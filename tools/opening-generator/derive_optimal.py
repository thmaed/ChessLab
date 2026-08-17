"""Squelette d'une ligne optimale : attaquant DTM-optimal, défenseur coriace.

    python3 derive_optimal.py --fen "…" --plies 24

Imprime la ligne SAN avec, à chaque coup, le DTM — le squelette qu'on annote
ensuite dans `content_endgames/`. Les égalités DTM listent les coups
équivalents : c'est là que l'auteur choisit le coup « de méthode ».
"""
from __future__ import annotations

import argparse

import chess

from tablebase import Tablebase


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fen", required=True)
    parser.add_argument("--plies", type=int, default=24)
    parser.add_argument("--moves", default="", help="préfixe SAN imposé")
    args = parser.parse_args(argv)

    tb = Tablebase()
    board = chess.Board(args.fen)
    for san in args.moves.split():
        board.push_san(san)

    for _ in range(args.plies):
        info = tb.probe(board.fen())
        if not info["moves"] or board.is_game_over():
            break
        moves = info["moves"]
        # L'API trie déjà du meilleur au pire pour le camp au trait ; on prend
        # la tête de liste et on montre les ex æquo DTM.
        best = moves[0]
        ties = [m["san"] for m in moves
                if m["category"] == best["category"] and m.get("dtm") == best.get("dtm")]
        mover = "B" if board.turn else "N"
        note = f" (={' '.join(ties[1:])})" if len(ties) > 1 else ""
        print(f"  {mover} {best['san']:<8} dtm {best.get('dtm')}{note}")
        board.push_san(best["san"])

    print(f"\nFin : {board.fen()}  ({tb.probe(board.fen()).get('category')})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
