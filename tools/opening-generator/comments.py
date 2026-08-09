#!/usr/bin/env python3
"""Édition EN MASSE des commentaires pédagogiques d'un cours — export/import CSV.

Les coups et statistiques sont générés ; les COMMENTAIRES, eux, sont rédigés à
la main (règle stricte). Ce petit outil sort un CSV — une ligne par arête —
que l'on relit ouverture par ouverture dans n'importe quel tableur, puis
réinjecte les textes dans le fichier de cours.

RÈGLE APPLIQUÉE À L'IMPORT : un commentaire non explicitement marqué
« validated » reste « draft » — l'app n'affiche JAMAIS un brouillon comme du
contenu définitif (cf. MoveEdge.displayableComment côté Swift). On ne valide
donc jamais automatiquement.

Clé de correspondance : (from_fen, uci) — stable même si l'arbre est régénéré.

Usage :
    python3 comments.py export --course out/openings/scandinavian.json --out scandinavian.csv
    # ... on édite les colonnes `comment` et `status` dans un tableur ...
    python3 comments.py import --course out/openings/scandinavian.json --comments scandinavian.csv
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import sys
from pathlib import Path

FIELDNAMES = ["course_id", "from_fen", "uci", "san", "status", "comment"]
VALID_STATUS = {"draft", "validated"}


def export_csv(course: dict) -> str:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=FIELDNAMES)
    writer.writeheader()
    course_id = course.get("id", "")
    for from_fen, node in course.get("positions", {}).items():
        for edge in node.get("moves", []):
            writer.writerow({
                "course_id": course_id,
                "from_fen": from_fen,
                "uci": edge.get("uci", ""),
                "san": edge.get("san", ""),
                "status": edge.get("commentStatus", "") or "",
                "comment": edge.get("comment", "") or "",
            })
    return buf.getvalue()


def import_csv(course: dict, csv_text: str) -> dict:
    """Réinjecte les commentaires du CSV dans le cours. Retourne un bilan."""
    positions = course.get("positions", {})
    reader = csv.DictReader(io.StringIO(csv_text))
    updated = 0
    validated = 0
    drafts = 0
    unmatched = 0
    for row in reader:
        from_fen = (row.get("from_fen") or "").strip()
        uci = (row.get("uci") or "").strip()
        comment = (row.get("comment") or "").strip()
        status = (row.get("status") or "").strip()

        node = positions.get(from_fen)
        edge = next((e for e in node.get("moves", []) if e.get("uci") == uci), None) if node else None
        if edge is None:
            if from_fen or uci:
                unmatched += 1
            continue

        if not comment:
            edge.pop("comment", None)
            edge.pop("commentStatus", None)
            continue

        edge["comment"] = comment
        # JAMAIS de validation automatique : tout sauf « validated » = brouillon.
        edge["commentStatus"] = "validated" if status == "validated" else "draft"
        updated += 1
        if edge["commentStatus"] == "validated":
            validated += 1
        else:
            drafts += 1

    return {"updated": updated, "validated": validated, "drafts": drafts, "unmatched": unmatched}


def displayable_comment(edge: dict) -> str | None:
    """Miroir de MoveEdge.displayableComment (Swift) : seul un commentaire
    explicitement validé et non vide est affichable comme définitif."""
    if edge.get("commentStatus") == "validated" and edge.get("comment"):
        return edge["comment"]
    return None


def _main(argv) -> int:
    p = argparse.ArgumentParser(description="Édition en masse des commentaires d'un cours")
    sub = p.add_subparsers(dest="cmd", required=True)

    pe = sub.add_parser("export", help="cours JSON -> CSV")
    pe.add_argument("--course", required=True)
    pe.add_argument("--out", help="fichier CSV (défaut: stdout)")

    pi = sub.add_parser("import", help="CSV -> cours JSON (réécrit le cours)")
    pi.add_argument("--course", required=True)
    pi.add_argument("--comments", required=True)
    pi.add_argument("--out", help="fichier de sortie (défaut: réécrit --course)")

    args = p.parse_args(argv)
    course = json.loads(Path(args.course).read_text())

    if args.cmd == "export":
        text = export_csv(course)
        if args.out:
            Path(args.out).write_text(text)
            print(f"Exporté {args.out}")
        else:
            sys.stdout.write(text)
        return 0

    stats = import_csv(course, Path(args.comments).read_text())
    dest = Path(args.out) if args.out else Path(args.course)
    dest.write_text(json.dumps(course, ensure_ascii=False, separators=(",", ":")))
    print(f"Importé dans {dest}: {stats}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
