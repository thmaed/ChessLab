#!/usr/bin/env python3
"""Audit du module Ouvertures : les lignes sont-elles PRÊTES ?

`validate.py` contrôle l'intégrité du graphe, `audit.py` la qualité des coups
sous Stockfish. Ni l'un ni l'autre ne répond à la question que pose l'écran
d'index : **chaque ligne est-elle atteignable, nommée, commentée et évaluée ?**

Ce script reconstruit l'ARBRE exactement comme `OpeningLineTree.swift` (une
rangée s'arrête à la première déviation, chaque suite descend d'un étage, une
position n'est dépliée qu'une fois) et mesure, ouverture par ouverture :

- **atteignabilité** — une position que la racine ne rejoint pas n'apparaîtra
  jamais dans l'arbre : c'est du contenu écrit et invisible ;
- **couverture de l'arbre** — une position atteignable mais absente de l'arbre
  serait un bug de construction ;
- **évaluation** — part des positions ayant les trois meilleurs coups du
  sidecar, et part ayant des parties de maîtres ;
- **documentation** — rangées portant un commentaire validé ou un nom de
  variante, et titres de chapitre qui trouvent leur branche.

    python3 audit_opening_stats.py
    python3 audit_opening_stats.py --only scandinavian
    python3 audit_opening_stats.py --quiet     # seulement les anomalies

Sortie non nulle si une anomalie STRUCTURELLE subsiste (position inatteignable,
absente de l'arbre, ou sans évaluation moteur) : utilisable comme étape
bloquante. Les manques de documentation, eux, sont RAPPORTÉS mais non
bloquants — un arbre d'ouverture ne commente pas chacun de ses coups.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COURSES = ROOT / "ChessLab" / "Resources" / "openings"
SIDECARS = ROOT / "ChessLab" / "Resources" / "openings_stats"


def ordered(moves: list[dict]) -> list[dict]:
    """Ligne principale d'abord, puis par popularité club — même ordre que
    `OpeningLineTree.ordered`."""
    return sorted(moves, key=lambda e: (e.get("role") != "mainLine", -(e.get("popularityClub") or 0)))


def build_tree(course: dict) -> tuple[list[dict], set[str]]:
    """Les rangées de l'arbre, et les positions qu'il déplie.

    Miroir de `OpeningLineTree.expand` : une rangée court tant que la position
    n'offre qu'une suite, s'arrête à la première déviation, et chaque suite —
    la principale comprise — descend d'un étage.
    """
    positions = course["positions"]
    expanded = {course["rootFEN"]}
    rows: list[dict] = []

    def walk(entry: dict | None, fen: str, depth: int, on_main: bool) -> None:
        cursor = fen
        moves = [entry] if entry else []
        while True:
            edges = ordered(positions.get(cursor, {}).get("moves", []))
            if not edges:
                rows.append({"depth": depth, "moves": moves, "onMain": on_main})
                return
            if len(edges) == 1:
                edge = edges[0]
                moves.append(edge)
                if edge["toFEN"] in expanded:
                    rows.append({"depth": depth, "moves": moves, "onMain": on_main})
                    return
                expanded.add(edge["toFEN"])
                cursor = edge["toFEN"]
                continue
            rows.append({"depth": depth, "moves": moves, "onMain": on_main})
            for rank, edge in enumerate(edges):
                child_main = on_main and rank == 0
                if edge["toFEN"] in expanded:
                    rows.append({"depth": depth + 1, "moves": [edge], "onMain": child_main})
                    continue
                expanded.add(edge["toFEN"])
                walk(edge, edge["toFEN"], depth + 1, child_main)
            return

    walk(None, course["rootFEN"], 0, True)
    return rows, expanded


def reachable(course: dict) -> set[str]:
    """Positions que la racine rejoint, en parcours en LARGEUR (le graphe a des
    cycles par transposition : une descente naïve ne terminerait pas)."""
    positions = course["positions"]
    seen = {course["rootFEN"]}
    frontier = [course["rootFEN"]]
    while frontier:
        following = []
        for fen in frontier:
            for edge in positions.get(fen, {}).get("moves", []):
                if edge["toFEN"] not in seen:
                    seen.add(edge["toFEN"])
                    following.append(edge["toFEN"])
        frontier = following
    return seen


def spine(course: dict, chapter: dict) -> list[str]:
    """Colonne vertébrale d'un chapitre : son premier tronçon CONTIGU."""
    positions = course["positions"]
    result: list[str] = []
    previous = None
    for fen in chapter["positionFENs"]:
        if previous is not None and not any(
            e["toFEN"] == fen for e in positions.get(previous, {}).get("moves", [])
        ):
            break
        result.append(fen)
        previous = fen
    return result


def placed_titles(course: dict, rows: list[dict]) -> int:
    """Titres de chapitre qui trouvent leur branche — miroir de
    `OpeningLineTree.titles`."""
    positions = course["positions"]
    heads = {row["moves"][0]["toFEN"] for row in rows if row["depth"] > 0 and row["moves"]}
    rank = {}
    for node in positions.values():
        for index, edge in enumerate(ordered(node.get("moves", []))):
            rank.setdefault(edge["toFEN"], index)

    claimed: set[str] = set()
    placed = 0
    for chapter in course.get("chapters") or []:
        for fen in spine(course, chapter) + chapter["positionFENs"]:
            if fen in heads and rank.get(fen, 0) > 0 and fen not in claimed:
                claimed.add(fen)
                placed += 1
                break
    return placed


def audit(course: dict) -> dict:
    positions = course["positions"]
    rows, expanded = build_tree(course)
    reach = reachable(course)

    sidecar_path = SIDECARS / f"{course['id']}.stats.json"
    sidecar = {}
    if sidecar_path.exists():
        sidecar = json.loads(sidecar_path.read_text()).get("positions", {})

    named = {fen for fen, node in positions.items() if node.get("ecoName")}
    documented = sum(
        1
        for row in rows
        if row["moves"]
        and (
            any(e.get("commentStatus") == "validated" for e in row["moves"])
            or any(e["toFEN"] in named for e in row["moves"])
        )
    )
    chapters = course.get("chapters") or []

    return {
        "id": course["id"],
        "positions": len(positions),
        "unreachable": len(positions) - len(reach),
        "missingFromTree": len(reach) - len(expanded),
        "rows": len(rows),
        "depth": max((r["depth"] for r in rows), default=0),
        "mainRows": sum(1 for r in rows if r["onMain"]),
        "engine": sum(1 for fen in positions if sidecar.get(fen, {}).get("engine")),
        "masters": sum(1 for fen in positions if sidecar.get(fen, {}).get("masters")),
        "documented": documented,
        "chapters": len(chapters),
        "titlesPlaced": placed_titles(course, rows),
        "hasSidecar": sidecar_path.exists(),
    }


def blocking(report: dict) -> list[str]:
    """Les anomalies qui doivent faire échouer : du contenu invisible, ou une
    position que l'écran afficherait sans aucune évaluation."""
    issues = []
    if not report["hasSidecar"]:
        issues.append("aucun sidecar de statistiques")
    if report["unreachable"]:
        issues.append(f"{report['unreachable']} positions inatteignables depuis la racine")
    if report["missingFromTree"]:
        issues.append(f"{report['missingFromTree']} positions atteignables mais absentes de l'arbre")
    missing = report["positions"] - report["engine"]
    if missing:
        issues.append(f"{missing} positions sans évaluation moteur")
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="limiter à un identifiant de cours")
    parser.add_argument("--quiet", action="store_true", help="n'afficher que les anomalies")
    args = parser.parse_args()

    reports = []
    for path in sorted(COURSES.glob("*.json")):
        if path.name == "opening_catalog.json":
            continue
        course = json.loads(path.read_text())
        if course.get("kind") == "endgame":
            continue
        if args.only and course["id"] != args.only:
            continue
        reports.append(audit(course))

    if not reports:
        print("✗ aucune ouverture trouvée.", file=sys.stderr)
        return 1

    if not args.quiet:
        header = f"{'ouverture':24} {'pos':>4} {'rang':>5} {'prof':>4} {'ppal':>5} {'mot':>5} {'maî':>5} {'doc':>5} {'titres':>8}"
        print(header)
        print("-" * len(header))
        for r in reports:
            print(
                f"{r['id']:24} {r['positions']:>4} {r['rows']:>5} {r['depth']:>4} "
                f"{r['mainRows']:>5} "
                f"{100 * r['engine'] / r['positions']:>4.0f}% "
                f"{100 * r['masters'] / r['positions']:>4.0f}% "
                f"{100 * r['documented'] / max(1, r['rows']):>4.0f}% "
                f"{r['titlesPlaced']:>3}/{r['chapters']:<4}"
            )
        print("-" * len(header))
        total = {k: sum(r[k] for r in reports) for k in
                 ("positions", "rows", "mainRows", "engine", "masters", "documented", "chapters", "titlesPlaced")}
        print(
            f"{'TOTAL':24} {total['positions']:>4} {total['rows']:>5} {'':>4} "
            f"{total['mainRows']:>5} "
            f"{100 * total['engine'] / total['positions']:>4.0f}% "
            f"{100 * total['masters'] / total['positions']:>4.0f}% "
            f"{100 * total['documented'] / total['rows']:>4.0f}% "
            f"{total['titlesPlaced']:>3}/{total['chapters']:<4}"
        )

    failures = [(r["id"], issue) for r in reports for issue in blocking(r)]
    print()
    if failures:
        print(f"✗ {len(failures)} anomalies bloquantes :")
        for course_id, issue in failures:
            print(f"   {course_id} : {issue}")
        return 1
    print(f"✓ {len(reports)} ouvertures : aucune anomalie structurelle.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
