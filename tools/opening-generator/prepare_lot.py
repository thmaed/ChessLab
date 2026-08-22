#!/usr/bin/env python3
"""Prépare un lot de contenu : les N trous les plus coûteux d'un cours, avec le
chemin EXACT qui y mène et la meilleure suite du moteur.

Enchaîne ce qui était fait à la main lot après lot :
  1. lire le rapport de couverture, garder les vrais trous du cours ;
  2. écarter les faux positifs (coup déjà couvert dans le cours compilé) ;
  3. reconstruire le chemin depuis la racine par parcours du graphe — JAMAIS
     en lisant la FEN à l'œil, trois séquences sur cinq en étaient fausses ;
  4. demander au moteur la suite après le coup adverse du trou.

Il ne rédige rien : les commentaires bilingues restent écrits à la main, c'est
le seul travail qui compte vraiment ici.

    python3 prepare_lot.py colle-system --report rapport.json --top 5
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUNDLE = HERE.parent.parent / "ChessLab" / "Resources" / "openings"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("course")
    parser.add_argument("--report", required=True, help="JSON produit par coverage.py")
    parser.add_argument("--top", type=int, default=5)
    parser.add_argument("--depth", type=int, default=21)
    parser.add_argument("--length", type=int, default=10)
    args = parser.parse_args(argv)

    report = json.load(open(args.report))
    entry = next((c for c in report if c["id"] == args.course), None)
    if entry is None:
        print(f"✗ {args.course} absent du rapport", file=sys.stderr)
        return 2

    course_path = BUNDLE / f"{args.course}.json"
    positions = json.load(open(course_path))["positions"]

    print(f"# {args.course} — dette {sum(g['priority'] for g in entry['holes']):.2f}, "
          f"{entry['positions']} positions\n")

    shown = 0
    for hole in sorted(entry["holes"], key=lambda h: -h["priority"]):
        node = positions.get(hole["fen"])
        covered = [m["san"] for m in node["moves"]] if node else None
        # Faux positif : le rapport hors ligne peut désigner un coup déjà écrit.
        if node is not None and hole["san"] in covered:
            continue

        path = subprocess.run(
            ["python3", str(HERE / "path_to_hole.py"), str(course_path), hole["fen"]],
            capture_output=True, text=True,
        ).stdout.strip()
        if not path and hole["fen"] != json.load(open(course_path))["rootFEN"]:
            print(f"  ⚠ {hole['san']} : chemin introuvable dans le graphe, ignoré\n")
            continue

        full = f"{path} {hole['san']}".strip()
        print(f"## {hole['san']}  ({hole['share']*100:.1f} % des parties, priorité {hole['priority']:.3f})")
        print(f"   chemin  : {path or '(racine)'}")
        print(f"   couverts: {covered}")
        suggestion = subprocess.run(
            ["python3", str(HERE / "suggest.py"), "--moves", full,
             "--depth", str(args.depth), "--lines", "1", "--length", str(args.length)],
            capture_output=True, text=True, cwd=HERE,
        )
        for line in suggestion.stdout.splitlines():
            if line.strip().startswith(("+", "-", "à coller", "#")) or "à coller" in line:
                print(f"   {line.strip()}")
        print()

        shown += 1
        if shown >= args.top:
            break
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
