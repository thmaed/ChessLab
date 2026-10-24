"""Lit s2_results.json (s2_elo_estimate.py) et mesure l'erreur de l'estimation
du niveau selon le nombre de parties poolées (1, 3, 5, toutes).

Pour chaque joueur et chaque N, on tire 300 sous-ensembles de N parties, on
additionne leurs log-vraisemblances, on prend le niveau qui les maximise, et on
compare à la cote Lichess moyenne du joueur.
"""
import json, random, sys
import numpy as np

GRID = list(range(700, 2701, 100))

def argmax_elo(ll):
    i = int(np.argmax(ll))
    if 0 < i < len(GRID) - 1:
        y0, y1, y2 = ll[i - 1], ll[i], ll[i + 1]
        d = y0 - 2 * y1 + y2
        if d < 0:
            return GRID[i] + 100 * 0.5 * (y0 - y2) / d
    return float(GRID[i])

data = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "s2_results.json"))
rng = random.Random(7)
print(f"{len(data)} joueurs, cotes {min(d['true'] for d in data):.0f}-{max(d['true'] for d in data):.0f}\n")
print(f"{'N parties':>10} {'erreur moy.':>12} {'écart-type':>11} {'biais':>8} {'|e|<100':>8} {'|e|<200':>8}")
rows = []
for n in (1, 3, 5, 8):
    errs = []
    for d in data:
        lls = [np.array(x) for x in d["ll"]]
        if len(lls) < n:
            continue
        for _ in range(100):
            sub = rng.sample(lls, n)
            errs.append(argmax_elo(sum(sub)) - d["true"])
    if not errs:
        continue
    e = np.array(errs)
    rows.append((n, len(e), float(np.mean(np.abs(e))), float(np.std(e)), float(np.mean(e)),
                 float(np.mean(np.abs(e) < 100)), float(np.mean(np.abs(e) < 200))))
    print(f"{n:>10} {np.mean(np.abs(e)):>12.0f} {np.std(e):>11.0f} {np.mean(e):>+8.0f} {np.mean(np.abs(e)<100):>8.0%} {np.mean(np.abs(e)<200):>8.0%}")

# Biais selon la cote : la méthode tire-t-elle vers le milieu ?
print("\nBiais par tranche de cote (N=5) :")
for lo, hi in ((0, 1300), (1300, 1600), (1600, 1900), (1900, 4000)):
    es = []
    for d in data:
        if lo <= d["true"] < hi and len(d["ll"]) >= 5:
            lls = [np.array(x) for x in d["ll"]]
            for _ in range(100):
                es.append(argmax_elo(sum(rng.sample(lls, 5))) - d["true"])
    if es:
        print(f"  {lo}-{hi}: n={len(es)//100} joueurs, biais {np.mean(es):+.0f}, écart-type {np.std(es):.0f}")
json.dump(rows, open("s2_summary.json", "w"))
