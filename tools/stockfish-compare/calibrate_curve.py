import json, math, sys, bisect, statistics as st
from collections import Counter
data = json.load(open(sys.argv[1]))
def win(cp): return 50 + 50 * (2 / (1 + math.exp(-0.00368 * cp)) - 1)
ORDER = ["excellent", "bon", "imprécision", "erreur", "gaffe"]
def cat(l):
    l = max(0.0, l)
    return 0 if l < 2 else 1 if l < 5 else 2 if l < 10 else 3 if l < 20 else 4
EDGES = [0, 25, 50, 100, 150, 200, 300, 400, 500, 700, 1000]
def fit(games):
    xs = {}
    for g in games:
        for a, b in zip(g["sf17"], g["sf19"]):
            if a is None or b is None or a[0] == "m" or b[0] == "m": continue
            y = abs(b[1]); 
            if y >= 1000: continue
            k = bisect.bisect_right(EDGES, y) - 1
            xs.setdefault(k, []).append((y, abs(a[1])))
    pts = [(0.0, 0.0)]
    for k in sorted(xs):
        v = xs[k]; pts.append((st.mean(p[0] for p in v), st.mean(p[1] for p in v)))
    return pts
def apply(pts, cp):
    y = abs(cp); s = 1 if cp >= 0 else -1
    if y >= pts[-1][0]:
        # prolonge avec la dernière pente
        (y0, x0), (y1, x1) = pts[-2], pts[-1]
        return s * (x1 + (y - y1) * (x1 - x0) / (y1 - y0))
    i = bisect.bisect_right([p[0] for p in pts], y) - 1
    (y0, x0), (y1, x1) = pts[i], pts[i + 1]
    return s * (x0 + (y - y0) * (x1 - x0) / (y1 - y0))
def w(entry, tf=None):
    k, v = entry[0], entry[1]
    if k == "m": return 100.0 if v > 0 else 0.0
    return win(tf(v) if tf else v)
def agree(games, tf):
    same = n = gaffes17 = gaffes19 = 0
    for g in games:
        a, b = g["sf17"], g["sf19"]
        for i in range(10, len(g["fens"]) - 1):
            if None in (a[i], a[i+1], b[i], b[i+1]): continue
            white = i % 2 == 0
            def loss(e, tfn):
                x, y = w(e[i], tfn), w(e[i+1], tfn)
                return (x - y) if white else (y - x)
            c17 = cat(loss(a, None)); c19 = cat(loss(b, tf))
            same += c17 == c19; n += 1; gaffes17 += c17 == 4; gaffes19 += c19 == 4
    return same / n, gaffes17, gaffes19, n
half = [g for i, g in enumerate(data) if i % 2 == 0], [g for i, g in enumerate(data) if i % 2 == 1]
print("brut        : accord %.1f %% ; gaffes SF17 %d / SF19 %d" % ((lambda r: (100*r[0], r[1], r[2]))(agree(data, None))))
# facteur linéaire unique (ajusté sur une moitié, évalué sur l'autre)
for tr, te, name in ((0, 1, "A→B"), (1, 0, "B→A")):
    num = den = 0
    for g in half[tr]:
        for a, b in zip(g["sf17"], g["sf19"]):
            if a is None or b is None or a[0] == "m" or b[0] == "m" or abs(a[1]) >= 1000 or abs(b[1]) >= 1000: continue
            num += a[1] * b[1]; den += b[1] * b[1]
    k = num / den
    r = agree(half[te], lambda cp, k=k: k * cp)
    pts = fit(half[tr]); r2 = agree(half[te], lambda cp, pts=pts: apply(pts, cp))
    r0 = agree(half[te], None)
    print(f"{name}: brut {100*r0[0]:.1f} %  | facteur linéaire k={k:.3f}: {100*r[0]:.1f} % (gaffes {r[1]}/{r[2]})  | courbe par tranches: {100*r2[0]:.1f} % (gaffes {r2[1]}/{r2[2]})")
pts = fit(data)
print("courbe complète (cp19 → équivalent cp17):", [(round(a), round(b)) for a, b in pts])
