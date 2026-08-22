"""Chemin EXACT menant à une position, lu dans le graphe du cours.

Déduire la séquence de coups en lisant une FEN à l'œil est une source d'erreur
silencieuse : on calcule alors une ligne pour une position qui n'est pas celle
du trou, l'audit ne dit rien (la ligne est saine), et le trou reste béant.
Le graphe connaît le chemin — autant le lui demander.
"""
import json, sys
from collections import deque

course = json.load(open(sys.argv[1]))
target = sys.argv[2]
pos, root = course["positions"], course["rootFEN"]

# BFS : le plus court chemin depuis la racine, en SAN.
seen, queue = {root}, deque([(root, [])])
while queue:
    fen, path = queue.popleft()
    if fen == target:
        print(" ".join(path)); break
    for edge in pos.get(fen, {}).get("moves", []):
        nxt = edge["toFEN"]
        if nxt not in seen:
            seen.add(nxt)
            queue.append((nxt, path + [edge["san"]]))
else:
    print("INTROUVABLE", file=sys.stderr); sys.exit(1)
