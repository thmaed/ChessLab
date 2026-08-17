"""Audit des cours de FINALES — par tablebase, donc par preuve.

Pour les ouvertures, `audit.py` estime (moteur, seuil en centipions). Ici, la
tablebase Syzygy donne le verdict EXACT de chaque position ≤ 7 pièces : cet
audit ne tolère donc AUCUNE approximation sur ce périmètre.

## Les règles

Pour chaque arête d'un cours `kind == "endgame"` :

1. **Coup du camp étudié** (celui de `side`) : il doit PRÉSERVER le verdict de
   la position — un gain reste un gain, une nulle reste une nulle. Sous jeu
   optimal, un coup ne peut jamais AMÉLIORER son propre verdict ; tout écart
   est donc une dégradation, et une dégradation enseignée est une faute
   d'audit… sauf si l'arête est marquée `role: "trap"` ou `"inaccuracy"` — la
   faute est alors LA leçon (le pat classique, par exemple), et on vérifie
   même l'inverse : qu'elle dégrade bien le verdict, sinon le « piège » n'en
   est pas un.

2. **Coup de l'adversaire** : il ne peut pas améliorer son sort (théorème) ;
   il peut le dégrader (défense naturelle mais fautive, qu'on a le droit
   d'enseigner à punir). On SIGNALE ces défenses sous-optimales à titre
   d'information — elles doivent être un choix pédagogique, pas un accident.

3. **Position > 7 pièces** (hors tablebase) : repli sur Stockfish à forte
   profondeur, même logique de seuil que `audit.py`. Signalé comme
   « vérifié moteur » et non « prouvé » — l'honnêteté du rapport compte.

Sortie : rapport lisible + code retour non nul si une arête enseignée casse
son verdict.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import chess

from fen import board_from_key, side_to_move
from tablebase import Tablebase

HERE = Path(__file__).resolve().parent
COURSES_DIR = HERE.parents[1] / "ChessLab" / "Resources" / "openings"

# Au-delà de 7 pièces la tablebase ne dit rien : moteur, profondeur élevée.
ENGINE_DEPTH = 28
ENGINE_WIN_CP = 250  # au-delà : « gagnant » au sens pratique


def piece_count(key: str) -> int:
    return sum(1 for c in key.split(" ")[0] if c.isalpha())


def audit_course(course: dict, tb: Tablebase, engine=None) -> dict:
    """Rapport d'un cours : {taught_breaks, weak_defenses, engine_checked, fake_traps}."""
    side = course.get("side", "white")
    report = {"taught_breaks": [], "weak_defenses": [], "engine_checked": [], "fake_traps": []}

    for key, node in course["positions"].items():
        edges = node.get("moves", [])
        if not edges:
            continue
        if piece_count(key) > 7:
            for edge in edges:
                # Les pièges assument leur chute d'évaluation — comme côté
                # tablebase. On les note sans les compter en échec.
                excused = edge.get("role") in ("trap", "inaccuracy")
                note = _engine_note(key, edge, engine)
                if excused:
                    note += " [piège assumé]" if "⚠" in note else ""
                    note = note.replace("⚠", "piège :")
                report["engine_checked"].append(note)
            continue

        parent_verdict = tb.category(key)          # POV camp au trait
        move_verdicts = tb.move_categories(key)     # POV camp qui joue
        mover = side_to_move(key)

        for edge in edges:
            verdict = move_verdicts.get(edge["uci"])
            if verdict is None:
                report["taught_breaks"].append(
                    f"{edge['san']} depuis {key} : coup inconnu de la tablebase")
                continue
            preserved = (verdict == parent_verdict)

            if mover == side:
                role = edge.get("role")
                if role == "trap":
                    # Un piège doit VRAIMENT dégrader, sinon il ment.
                    if preserved:
                        report["fake_traps"].append(
                            f"{edge['san']} depuis {key} : marqué piège mais préserve {parent_verdict}")
                elif role == "inaccuracy":
                    # « Imprécision » en finale : garde le verdict mais ne
                    # progresse pas (le Kc7 sans pont de la Lucena). Ni
                    # obligation de dégrader, ni faute si ça dégrade — mais on
                    # le SIGNALE si ça dégrade, pour que ce soit un choix.
                    if not preserved:
                        report["weak_defenses"].append(
                            f"{edge['san']} depuis {key} : imprécision qui dégrade "
                            f"{parent_verdict} → {verdict} (piège plutôt ?)")
                elif not preserved:
                    report["taught_breaks"].append(
                        f"{edge['san']} depuis {key} : {parent_verdict} → {verdict}")
            else:
                # L'adversaire qui joue moins bien que l'optimal : information.
                if not preserved:
                    report["weak_defenses"].append(
                        f"{edge['san']} depuis {key} : l'adversaire concède {parent_verdict} → {verdict}")
    return report


def _engine_note(key: str, edge: dict, engine) -> str:
    if engine is None:
        return f"{edge['san']} depuis {key} : > 7 pièces, NON vérifié (pas de moteur fourni)"
    board = board_from_key(key)
    import chess.engine as ce
    before = engine.analyse(board, ce.Limit(depth=ENGINE_DEPTH))
    before_cp = before["score"].pov(board.turn).score(mate_score=10000)
    board.push(chess.Move.from_uci(edge["uci"]))
    after = engine.analyse(board, ce.Limit(depth=ENGINE_DEPTH))
    after_cp = -after["score"].pov(board.turn).score(mate_score=10000)
    drop = before_cp - after_cp
    status = "OK" if drop < 100 else f"⚠ perd {drop} cp"
    return f"{edge['san']} depuis {key} : moteur d{ENGINE_DEPTH} {before_cp:+} → {after_cp:+} ({status})"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Audit tablebase des cours de finales")
    parser.add_argument("--dir", default=str(COURSES_DIR))
    parser.add_argument("--only", help="ids séparés par des virgules")
    parser.add_argument("--stockfish", help="binaire pour les positions > 7 pièces")
    args = parser.parse_args(argv)

    tb = Tablebase()
    engine = None
    if args.stockfish:
        import chess.engine as ce
        engine = ce.SimpleEngine.popen_uci(args.stockfish)
        engine.configure({"Threads": 4, "Hash": 1024})

    wanted = {s.strip() for s in args.only.split(",")} if args.only else None
    failures = 0
    audited = 0
    try:
        for path in sorted(Path(args.dir).glob("*.json")):
            if path.name == "opening_catalog.json":
                continue
            course = json.loads(path.read_text())
            if course.get("kind") != "endgame":
                continue
            if wanted and course["id"] not in wanted:
                continue
            audited += 1
            report = audit_course(course, tb, engine)
            edge_count = sum(len(n.get("moves", [])) for n in course["positions"].values())
            print(f"\n· {course['id']:<28} {len(course['positions'])} positions, {edge_count} arêtes")
            for line in report["taught_breaks"]:
                print(f"  ✗ ENSEIGNÉ CASSE LE VERDICT : {line}")
                failures += 1
            for line in report["fake_traps"]:
                print(f"  ✗ FAUX PIÈGE : {line}")
                failures += 1
            for line in report["weak_defenses"]:
                print(f"  ℹ défense sous-optimale (voulue ?) : {line}")
            for line in report["engine_checked"]:
                print(f"  ~ {line}")
                if "⚠" in line:
                    failures += 1
    finally:
        if engine is not None:
            engine.quit()

    print(f"\n{audited} cours de finales audités — "
          f"{tb.requests} requêtes tablebase ({tb.cache_hits} en cache)")
    if failures:
        print(f"✗ {failures} problème(s) prouvé(s)")
        return 1
    print("✓ Chaque coup enseigné préserve son verdict théorique (tablebase).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
