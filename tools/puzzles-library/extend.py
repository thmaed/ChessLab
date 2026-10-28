#!/usr/bin/env python3
"""Complète la bibliothèque de puzzles Lichess embarquée (lichess_puzzles.json).

Pourquoi ce script existe : la bibliothèque a été générée par un script
ponctuel qui n'a jamais été versionné (PROGRESS.md le décrit, 12/07/2026). Celui-ci
AJOUTE des puzzles sans toucher aux existants (leurs identifiants restent, la
progression des utilisateurs aussi) et corrige les trous mesurés :

  - niveaux extrêmes (sous 600, au-dessus de 2400) ;
  - cellules (tranche de cote × thème) creuses ;
  - séquences longues : 4 coups du joueur ou plus (7 coups de solution ou plus), les
    seules vraiment rares — celles à 3 coups du joueur sont déjà 37 000 ;
  - équilibre des phases (ouverture / milieu / finale).

Source : `lichess_db_puzzle.csv.zst` de database.lichess.org (CC0). Un puzzle y
est « FEN avant le coup de mise en place de l'adversaire ; Moves = mise en place
puis solution ». Le champ `fen` de l'app est la position APRÈS la mise en place
(c'est au joueur de jouer), `solutionLANs` la suite.

Usage :
    python3 -I tools/puzzles-library/extend.py \
        --csv lichess_db_puzzle.csv.zst --library ChessLab/Resources/lichess_puzzles.json \
        --add 25000 [--dry-run]

Dépendances : python-chess, zstd en ligne de commande. Le tirage est reproductible
(`--seed`).
"""
import argparse
import collections
import csv
import json
import random
import subprocess
import sys

import chess

THEMES = ["checkmate", "fork", "pin", "skewer", "discoveredAttack", "hangingPiece", "sacrifice", "tactic"]
# Ordre de priorité du thème principal (voir PROGRESS.md) : le plus spécifique d'abord.
PRIORITY = [
    ("checkmate", {"mate"}),
    ("fork", {"fork"}),
    ("pin", {"pin"}),
    ("skewer", {"skewer"}),
    ("discoveredAttack", {"discoveredAttack"}),
    ("hangingPiece", {"hangingPiece"}),
    ("sacrifice", {"sacrifice"}),
]
LOW, HIGH = 400, 2800            # tranches de 200 ; les cotes hors bornes sont ramenées dedans
BUCKETS = list(range(LOW, HIGH + 1, 200))
PHASES = ["opening", "middlegame", "endgame"]

# Qualité minimale d'un puzzle retenu.
MIN_PLAYS = 150
MIN_POPULARITY = 70
MAX_RATING_DEVIATION = 100
MAX_SOLUTION_LANS = 11           # 6 coups du joueur au plus

# Planchers par (tranche, thème) : on comble ce qui manque, on ne retire rien.
FLOORS = {400: 1000, 600: 1100, 2400: 1000, 2600: 600, 2800: 200}
RESERVOIR = 260                   # candidats gardés par (cellule, phase, palier de longueur)
# Palier de longueur d'une solution : 2 = 4 coups du joueur ou plus, 1 = 3 coups, 0 = 1 ou 2.
TIERS = (0, 1, 2)
# La phase la plus rare, l'ouverture, passe deux fois par tour : la bibliothèque en avait 27 000
# contre 57 000 au milieu de partie.
PHASE_ROTATION = ["opening", "opening", "endgame", "middlegame"]


def tier_of(solution_len):
    return 2 if solution_len >= 7 else 1 if solution_len == 5 else 0


def bucket(rating):
    return max(LOW, min(HIGH, (rating // 200) * 200))


def main_theme(tags):
    for name, wanted in PRIORITY:
        if tags & wanted or (name == "checkmate" and any(t.startswith("mateIn") for t in tags)):
            return name
    return "tactic"


def phase_of_board(board):
    """Pendant EXACT de GamePhaseClassifier.classify (Swift) / GamePhase.of (Kotlin)."""
    pieces = board.piece_map().values()
    has_queen = any(p.piece_type == chess.QUEEN for p in pieces)
    major_minor = sum(1 for p in pieces if p.piece_type not in (chess.PAWN, chess.KING))
    if major_minor <= (2 if has_queen else 6):
        return "endgame"
    pawns = sum(1 for p in pieces if p.piece_type == chess.PAWN)
    if board.fullmove_number <= 10 and pawns >= 14 and major_minor >= 12:
        return "opening"
    return "middlegame"


def cheap_phase(fen):
    """La phase estimée SANS python-chess (6 M de lignes) : la position d'avant la mise en
    place, à une pièce près. La phase exacte est recalculée sur les seuls puzzles retenus."""
    placement, _, rest = fen.partition(" ")
    pieces = [c for c in placement if c.isalpha()]
    has_queen = any(c in "qQ" for c in pieces)
    major_minor = sum(1 for c in pieces if c.lower() not in "pk")
    if major_minor <= (2 if has_queen else 6):
        return "endgame"
    pawns = sum(1 for c in pieces if c in "pP")
    try:
        move = int(fen.split()[-1])
    except ValueError:
        move = 99
    return "opening" if (move <= 10 and pawns >= 14 and major_minor >= 12) else "middlegame"


def stream_rows(path):
    proc = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE, text=True, bufsize=1 << 20)
    reader = csv.DictReader(proc.stdout)
    yield from reader
    proc.wait()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--library", required=True)
    ap.add_argument("--add", type=int, default=25000)
    ap.add_argument("--seed", type=int, default=20261028)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    rng = random.Random(args.seed)

    library = json.load(open(args.library, encoding="utf-8"))
    known = {p["id"] for p in library}
    have = collections.Counter((bucket(p["rating"]), p["theme"]) for p in library)

    # --- 1. Un seul passage sur la base : des réservoirs par (tranche, thème, phase, longue).
    pools = collections.defaultdict(list)
    seen = collections.Counter()
    kept = 0
    for i, row in enumerate(stream_rows(args.csv)):
        if i % 1_000_000 == 0:
            print(f"  … {i:,} lignes", file=sys.stderr)
        if row["PuzzleId"] in known:
            continue
        try:
            rating = int(row["Rating"])
            if (int(row["NbPlays"]) < MIN_PLAYS or int(row["Popularity"]) < MIN_POPULARITY
                    or int(row["RatingDeviation"]) > MAX_RATING_DEVIATION):
                continue
        except ValueError:
            continue
        moves = row["Moves"].split()
        solution_len = len(moves) - 1
        if solution_len < 1 or solution_len % 2 == 0 or solution_len > MAX_SOLUTION_LANS:
            continue
        theme = main_theme(set(row["Themes"].split()))
        key = (bucket(rating), theme, cheap_phase(row["FEN"]), tier_of(solution_len))
        seen[key] += 1
        kept += 1
        pool = pools[key]
        if len(pool) < RESERVOIR:
            pool.append(row)
        else:
            j = rng.randrange(seen[key])
            if j < RESERVOIR:
                pool[j] = row
    print(f"{kept:,} candidats éligibles, {len(pools)} réservoirs", file=sys.stderr)

    def available(b, t, tiers=TIERS):
        return sum(len(pools[(b, t, ph, tr)]) for ph in PHASES for tr in tiers)

    # --- 2. Plan : A) combler les planchers ; B) le reste en séquences longues (3 coups et plus), au milieu
    # de l'échelle, les plus longues d'abord.
    quota = {}
    for b in BUCKETS:
        for t in THEMES:
            deficit = max(0, FLOORS.get(b, 0) - have[(b, t)])
            quota[(b, t)] = min(deficit, available(b, t))
    stage_a = sum(quota.values())
    if stage_a > args.add:
        scale = args.add / stage_a
        quota = {k: int(v * scale) for k, v in quota.items()}
        stage_a = sum(quota.values())
    remaining = args.add - stage_a
    middle = [(b, t) for b in BUCKETS if 800 <= b <= 2200 for t in THEMES]
    extra_each = remaining // len(middle)
    for cell in middle:
        quota[cell] += min(extra_each, available(*cell, tiers=(1, 2)))
    print(f"plan : {stage_a:,} pour combler les trous + {sum(quota.values()) - stage_a:,} séquences longues",
          file=sys.stderr)

    # --- 3. Tirage dans chaque cellule : phases à parts égales, longues d'abord au milieu de l'échelle.
    chosen = []
    for (b, t), n in sorted(quota.items()):
        if n <= 0:
            continue
        # Au milieu de l'échelle, le palier le plus long d'abord ; aux extrémités, tous mêlés.
        mid_range = 800 <= b <= 2200
        per_phase = {ph: [] for ph in PHASES}
        for ph in PHASES:
            if mid_range:
                for tr in (2, 1, 0):
                    rows = list(pools[(b, t, ph, tr)])
                    rng.shuffle(rows)
                    per_phase[ph] += rows
            else:
                rows = [r for tr in TIERS for r in pools[(b, t, ph, tr)]]
                rng.shuffle(rows)
                per_phase[ph] = rows
        picked = []
        # Tour de rôle entre les phases jusqu'au quota (ce qui manque dans une phase passe aux autres).
        while len(picked) < n and any(per_phase.values()):
            for ph in PHASE_ROTATION:
                if per_phase[ph] and len(picked) < n:
                    picked.append(per_phase[ph].pop(0))
        chosen += [(t, r) for r in picked]

    # --- 4. Mise en forme : FEN après la mise en place, phase exacte.
    added = []
    for theme, row in chosen:
        moves = row["Moves"].split()
        board = chess.Board(row["FEN"])
        try:
            board.push_uci(moves[0])
        except ValueError:
            continue
        added.append({
            "id": row["PuzzleId"], "fen": board.fen(), "solutionLANs": moves[1:],
            "theme": theme, "rating": int(row["Rating"]), "phase": phase_of_board(board),
        })

    def report(title, items):
        print(f"\n== {title} : {len(items):,} puzzles")
        print("  thèmes :", dict(sorted(collections.Counter(p["theme"] for p in items).items())))
        print("  phases :", dict(collections.Counter(p["phase"] for p in items)))
        print("  tranches:", dict(sorted(collections.Counter(bucket(p["rating"]) for p in items).items())))
        print("  coups du joueur :", dict(sorted(collections.Counter((len(p["solutionLANs"]) + 1) // 2 for p in items).items())))

    report("AJOUTÉS", added)
    report("BIBLIOTHÈQUE APRÈS", library + added)
    if args.dry_run:
        return
    with open(args.library, "w", encoding="utf-8") as out:
        json.dump(library + added, out, ensure_ascii=False, separators=(",", ":"))
    print(f"\nécrit : {args.library} ({len(library) + len(added):,} puzzles)")


if __name__ == "__main__":
    main()
