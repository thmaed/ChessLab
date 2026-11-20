"""Variantes du CHOIX, pour le téléphone (19/11/2026) : sur l'iPhone XS, la normalisation sur les 51 865 jetons de
Whisper déborde en demi-précision et coûte ~1 s par lot de 32. Deux allégements, mesurés ici sur les mêmes essais :

  vocabulaire RÉDUIT — la probabilité de chaque jeton est normalisée sur les seuls jetons des phrases d'échecs
                       (une centaine) au lieu des 51 865 : ~400 fois moins de calcul à la sortie du décodeur ;
  moins de GRAPHIES  — 1, 2 ou 4 graphies par formulation (« Pion e4 », « Pion e4. », « Pion E4 », « Pion E4. »).

Usage : .venv/bin/python variantes.py <trials.jsonl> <dossier des sons> [...autres paires]
"""
import json
import sys
from pathlib import Path

import torch

import mesure
from convertir import vocabulary_pieces


def main():
    pairs = list(zip(sys.argv[1::2], sys.argv[2::2]))
    whisper = mesure.Whisper("base")
    tok = whisper.processor.tokenizer
    allowed = sorted({t for p in vocabulary_pieces() for t in tok.encode(p, add_special_tokens=False)} | {whisper.eot})
    index = {t: i for i, t in enumerate(allowed)}
    print(f"vocabulaire réduit : {len(allowed)} jetons")
    variants = [(vocab, n) for vocab in ("complet", "réduit") for n in (4, 2, 1)]
    for trials_path, sounds_dir in pairs:
        trials = [json.loads(l) for l in Path(trials_path).read_text().splitlines() if l.strip()]
        sounds = {p.stem: p for p in Path(sounds_dir).iterdir() if p.suffix in (".caf", ".wav")}
        trials = [t for t in trials if t["id"] in sounds]
        right = {v: 0 for v in variants}
        sure = {v: [0, 0] for v in variants}   # écart ≥ 2 : joués, faux
        for t in trials:
            feats = whisper.features(mesure.load_audio(sounds[t["id"]]))
            texts, owner, rank = [], [], []
            for i, c in enumerate(t["candidates"]):
                for form in mesure.spoken_forms(c, t["candidates"]):
                    for r, s in enumerate(mesure.surface(form)):
                        texts.append(s)
                        owner.append(i)
                        rank.append(r)
            with torch.no_grad():
                enc = whisper.model.model.encoder(feats).last_hidden_state
                seqs = [whisper.prefix + tok.encode(" " + s, add_special_tokens=False) + [whisper.eot] for s in texts]
                width = max(map(len, seqs))
                ids = torch.full((len(seqs), width), whisper.eot, dtype=torch.long)
                mask = torch.zeros((len(seqs), width), dtype=torch.bool)
                for i, s in enumerate(seqs):
                    ids[i, :len(s)] = torch.tensor(s)
                    mask[i, len(whisper.prefix):len(s)] = True
                logits = whisper.model(encoder_outputs=(enc.expand(len(seqs), -1, -1),),
                                       decoder_input_ids=ids[:, :-1]).logits.float()
                nxt, m = ids[:, 1:], mask[:, 1:]
                full = (torch.log_softmax(logits, -1).gather(2, nxt.unsqueeze(-1)).squeeze(-1) * m).sum(1)
                sub = logits[:, :, allowed]
                local = torch.tensor([[index.get(int(x), 0) for x in row] for row in nxt])
                reduced = (torch.log_softmax(sub, -1).gather(2, local.unsqueeze(-1)).squeeze(-1) * m).sum(1)
            for vocab, n in variants:
                scores = full if vocab == "complet" else reduced
                best = {}
                for i, r, s in zip(owner, rank, scores.tolist()):
                    if r < n:
                        best[i] = max(best.get(i, -1e9), s)
                ranked = sorted(best.items(), key=lambda kv: -kv[1])
                ok = t["candidates"][ranked[0][0]]["uci"] == t["target"]["uci"]
                right[(vocab, n)] += ok
                if len(ranked) == 1 or ranked[0][1] - ranked[1][1] >= 2:
                    sure[(vocab, n)][0] += 1
                    sure[(vocab, n)][1] += not ok
        print(f"{trials_path.split('/')[-2]} ({len(trials)} essais)")
        for v in variants:
            print(f"   {v[0]:8s} {v[1]} graphie(s) : {right[v]}/{len(trials)} ; écart ≥ 2 : {sure[v][0]} joués, "
                  f"{sure[v][1]} faux")


if __name__ == "__main__":
    main()
