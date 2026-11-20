"""Les modèles Core ML de `convertir.py` donnent-ils le même CHOIX que Whisper d'origine (48/51 avec base) ?
Même chemin que l'iPhone : morceaux de jetons de `whisper-pretokens.json`, lots de 32, son complété à 30 s.

Usage : .venv/bin/python verifier_coreml.py <dossier coreml> <trials.jsonl> <dossier des sons>
"""
import json
import sys
import time
from pathlib import Path

import coremltools as ct
import numpy as np

import mesure
from convertir import BATCH, LENGTH, SAMPLES, pretokens


def main():
    folder, trials_path, sounds_dir = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    table = json.loads((folder / "whisper-pretokens.json").read_text())
    audio_model = ct.models.MLModel(str(folder / "WhisperAudio.mlpackage"), compute_units=ct.ComputeUnit.ALL)
    scorer = ct.models.MLModel(str(folder / "WhisperScorer.mlpackage"), compute_units=ct.ComputeUnit.ALL)
    prefix, eot = table["prefix"], table["endoftext"]
    trials = [json.loads(l) for l in trials_path.read_text().splitlines() if l.strip()]
    sounds = {p.stem: p for p in sounds_dir.iterdir() if p.suffix in (".caf", ".wav")}
    right, times, batches = 0, [], []
    for t in trials:
        if t["id"] not in sounds:
            continue
        audio = mesure.load_audio(sounds[t["id"]])[:SAMPLES]
        padded = np.zeros((1, SAMPLES), dtype=np.float32)
        padded[0, :len(audio)] = audio
        start = time.perf_counter()
        kv = audio_model.predict({"audio": padded})
        texts, owner = [], []
        for i, c in enumerate(t["candidates"]):
            for form in mesure.spoken_forms(c, t["candidates"]):
                for s in mesure.surface(form):
                    texts.append(s)
                    owner.append(i)
        seqs = [prefix + [x for p in pretokens(" " + s) for x in table["pieces"][p]] + [eot] for s in texts]
        scores = []
        for b in range(0, len(seqs), BATCH):
            chunk = seqs[b:b + BATCH]
            ids = np.full((BATCH, LENGTH), eot, dtype=np.int32)
            for i, s in enumerate(chunk):
                ids[i, :len(s)] = s
            lp = scorer.predict({"tokens": ids, "keys": kv["keys"], "values": kv["values"]})["logprobs"]
            for i, s in enumerate(chunk):
                scores.append(float(lp[i, len(prefix) - 1:len(s) - 1].sum()))
        times.append(time.perf_counter() - start)
        batches.append((len(seqs) + BATCH - 1) // BATCH)
        best = {}
        for i, s in zip(owner, scores):
            best[i] = max(best.get(i, -1e9), s)
        chosen = t["candidates"][max(best, key=best.get)]
        right += chosen["uci"] == t["target"]["uci"]
    print(f"Core ML : {right}/{len(times)} justes ; médiane {np.median(times)*1000:.0f} ms par coup sur le Mac "
          f"({np.median(batches):.0f} lots de {BATCH})")


if __name__ == "__main__":
    main()
