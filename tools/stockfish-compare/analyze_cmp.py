import json, math, sys, statistics as st
from collections import Counter
data = json.load(open(sys.argv[1]))
def win(cp): return 50 + 50 * (2 / (1 + math.exp(-0.00368 * cp)) - 1)
def w(entry):
    if entry is None: return None
    k, v = entry
    if k == "m": return 100.0 if v > 0 else 0.0
    return win(v)
def cat(loss):
    loss = max(0.0, loss)
    return "excellent" if loss < 2 else "bon" if loss < 5 else "imprécision" if loss < 10 else "erreur" if loss < 20 else "gaffe"
ORDER = ["excellent", "bon", "imprécision", "erreur", "gaffe"]
pairs = Counter(); n = 0; same = 0
cp17, cp19 = [], []
mate_diff = 0; mate_total = 0
loss17_all, loss19_all = [], []
big = 0
for g in data:
    a, b = g["sf17"], g["sf19"]
    for i in range(10, len(g["fens"]) - 1):
        if None in (a[i], a[i+1], b[i], b[i+1]): continue
        w17a, w17b, w19a, w19b = w(a[i]), w(a[i+1]), w(b[i]), w(b[i+1])
        white = (i % 2 == 0)
        l17 = (w17a - w17b) if white else (w17b - w17a)
        l19 = (w19a - w19b) if white else (w19b - w19a)
        c17, c19 = cat(l17), cat(l19)
        pairs[(c17, c19)] += 1; n += 1; same += c17 == c19
        loss17_all.append(max(0, l17)); loss19_all.append(max(0, l19))
        if abs(ORDER.index(c17) - ORDER.index(c19)) >= 2: big += 1
    for i in range(len(g["fens"])):
        if a[i] is None or b[i] is None: continue
        if a[i][0] == "m" or b[i][0] == "m":
            mate_total += 1
            if a[i][0] != b[i][0] or (a[i][0] == "m" and (a[i][1] > 0) != (b[i][1] > 0)): mate_diff += 1
        elif abs(a[i][1]) < 1000 and abs(b[i][1]) < 1000:
            cp17.append(a[i][1]); cp19.append(b[i][1])
print(f"coups comparés: {n}")
print(f"même catégorie: {same} ({100*same/n:.1f} %) ; écart de 2 catégories ou plus: {big} ({100*big/n:.2f} %)")
for c in ORDER:
    t17 = sum(v for (x, y), v in pairs.items() if x == c); t19 = sum(v for (x, y), v in pairs.items() if y == c)
    print(f"  {c:12} SF17: {t17:5d} ({100*t17/n:5.1f} %)   SF19: {t19:5d} ({100*t19/n:5.1f} %)")
errs17 = sum(v for (x, y), v in pairs.items() if x in ORDER[2:]); errs19 = sum(v for (x, y), v in pairs.items() if y in ORDER[2:])
both = sum(v for (x, y), v in pairs.items() if x in ORDER[2:] and y in ORDER[2:])
print(f"coups fautifs (≥ imprécision): SF17 {errs17}, SF19 {errs19}, les deux {both} → {100*both/max(errs17,errs19):.0f} % du plus grand ensemble")
print(f"perte moyenne (points de gain): SF17 {st.mean(loss17_all):.3f}  SF19 {st.mean(loss19_all):.3f}")
mx = st.mean(cp17); my = st.mean(cp19)
cov = sum((x-mx)*(y-my) for x, y in zip(cp17, cp19)) / len(cp17)
vx = st.pvariance(cp17); vy = st.pvariance(cp19)
print(f"éval (cp, |cp|<1000, {len(cp17)} positions): moyenne SF17 {mx:.1f}  SF19 {my:.1f} ; corrélation {cov/math.sqrt(vx*vy):.4f} ; pente SF19/SF17 {cov/vx:.3f} ; écart-type de la différence {st.pstdev([y-x for x,y in zip(cp17,cp19)]):.1f}")
print(f"positions avec mat: {mate_total}, désaccord sur le mat: {mate_diff}")
print("matrice (lignes SF17, colonnes SF19):")
print(" " * 13 + "".join(f"{c[:6]:>8}" for c in ORDER))
for x in ORDER:
    print(f"{x:13}" + "".join(f"{pairs[(x,y)]:8d}" for y in ORDER))
