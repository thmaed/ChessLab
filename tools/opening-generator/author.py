#!/usr/bin/env python3
"""Compilateur d'AUTEUR (aucun réseau) : transforme une spec de variantes
écrite à la main en fichiers `OpeningCourse` valides.

Le contenu (coups + commentaires bilingues FR/EN) est rédigé à la main dans
`content/<ouverture>.py` ; ce compilateur en dérive le graphe : clés FEN
normalisées (identiques à Swift), transpositions FUSIONNÉES, rôles, commentaires.
Il rejoue chaque coup avec python-chess (donc légalité garantie), valide le
graphe (miroir du validateur Swift) puis écrit le JSON, et reconstruit
`opening_catalog.json` en scannant le dossier.

Usage :
    python3 author.py                      # écrit dans ../../ChessLab/Resources/openings
    python3 author.py --out /chemin/dir
    python3 author.py --only scandinavian
"""
from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import chess

from fen import normalize_fen, side_to_move
from models import CatalogEntry, MoveEdge, OpeningChapter, OpeningCourse, PositionNode
from validate import validate_course

HERE = Path(__file__).resolve().parent
DEFAULT_OUT = HERE.parent.parent / "ChessLab" / "Resources" / "openings"


def _split(item):
    """Un coup de spec : soit 'e4', soit {'san': 'e4', 'comment': {...}, ...}."""
    if isinstance(item, str):
        return item, {}
    data = dict(item)
    return data.pop("san"), data


def build_course(spec: dict) -> OpeningCourse:
    positions: dict[str, PositionNode] = {}
    edges_by_key: dict[str, dict[str, MoveEdge]] = {}
    chapters: dict[str, OpeningChapter] = {}

    root_key = normalize_fen(chess.Board())

    def ensure(key: str) -> PositionNode:
        node = positions.get(key)
        if node is None:
            node = PositionNode(fen=key)
            positions[key] = node
        return node

    ensure(root_key)

    for line_index, line in enumerate(spec["lines"]):
        is_main = line_index == 0
        board = chess.Board()
        cur_key = root_key

        chapter = None
        ch = line.get("chapter")
        if ch:
            chapter = chapters.get(ch["id"])
            if chapter is None:
                chapter = OpeningChapter(id=ch["id"], title=ch.get("title"), summary=ch.get("summary"), positionFENs=[])
                chapters[ch["id"]] = chapter
            if root_key not in chapter.positionFENs:
                chapter.positionFENs.append(root_key)

        for item in line["moves"]:
            san_in, ann = _split(item)
            move = board.parse_san(san_in)
            san = board.san(move)
            uci = move.uci()
            board.push(move)
            to_key = normalize_fen(board)
            node = ensure(to_key)

            # Annotations portées par le NŒUD atteint.
            if ann.get("eco"):
                node.ecoName = ann["eco"]
            if ann.get("plan"):
                node.plan = ann["plan"]
            if ann.get("keySquares"):
                node.keySquares = ann["keySquares"]

            # Arête (fusion des transpositions : une seule par uci et par nœud).
            slot = edges_by_key.setdefault(cur_key, {})
            edge = slot.get(uci)
            if edge is None:
                role = ann.get("role") or ("mainLine" if is_main else "sideline")
                edge = MoveEdge(san=san, uci=uci, toFEN=to_key, role=role)
                slot[uci] = edge
                positions[cur_key].moves.append(edge)
            # Les annotations explicites priment (même sur une arête déjà créée).
            if ann.get("role"):
                edge.role = ann["role"]
            if ann.get("comment"):
                edge.comment = ann["comment"]
                edge.commentStatus = ann.get("commentStatus", "validated")
            if ann.get("critical"):
                edge.isCritical = True

            if chapter is not None and to_key not in chapter.positionFENs:
                chapter.positionFENs.append(to_key)
            cur_key = to_key

    return OpeningCourse(
        id=spec["id"], name=spec["name"], rootFEN=root_key,
        side=spec["side"], level=spec.get("level", "club"),
        eco=spec.get("eco"), summary=spec.get("summary"),
        chapters=list(chapters.values()), positions=positions,
    )


def _measure_depth(course_dict: dict) -> int:
    positions = course_dict["positions"]
    root = course_dict["rootFEN"]
    seen = {root: 0}
    queue = deque([root])
    best = 0
    while queue:
        key = queue.popleft()
        best = max(best, seen[key])
        for edge in positions.get(key, {}).get("moves", []):
            if edge["toFEN"] not in seen:
                seen[edge["toFEN"]] = seen[key] + 1
                queue.append(edge["toFEN"])
    return best


def rebuild_catalog(out_dir: Path, order: list[str] | None = None) -> list[dict]:
    """Reconstruit opening_catalog.json en scannant TOUS les cours du dossier.

    `order` (ids) impose l'ordre d'affichage pédagogique (1.e4 blanc, réponses à
    1.e4, 1.d4, etc.) ; les cours hors liste passent en fin, par ordre alpha.
    """
    rank = {cid: i for i, cid in enumerate(order or [])}
    paths = sorted(out_dir.glob("*.json"), key=lambda p: (rank.get(p.stem, len(rank)), p.stem))
    entries = []
    for path in paths:
        if path.name == "opening_catalog.json":
            continue
        course = json.loads(path.read_text())
        entries.append(CatalogEntry(
            id=course["id"], name=course["name"],
            side=course.get("side", "white"), level=course.get("level", "club"),
            eco=course.get("eco"), summary=course.get("summary"),
            positionCount=len(course.get("positions", {})),
            maxDepth=_measure_depth(course),
        ).to_dict())
    (out_dir / "opening_catalog.json").write_text(
        json.dumps(entries, ensure_ascii=False, separators=(",", ":"))
    )
    return entries


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Compilateur d'ouvertures rédigées à la main")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--only", help="ids séparés par des virgules")
    args = parser.parse_args(argv)

    import content
    specs = content.COURSES
    if args.only:
        wanted = {s.strip() for s in args.only.split(",")}
        specs = [s for s in specs if s["id"] in wanted]

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    for spec in specs:
        try:
            course = build_course(spec)
        except Exception as exc:  # noqa: BLE001 - une ouverture ratée n'arrête pas le lot
            print(f"  ! {spec['id']:<22} erreur de construction : {exc}")
            continue
        course_dict = course.to_dict()
        issues = validate_course(course_dict)
        if issues:
            print(f"  ! {spec['id']} : intégrité ({len(issues)}) {issues[:3]}")
            continue
        (out_dir / f"{spec['id']}.json").write_text(
            json.dumps(course_dict, ensure_ascii=False, separators=(",", ":"))
        )
        stats = {"positions": len(course_dict["positions"]), "depth": _measure_depth(course_dict)}
        commented = sum(1 for n in course_dict["positions"].values() for e in n["moves"] if e.get("comment"))
        print(f"  ✓ {spec['id']:<22} {stats['positions']:>4} positions, prof {stats['depth']:>2}, {commented} commentaires")

    catalog = rebuild_catalog(out_dir, order=[c["id"] for c in content.COURSES])
    print(f"\nCatalogue reconstruit : {len(catalog)} cours dans {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
