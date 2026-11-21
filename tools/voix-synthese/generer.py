#!/usr/bin/env python3
"""Fabrique des enregistrements SYNTHÉTIQUES de coups d'échecs, dans chaque langue de l'app, avec plusieurs voix du Mac.

Sert à mesurer, SANS locuteur natif, ce que les reconnaisseurs de l'appareil écrivent (Android : `VoiceSynthBatchActivity`,
iOS : le banc `VoiceSynthBench`), puis à comparer au coup attendu (tests `SynthEvalTest` / `SynthEvalTests`).

Une voix de synthèse est propre : les résultats sont plus optimistes que la vraie parole. À lire comme un filtre de
dégrossissage, pas comme une mesure de précision.

Usage : tools/voix-synthese/generer.py --langs de it --voices 4 --out /tmp/synth
Sorties dans --out :  index.jsonl (une ligne par enregistrement), bundle.bin (PCM 16 kHz mono 16 bits concaténé, pour
Android), wav/<id>.wav (pour iOS), et le fichier `index.jsonl` décrit : id, lang, voice, rate, text, fen, expected.
"""
import argparse, json, os, re, subprocess, sys, wave, array, tempfile

POS = {
    "start": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "ruy": "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
    "italian": "r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    "rooks": "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
}
# (position, uci, genre, pièce, colonne, rangée)  — genre : piece | pawn | castleS | castleL | capture
MOVES = [
    ("start", "e2e4", "pawn", "P", "e", 4), ("start", "d2d4", "pawn", "P", "d", 4),
    ("start", "g1f3", "piece", "N", "f", 3), ("start", "b1c3", "piece", "N", "c", 3),
    ("ruy", "f1b5", "piece", "B", "b", 5), ("ruy", "f1c4", "piece", "B", "c", 4),
    ("ruy", "d2d4", "pawn", "P", "d", 4), ("ruy", "b1c3", "piece", "N", "c", 3),
    ("italian", "e1g1", "castleS", None, None, None), ("italian", "d2d3", "pawn", "P", "d", 3),
    ("italian", "c2c3", "pawn", "P", "c", 3),
    ("rooks", "e1g1", "castleS", None, None, None), ("rooks", "e1c1", "castleL", None, None, None),
    ("rooks", "a1a8", "capture", "R", "a", 8), ("rooks", "h1h8", "capture", "R", "h", 8),
    ("rooks", "e1e2", "piece", "K", "e", 2),
]
LANGS = {
    "fr": dict(loc="fr_FR", pieces=dict(K="roi", Q="dame", R="tour", B="fou", N="cavalier", P="pion"),
               ranks="un deux trois quatre cinq six sept huit".split(), short="petit roque", long="grand roque",
               undo="annule", takes="prend"),
    "en": dict(loc="en_", pieces=dict(K="king", Q="queen", R="rook", B="bishop", N="knight", P="pawn"),
               ranks="one two three four five six seven eight".split(), short="castles kingside",
               long="castles queenside", undo="undo", takes="takes"),
    "es": dict(loc="es_ES", pieces=dict(K="rey", Q="dama", R="torre", B="alfil", N="caballo", P="peón"),
               ranks="uno dos tres cuatro cinco seis siete ocho".split(), short="enroque corto", long="enroque largo",
               undo="deshacer", takes="come"),
    "de": dict(loc="de_DE", pieces=dict(K="König", Q="Dame", R="Turm", B="Läufer", N="Springer", P="Bauer"),
               ranks="eins zwei drei vier fünf sechs sieben acht".split(), short="kurze Rochade",
               long="lange Rochade", undo="zurück", takes="schlägt"),
    "it": dict(loc="it_IT", pieces=dict(K="re", Q="donna", R="torre", B="alfiere", N="cavallo", P="pedone"),
               ranks="uno due tre quattro cinque sei sette otto".split(), short="arrocco corto", long="arrocco lungo",
               undo="annulla", takes="prende"),
}
NOVELTY = {"Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos", "Good News", "Jester", "Organ",
           "Superstar", "Trinoids", "Whisper", "Wobble", "Zarvox", "Fred", "Junior", "Kathy", "Ralph", "Princess"}


def voices_for(lang, count):
    out = subprocess.run(["say", "-v", "?"], capture_output=True, text=True).stdout
    found = []
    for line in out.splitlines():
        m = re.match(r"^(.+?)\s+([a-z]{2}_[A-Z]{2})\s+#", line)
        if not m:
            continue
        name, loc = m.group(1).strip(), m.group(2)
        if not loc.startswith(LANGS[lang]["loc"]) or name.split(" (")[0] in NOVELTY:
            continue
        found.append((name, loc))
    # Une seule variante régionale par prénom, les voix « de base » (sans parenthèse) d'abord.
    found.sort(key=lambda v: ("(" in v[0], v[0]))
    names = [n for n, _ in found]
    if len(names) <= count:
        return names
    # Réparties sur toute la liste (voix de base, puis voix variées) plutôt que les premières par ordre alphabétique.
    return [names[round(i * (len(names) - 1) / (count - 1))] for i in range(count)] if count > 1 else names[:1]


def phrases(lang):
    t = LANGS[lang]
    rows = []
    for pos, uci, kind, piece, col, rank in MOVES:
        if kind == "castleS":
            rows.append((pos, uci, t["short"]))
        elif kind == "castleL":
            rows.append((pos, uci, t["long"]))
        else:
            sq = f"{col} {t['ranks'][rank - 1]}"
            name = t["pieces"][piece]
            if kind == "pawn":
                rows += [(pos, uci, sq), (pos, uci, f"{name} {sq}")]
            elif kind == "capture":
                rows += [(pos, uci, f"{name} {sq}"), (pos, uci, f"{name} {t['takes']} {sq}")]
            else:
                rows.append((pos, uci, f"{name} {sq}"))
    rows.append(("start", "undo", t["undo"]))
    return rows


def synth(voice, text, rate, tmp):
    aiff = os.path.join(tmp, "x.aiff")
    wav = os.path.join(tmp, "x.wav")
    cmd = ["say", "-v", voice, "-o", aiff]
    if rate:
        cmd += ["-r", str(rate)]
    subprocess.run(cmd + [text], check=True, capture_output=True)
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiff, wav], check=True, capture_output=True)
    with wave.open(wav) as w:
        samples = array.array("h")
        samples.frombytes(w.readframes(w.getnframes()))
    return samples


def prepare(samples):
    peak = max(1, max(abs(s) for s in samples))
    gain = 23000 / peak                      # crête vers −3 dB, comme la normalisation de l'app
    padded = array.array("h", [0] * 4800)     # 0,3 s de silence avant
    padded.extend(array.array("h", (max(-32768, min(32767, int(s * gain))) for s in samples)))
    padded.extend(array.array("h", [0] * 12800))  # 0,8 s de silence APRÈS : la fin de phrase de l'app (0,7 s) ; sans lui iOS coupe la dernière syllabe
    return padded


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--langs", nargs="+", default=["de"])
    ap.add_argument("--voices", type=int, default=4)
    ap.add_argument("--rates", nargs="*", type=int, default=[0], help="mots/minute ; 0 = défaut de la voix")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(os.path.join(args.out, "wav"), exist_ok=True)
    index, bundle, offset, count = [], bytearray(), 0, 0
    with tempfile.TemporaryDirectory() as tmp:
        for lang in args.langs:
            for voice in voices_for(lang, args.voices):
                for rate in args.rates:
                    for pos, expected, text in phrases(lang):
                        try:
                            pcm = prepare(synth(voice, text, rate, tmp))
                        except subprocess.CalledProcessError as e:
                            print("échec", voice, text, e, file=sys.stderr)
                            continue
                        count += 1
                        rid = f"{lang}-{count:04d}"
                        raw = pcm.tobytes()
                        with wave.open(os.path.join(args.out, "wav", rid + ".wav"), "wb") as w:
                            w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(raw)
                        index.append(dict(id=rid, lang=lang, voice=voice, rate=rate, text=text, fen=POS[pos],
                                          expected=expected, offset=offset, length=len(raw)))
                        bundle += raw
                        offset += len(raw)
                print(f"{lang} · {voice} : {len(phrases(lang))} phrases", flush=True)
    with open(os.path.join(args.out, "index.jsonl"), "w") as f:
        for row in index:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    with open(os.path.join(args.out, "bundle.bin"), "wb") as f:
        f.write(bundle)
    print(f"{len(index)} enregistrements, {len(bundle) // 1024} Ko → {args.out}")


if __name__ == "__main__":
    main()
