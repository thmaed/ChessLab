"""Coups à la voix avec WHISPER, sur le Mac, sur les vrais enregistrements (étude du 19/11/2026).

Question : un modèle embarqué (Whisper, licence MIT, rien qui sorte de l'appareil) reconnaît-il mieux les coups
que la reconnaissance d'Apple d'avant iOS 26 (70-74 % bruts le 19/11, colonne e ratée sur l'iPhone XS) ?

Deux façons de s'en servir, pour chaque taille de modèle :

  libre  — Whisper transcrit (5 propositions, comme iOS) ; les transcriptions sont écrites dans un journal au format
           de la mesure, que le VRAI module de ChessLab rejoue (test Kotlin « rapport des journaux rejoués »).
  choix  — on ne demande pas « qu'a-t-il dit ? » mais « lequel des coups LÉGAUX a-t-il dit ? » : Whisper note
           chaque façon de dire chaque coup légal (probabilité du texte sachant le son) ; le mieux noté gagne.

Usage :
  .venv/bin/python mesure.py <trials.jsonl> <dossier des sons> <sortie.jsonl> [tiny,base,small]
"""
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from transformers import WhisperForConditionalGeneration, WhisperProcessor

# Le processeur : l'accélération Metal (mps) s'est bloquée pour de bon dans waitUntilCompleted (19/11/2026).
DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")
NAMES = {"K": "roi", "Q": "dame", "R": "tour", "B": "fou", "N": "cavalier", "P": "pion"}


def piece(c):
    if c["san"].startswith("O-O"):
        return "K"
    return c["san"][0] if c["san"][0] in "KQRBN" else "P"


def spoken_forms(c, all_candidates):
    """Les façons de dire un coup — celles de `VoiceMoveParser.spokenForms` (iOS/Android), plus le départ quand deux
    pièces de même sorte vont sur la même case (« cavalier b1 d2 »)."""
    if c["san"].startswith("O-O-O"):
        return ["grand roque"]
    if c["san"].startswith("O-O"):
        return ["petit roque", "roi " + c["uci"][2:4]]
    to, frm, name = c["uci"][2:4], c["uci"][:2], NAMES[piece(c)]
    forms = [f"{name} {to}", f"{name} en {to}"]
    if "x" in c["san"]:
        forms.append(f"{name} prend {to}")
    if piece(c) == "P":
        forms.append(to)
    if len(c["uci"]) > 4:
        promoted = NAMES[c["uci"][4].upper()]
        forms = [f"{to} {promoted}", f"{to} promotion {promoted}", f"pion {to} {promoted}"]
    twins = [o for o in all_candidates if o is not c and piece(o) == piece(c) and o["uci"][2:4] == to
             and len(o["uci"]) == len(c["uci"])]
    if twins:
        forms += [f"{name} {frm} {to}", f"{name} {frm} en {to}"]
    return forms


def load_audio(path):
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(path), tmp.name],
                       check=True, capture_output=True)
        audio, rate = sf.read(tmp.name, dtype="float32")
    assert rate == 16000
    return audio


class Whisper:
    def __init__(self, size):
        name = f"openai/whisper-{size}"
        self.processor = WhisperProcessor.from_pretrained(name)
        self.model = WhisperForConditionalGeneration.from_pretrained(name).to(DEVICE).eval()
        tok = self.processor.tokenizer
        self.prefix = tok.convert_tokens_to_ids(["<|startoftranscript|>", "<|fr|>", "<|transcribe|>",
                                                 "<|notimestamps|>"])
        self.eot = tok.eos_token_id

    def features(self, audio):
        f = self.processor(audio, sampling_rate=16000, return_tensors="pt").input_features
        return f.to(DEVICE)

    @torch.no_grad()
    def transcribe(self, feats, beams=5):
        out = self.model.generate(feats, language="fr", task="transcribe", num_beams=beams,
                                  num_return_sequences=beams, max_new_tokens=24)
        texts = self.processor.batch_decode(out, skip_special_tokens=True)
        seen, result = set(), []
        for t in (t.strip() for t in texts):
            if t and t not in seen:
                seen.add(t)
                result.append(t)
        return result

    @torch.no_grad()
    def score(self, feats, texts):
        """log P(texte | son) de chaque texte (somme sur ses jetons et la fin), en un seul passage du décodeur."""
        tok = self.processor.tokenizer
        enc = self.model.model.encoder(feats).last_hidden_state
        seqs = [self.prefix + tok.encode(" " + t, add_special_tokens=False) + [self.eot] for t in texts]
        width = max(map(len, seqs))
        ids = torch.full((len(seqs), width), self.eot, dtype=torch.long)
        mask = torch.zeros((len(seqs), width), dtype=torch.bool)
        for i, s in enumerate(seqs):
            ids[i, :len(s)] = torch.tensor(s)
            mask[i, len(self.prefix):len(s)] = True
        ids, mask = ids.to(DEVICE), mask.to(DEVICE)
        logits = self.model(encoder_outputs=(enc.expand(len(seqs), -1, -1),), decoder_input_ids=ids[:, :-1]).logits
        logp = torch.log_softmax(logits.float(), dim=-1)
        picked = logp.gather(2, ids[:, 1:].unsqueeze(-1)).squeeze(-1)
        picked = picked * mask[:, 1:]
        return picked.sum(dim=1).tolist(), mask[:, 1:].sum(dim=1).tolist()


def surface(form):
    """Les graphies d'une même phrase que Whisper pourrait écrire (« Pion e4. », « pion E4 »…)."""
    cap = form[0].upper() + form[1:]
    up = " ".join(w.upper() if len(w) == 2 and w[0] in "abcdefgh" and w[1] in "12345678" else w for w in cap.split())
    return [cap, cap + ".", up, up + "."]


def choose(whisper, feats, candidates):
    texts, owner = [], []
    for i, c in enumerate(candidates):
        for form in spoken_forms(c, candidates):
            for s in surface(form):
                texts.append(s)
                owner.append(i)
    totals, lengths = whisper.score(feats, texts)
    best = {}
    for i, total, n in zip(owner, totals, lengths):
        best[i] = max(best.get(i, -1e9), total)
    ranked = sorted(best.items(), key=lambda kv: -kv[1])
    (first, s1), (second, s2) = ranked[0], ranked[1] if len(ranked) > 1 else (None, -1e9)
    return candidates[first], s1 - s2


def main():
    trials_path, audio_dir, out_path = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    sizes = (sys.argv[4] if len(sys.argv) > 4 else "tiny,base,small").split(",")
    trials = [json.loads(l) for l in trials_path.read_text().splitlines() if l.strip()]
    sounds = {p.stem: p for p in audio_dir.iterdir() if p.suffix in (".caf", ".wav")}
    trials = [t for t in trials if t["id"] in sounds]
    print(f"{len(trials)} essais avec leur son, sur {DEVICE}")
    audio = {t["id"]: load_audio(sounds[t["id"]]) for t in trials}
    out = {t["id"]: dict(t, results=[]) for t in trials}
    for size in sizes:
        whisper = Whisper(size)
        right, wrong_choice, margins, t_free, t_choice = 0, [], [], [], []
        for t in trials:
            feats = whisper.features(audio[t["id"]])
            start = time.perf_counter()
            heard = whisper.transcribe(feats)
            t_free.append(time.perf_counter() - start)
            out[t["id"]]["results"].append({"engine": f"W-{size} libre", "transcripts": heard, "correct": False,
                                            "millis": int(t_free[-1] * 1000)})
            start = time.perf_counter()
            chosen, margin = choose(whisper, feats, t["candidates"])
            t_choice.append(time.perf_counter() - start)
            ok = chosen["uci"] == t["target"]["uci"]
            right += ok
            margins.append((margin, ok))
            if not ok:
                wrong_choice.append(f'{t["target"]["san"]}→{chosen["san"]}')
            # Le choix s'écrit aussi en « transcription » (sa première forme) : le rejeu Kotlin le compte pareil.
            out[t["id"]]["results"].append({"engine": f"W-{size} choix", "transcripts": [spoken_forms(chosen, t["candidates"])[0]],
                                            "correct": ok, "millis": int(t_choice[-1] * 1000)})
        print(f"whisper-{size} : choix parmi les coups légaux {right}/{len(trials)} "
              f"(médianes : libre {np.median(t_free)*1000:.0f} ms, choix {np.median(t_choice)*1000:.0f} ms sur le Mac)")
        print(f"   ratés du choix : {', '.join(wrong_choice) or 'aucun'}")
        for cut in (0.5, 1, 2, 3):
            kept = [ok for m, ok in margins if m >= cut]
            print(f"   avec un écart ≥ {cut} : {sum(kept)} justes / {len(kept)} joués, "
                  f"{len(margins) - len(kept)} redemandés, {len(kept) - sum(kept)} FAUX")
        # Écrit après CHAQUE taille : un calcul interrompu (small, le 19/11) ne perd pas les précédentes.
        out_path.write_text("".join(json.dumps(v, ensure_ascii=False) + "\n" for v in out.values()))
        del whisper


if __name__ == "__main__":
    main()
