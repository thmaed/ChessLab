#!/usr/bin/env python3
"""Audit MOTEUR des cours produits — le garde-fou qualité qui manquait.

`validate.py` ne vérifie que l'intégrité du graphe : légalité des coups,
cohérence des clés FEN, absence d'arête orpheline. Un coup parfaitement légal
peut donc être une gaffe, et il y en avait — un testeur classé les a trouvées
avant nous (Cd5 qui perd une pièce, Db4 qui laisse une tour gratuite en a1).

Ce script rejoue CHAQUE arête sous Stockfish et refuse celles qui perdent plus
de `--threshold` centipions par rapport au meilleur coup, SAUF si l'auteur les
a explicitement annotées `trap` ou `inaccuracy` : dans ce cas le mauvais coup
est le sujet de la leçon, l'app l'affiche avec sa pastille, et c'est légitime.

    python3 audit.py --stockfish "$(which stockfish)"
    python3 audit.py --stockfish ./sf/stockfish --only englund-gambit
    python3 audit.py --stockfish ./sf/stockfish --threshold 200 --json rapport.json

Sortie non nulle si au moins une gaffe non annotée subsiste : utilisable tel
quel comme étape bloquante.

Deux passes, pour tenir en quelques minutes sur ~3 000 positions :
1. une recherche par position UNIQUE (mutualisée entre cours, cache disque) ;
   la perte estimée d'une arête vaut best(parent) − (−best(enfant)) ;
2. les seules arêtes suspectes sont remesurées DEPUIS LA MÊME POSITION via
   `root_moves`, à profondeur supérieure — sans quoi on compare deux
   recherches de profondeurs différentes et on invente des écarts.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from pathlib import Path

import chess
import chess.engine

from fen import board_from_key

HERE = Path(__file__).resolve().parent
DEFAULT_DIR = HERE.parent.parent / "ChessLab" / "Resources" / "openings"

# Rôles qui ASSUMENT un mauvais coup : c'est la leçon, pas une erreur.
EXCUSED_ROLES = {"trap", "inaccuracy"}

# Sacrifices VOULUS, nommés et commentés dans le contenu : le moteur les
# condamnera toujours, c'est la définition d'un gambit. Chaque entrée est une
# décision d'auteur, pas un tapis sous lequel balayer — d'où la raison écrite.
WAIVERS = {
    ("four-knights", "Nxe5"): "gambit Halloween : le sacrifice de cavalier EST le chapitre",
}


def parse_args(argv):
    p = argparse.ArgumentParser(description="Audit moteur des cours d'ouverture")
    p.add_argument("--dir", default=str(DEFAULT_DIR), help="dossier des cours JSON")
    p.add_argument("--only", help="ids séparés par des virgules")
    p.add_argument("--stockfish", help="chemin du binaire (ou nom dans le PATH)")
    p.add_argument("--threshold", type=int, default=150, help="perte tolérée, en centipions")
    p.add_argument("--depth", type=int, default=18, help="profondeur de la passe de balayage")
    p.add_argument("--verify-depth", type=int, default=24, help="profondeur de la contre-mesure")
    p.add_argument("--threads", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    p.add_argument("--hash", type=int, default=2048, help="table de transposition, en Mo")
    p.add_argument("--cache", default=str(HERE / ".cache" / "audit"), help="cache des évaluations")
    p.add_argument("--json", help="écrit le rapport détaillé dans ce fichier")
    p.add_argument("--strict", action="store_true",
                   help="échouer aussi sur les lacunes de couverture (avertissements)")
    return p.parse_args(argv)


def load_courses(directory: str, only: str | None) -> dict:
    wanted = {s.strip() for s in only.split(",")} if only else None
    courses = {}
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        if os.path.basename(path) == "opening_catalog.json":
            continue
        with open(path, encoding="utf-8") as fh:
            course = json.load(fh)
        if wanted and course["id"] not in wanted:
            continue
        courses[course["id"]] = course
    return courses


def resolve_engine(path: str | None) -> str:
    import shutil

    if not path:
        raise SystemExit(
            "✗ Aucun Stockfish fourni. L'audit N'A PAS de mode dégradé : sans moteur\n"
            "  il ne vérifie rien et donnerait un feu vert mensonger.\n"
            "  Passe --stockfish \"$(which stockfish)\"."
        )
    resolved = path if os.path.isfile(path) else shutil.which(path)
    if not resolved or not os.path.isfile(resolved):
        raise SystemExit(f"✗ Stockfish introuvable à « {path} ».")
    return resolved


def sweep(engine, courses, depth, cache_path) -> dict:
    """Passe 1 : une évaluation par position unique, mise en cache sur disque."""
    keys = sorted({k for course in courses.values() for k in course["positions"]})
    cache: dict = {}
    if os.path.exists(cache_path):
        with open(cache_path, encoding="utf-8") as fh:
            cache = json.load(fh)

    todo = [k for k in keys if k not in cache]
    print(f"{len(courses)} cours, {len(keys)} positions ({len(todo)} à évaluer)", file=sys.stderr)
    limit = chess.engine.Limit(depth=depth)
    for i, key in enumerate(todo, 1):
        board = board_from_key(key)
        if board.is_game_over():
            cache[key] = None
        else:
            info = engine.analyse(board, limit)
            cache[key] = info["score"].pov(board.turn).score(mate_score=100000)
        if i % 200 == 0:
            print(f"  {i}/{len(todo)}", file=sys.stderr)
            _save(cache_path, cache)
    _save(cache_path, cache)
    return cache


def _save(path, payload) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh)


def suspects(courses, cache, threshold) -> list:
    """Arêtes dont la perte ESTIMÉE dépasse le seuil, hors rôles assumés."""
    out = []
    for course_id, course in courses.items():
        side = course.get("side")
        for key, node in course["positions"].items():
            parent = cache.get(key)
            if parent is None:
                continue
            for edge in node["moves"]:
                if edge.get("role") in EXCUSED_ROLES:
                    continue
                if (course_id, edge["san"]) in WAIVERS:
                    continue
                child = cache.get(edge["toFEN"])
                if child is None:
                    board = board_from_key(edge["toFEN"])
                    after = 100000 if board.is_checkmate() else 0
                else:
                    after = -child
                if parent - after < threshold:
                    continue
                mover = "white" if key.split(" ")[1] == "w" else "black"
                out.append({"course": course_id, "fen": key, "san": edge["san"],
                            "role": edge.get("role"), "own": mover == side,
                            "terminal": not course["positions"][edge["toFEN"]]["moves"]})
    return out


def severity(row) -> str:
    """Ce qui NUIT à l'élève bloque ; ce qui manque seulement se signale.

    - `error` : un coup de NOTRE répertoire qui perd (on enseignerait une
      faute), ou une fin de chapitre qui perd (la variante s'achève sur une
      gaffe inexpliquée — le défaut exact remonté par le testeur).
    - `warning` : un coup de l'ADVERSAIRE en milieu de ligne qui n'est pas le
      meilleur. On ne ment à personne, mais on ne couvre pas sa meilleure
      défense : c'est une lacune de couverture, à combler quand on approfondit.
    """
    if row["own"] or row["terminal"]:
        return "error"
    return "warning"


def verify(engine, rows, depth, threshold) -> list:
    """Passe 2 : mesure cohérente (même position, même profondeur)."""
    limit = chess.engine.Limit(depth=depth)
    confirmed = []
    for i, row in enumerate(rows, 1):
        board = board_from_key(row["fen"])
        move = board.parse_san(row["san"])
        best = engine.analyse(board, limit)
        book = engine.analyse(board, limit, root_moves=[move])
        best_cp = best["score"].pov(board.turn).score(mate_score=100000)
        book_cp = book["score"].pov(board.turn).score(mate_score=100000)
        if best_cp - book_cp < threshold:
            continue
        scratch = board.copy()
        refutation = []
        for mv in book.get("pv", [])[:6]:
            refutation.append(scratch.san(mv))
            scratch.push(mv)
        confirmed.append({**row, "best": board.san(best["pv"][0]) if best.get("pv") else None,
                          "best_cp": best_cp, "book_cp": book_cp, "loss": best_cp - book_cp,
                          "refutation": " ".join(refutation)})
        print(f"  {i}/{len(rows)}", file=sys.stderr)
    return confirmed


def main(argv=None) -> int:
    args = parse_args(argv or sys.argv[1:])
    binary = resolve_engine(args.stockfish)
    courses = load_courses(args.dir, args.only)
    if not courses:
        raise SystemExit(f"✗ Aucun cours trouvé dans {args.dir}")

    engine = chess.engine.SimpleEngine.popen_uci(binary)
    try:
        engine.configure({"Threads": args.threads, "Hash": args.hash})
        cache = sweep(engine, courses, args.depth, os.path.join(args.cache, f"d{args.depth}.json"))
        rows = suspects(courses, cache, args.threshold)
        print(f"{len(rows)} arêtes suspectes → contre-mesure à la profondeur {args.verify_depth}",
              file=sys.stderr)
        confirmed = verify(engine, rows, args.verify_depth, args.threshold)
    finally:
        engine.quit()

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(confirmed, fh, ensure_ascii=False, indent=1)

    confirmed.sort(key=lambda r: -r["loss"])
    errors = [r for r in confirmed if severity(r) == "error"]
    warnings = [r for r in confirmed if severity(r) == "warning"]

    def report(rows, title):
        print(f"\n{title}\n")
        for r in rows:
            who = "notre camp" if r["own"] else "l'adversaire"
            end = ", fin de chapitre" if r["terminal"] else ""
            print(f"  {r['course']:24} {r['san']:>7} ({who}{end}) {r['book_cp'] / 100:+.2f} "
                  f"au lieu de {r['best']} {r['best_cp'] / 100:+.2f} (perte {r['loss'] / 100:.2f})")
            print(f"      {r['fen']}")
            print(f"      réfutation : {r['refutation']}")

    if warnings:
        report(warnings, f"⚠ {len(warnings)} lacune(s) de couverture — l'adversaire a mieux, "
                         "en milieu de ligne (non bloquant) :")

    if not errors:
        print(f"\n✓ Aucune gaffe enseignée (seuil {args.threshold} cp) sur {len(courses)} cours.")
        return 1 if (warnings and args.strict) else 0

    report(errors, f"✗ {len(errors)} coup(s) fautif(s) enseigné(s) comme bons :")
    print("\nCorrige la ligne dans content/<ouverture>.py, ou annote le coup "
          '`"role": "trap"` / `"inaccuracy"` si la faute EST la leçon.')
    return 1


if __name__ == "__main__":
    sys.exit(main())
