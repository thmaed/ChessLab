#!/usr/bin/env python3
"""Remplit les statistiques et les évaluations des cours livrés.

## Ce que ça règle

Le modèle `MoveEdge` prévoit six champs statistiques (`gamesMasters`,
`popularityMasters`, `gamesClub`, `popularityClub`, `scoreWhite/Draw/Black`)
plus `eval`, et l'app sait déjà les AFFICHER : barre de score dans
l'Explorateur, pourcentage et évaluation dans l'écran d'apprentissage. Elle va
jusqu'à afficher « Statistiques indisponibles sur ce pilote » quand tout est
vide — ce qui était le cas des 3 599 arêtes des 58 cours.

Tout était branché ; rien n'arrivait. Ce script apporte les données.

## L'app n'appelle JAMAIS Lichess

Les requêtes partent d'ici, à la compilation. Les chiffres sont écrits dans les
fichiers de cours, qui partent avec l'app. Sur le téléphone, l'app lit ses
propres fichiers — exactement comme pour les 106 000 puzzles déjà embarqués.

## À lancer APRÈS `author.py`

`author.py` régénère les cours depuis `content/*.py` et écrase donc ces
champs : l'enrichissement est une passe de finition, pas une source. L'ordre
complet est `author.py`, puis `audit.py` (qui remplit au passage le cache
d'évaluations que ce script réutilise), puis `enrich.py`.

    export LICHESS_TOKEN=lip_xxxx
    python3 author.py && python3 audit.py --stockfish bin/stockfish && python3 enrich.py
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from explorer import TOKEN_HELP, LichessExplorer, token_from_environment
from fen import board_from_key

HERE = Path(__file__).resolve().parent
COURSES = HERE.parents[1] / "ChessLab" / "Resources" / "openings"
AUDIT_CACHE = HERE / ".cache" / "audit" / "d18.json"


def parse_args(argv):
    p = argparse.ArgumentParser(description="Statistiques et évaluations des cours livrés")
    p.add_argument("--dir", default=str(COURSES))
    p.add_argument("--only", help="identifiants séparés par des virgules")
    p.add_argument("--ratings", default="1400,1600,1800",
                   help="tranches Elo club — ce que le joueur affronte vraiment")
    p.add_argument("--speeds", default="blitz,rapid,classical")
    p.add_argument("--min-delay", type=float, default=1.0)
    p.add_argument("--cache", default=str(HERE / ".cache"))
    p.add_argument("--no-masters", action="store_true",
                   help="ne pas interroger la base des maîtres (deux fois moins de requêtes)")
    p.add_argument("--offline", action="store_true",
                   help="n'utiliser que le cache disque — aucune requête")
    return p.parse_args(argv)


def move_stats(data) -> dict:
    """(uci → statistiques) depuis une réponse Explorer, parts recalculées sur
    le total des coups : ce sont elles qui font somme 1, alors que les totaux
    de tête incluent des parties écartées par les filtres."""
    if not data:
        return {}
    moves = data.get("moves") or []
    out = {}
    total = 0
    for m in moves:
        uci = m.get("uci")
        if not uci:
            continue
        white = m.get("white") or 0
        draws = m.get("draws") or 0
        black = m.get("black") or 0
        games = white + draws + black
        if games <= 0:
            continue
        out[uci] = {"games": games, "white": white, "draws": draws, "black": black}
        total += games
    for value in out.values():
        value["share"] = value["games"] / total if total else 0.0
    return out


def load_evals() -> dict:
    """Évaluations déjà calculées par `audit.py`, indexées par FEN normalisée.

    Le cache les range du point de vue du CAMP AU TRAIT ; le modèle attend
    celui des BLANCS. D'où la conversion — une erreur de signe ici afficherait
    des évaluations inversées, ce qui est pire que pas d'évaluation du tout.
    """
    if not AUDIT_CACHE.exists():
        return {}
    raw = json.loads(AUDIT_CACHE.read_text())
    out = {}
    for key, value in raw.items():
        if value is None:
            continue
        fields = key.split(" ")
        black_to_move = len(fields) > 1 and fields[1] == "b"
        out[key] = -value if black_to_move else value
    return out


def enrich_course(path: Path, explorer, evals: dict, args) -> dict:
    course = json.loads(path.read_text())
    positions = course.get("positions") or {}
    touched = stats_filled = evals_filled = 0

    for key, node in positions.items():
        moves = node.get("moves") or []
        if not moves:
            continue
        board = board_from_key(key)
        club = move_stats(explorer.lichess(board)) if explorer else {}
        masters = {} if args.no_masters or not explorer else move_stats(explorer.masters(board))

        for edge in moves:
            uci = edge.get("uci")
            touched += 1
            if c := club.get(uci):
                edge["gamesClub"] = c["games"]
                edge["popularityClub"] = round(c["share"], 4)
                total = c["games"]
                edge["scoreWhite"] = round(c["white"] / total, 4)
                edge["scoreDraw"] = round(c["draws"] / total, 4)
                edge["scoreBlack"] = round(c["black"] / total, 4)
                stats_filled += 1
            if m := masters.get(uci):
                edge["gamesMasters"] = m["games"]
                edge["popularityMasters"] = round(m["share"], 4)
            # L'évaluation porte sur la position D'ARRIVÉE du coup.
            if (value := evals.get(edge.get("toFEN"))) is not None:
                edge["eval"] = value / 100.0
                evals_filled += 1

    path.write_text(json.dumps(course, ensure_ascii=False, separators=(",", ":")))
    return {"edges": touched, "stats": stats_filled, "evals": evals_filled}


def main(argv=None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])

    if not args.offline and not token_from_environment():
        print(f"\n✗ Aucun jeton Lichess. {TOKEN_HELP}\n", file=sys.stderr)
        return 2

    folder = Path(args.dir)
    wanted = {s.strip() for s in args.only.split(",")} if args.only else None
    evals = load_evals()
    print(f"Évaluations disponibles dans le cache d'audit : {len(evals)}")

    explorer = None if args.offline else LichessExplorer(
        cache_dir=Path(args.cache) / "explorer", speeds=args.speeds,
        ratings=args.ratings, min_delay=args.min_delay,
    )

    totals = {"edges": 0, "stats": 0, "evals": 0}
    for path in sorted(folder.glob("*.json")):
        if path.name == "opening_catalog.json":
            continue
        if wanted and path.stem not in wanted:
            continue
        result = enrich_course(path, explorer, evals, args)
        for k in totals:
            totals[k] += result[k]
        print(f"  · {path.stem:<28} {result['stats']:>4}/{result['edges']:<4} stats"
              f"   {result['evals']:>4} évals", flush=True)

    print(f"\n{totals['edges']} arêtes : {totals['stats']} avec statistiques, "
          f"{totals['evals']} avec évaluation.")
    if explorer:
        print(f"Requêtes réseau : {explorer.request_count} "
              f"(cache : {explorer.cache_hits}), échecs : {len(explorer.failed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
