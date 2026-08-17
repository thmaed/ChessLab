"""Outil d'ÉCRITURE des cours de finales — le pendant de `suggest.py`.

Deux usages :

    # Rejouer une ligne et voir le verdict de CHAQUE coup (⇒ rien de mémoire) :
    python3 verify_line.py --fen "…" --moves "Rd1+ Ke7 Rd4"

    # Explorer une position : tous les coups légaux groupés par verdict, DTM
    # trié — de quoi choisir la défense optimale ET la défense naturelle :
    python3 verify_line.py --fen "…" --explore

La règle de la maison depuis la Teichmann du Blackmar-Diemer : une ligne
écrite de mémoire a déjà perdu une tour en h1. Ici l'oracle est exact, autant
écrire SOUS son contrôle plutôt qu'espérer passer l'audit ensuite.
"""
from __future__ import annotations

import argparse

import chess

from tablebase import Tablebase


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fen", required=True)
    parser.add_argument("--moves", default="")
    parser.add_argument("--explore", action="store_true")
    args = parser.parse_args(argv)

    tb = Tablebase()
    board = chess.Board(args.fen)

    for san in args.moves.split():
        mover = "Blancs" if board.turn else "Noirs"
        parent = tb.category(board.fen())
        cats = tb.move_categories(board.fen())
        move = board.parse_san(san)
        verdict = cats.get(move.uci(), "?")
        marker = "✓" if verdict == parent else "⚠ CHANGE LE VERDICT"
        print(f"  {mover:<7} {san:<8} position={parent:<5} coup={verdict:<5} {marker}")
        board.push(move)

    final = tb.probe(board.fen())
    print(f"\nPosition finale : {tb.category(board.fen())} "
          f"(dtm {final.get('dtm')}) — {board.fen()}")

    if args.explore:
        cats = tb.move_categories(board.fen())
        detail = {m["uci"]: m for m in tb.probe(board.fen())["moves"]}
        print("\nCoups par verdict (dtm de la position atteinte) :")
        for wanted in ("win", "draw", "loss"):
            group = [(u, c) for u, c in cats.items() if c == wanted]
            if not group:
                continue
            print(f"  {wanted.upper()} :")
            group.sort(key=lambda t: abs(detail[t[0]].get("dtm") or 999))
            for uci, _ in group:
                san = board.san(chess.Move.from_uci(uci))
                print(f"    {san:<8} dtm {detail[uci].get('dtm')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
