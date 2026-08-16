#!/usr/bin/env python3
"""Ce que le moteur joue dans une position — l'outil d'écriture des variantes.

`coverage.py` dit OÙ un cours laisse l'élève sans réponse ; `audit.py` dit si
ce qu'on a écrit est une gaffe. Entre les deux il manquait de quoi ÉCRIRE :
demander au moteur la meilleure réponse et sa suite, dans la notation même des
fichiers `content/*.py`.

Sans lui, combler un trou revient à taper des coups de mémoire puis à espérer
qu'`audit.py` ne les rejette pas — exactement la méthode qui a produit les 15
gaffes trouvées par le testeur.

    python3 suggest.py --moves "e4 d5 exd5 Nf6 Nc3" --depth 22
    python3 suggest.py --fen "…" --lines 3

Sortie : la meilleure suite en SAN, prête à coller dans un chapitre, avec
l'évaluation du point de vue du camp au trait.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import chess
import chess.engine

# Le binaire vit ICI, hors du paquet vendorisé : y laisser quoi que ce soit
# d'étranger casse la compilation de l'app (voir le README).
DEFAULT_ENGINE = Path(__file__).resolve().parent / "bin" / "stockfish"


def parse_args(argv):
    p = argparse.ArgumentParser(description="Meilleure suite du moteur, en SAN")
    p.add_argument("--moves", default="", help="coups SAN séparés par des espaces depuis la position initiale")
    p.add_argument("--fen", help="position de départ (défaut : position initiale)")
    p.add_argument("--depth", type=int, default=22)
    p.add_argument("--lines", type=int, default=1, help="nombre de variantes candidates")
    p.add_argument("--length", type=int, default=8, help="demi-coups de suite à afficher")
    p.add_argument("--engine", default=str(DEFAULT_ENGINE))
    return p.parse_args(argv)


def board_from(args) -> chess.Board:
    board = chess.Board(args.fen) if args.fen else chess.Board()
    for san in args.moves.split():
        board.push_san(san)
    return board


def resolve_engine(path: str) -> str:
    if Path(path).exists():
        return path
    found = shutil.which("stockfish")
    if found:
        return found
    raise SystemExit(
        f"✗ Moteur introuvable : {path}\n"
        "  Compiler le binaire vendorisé :\n"
        "    cd Vendor/CStockfish/Sources/CStockfish/stockfish\n"
        "    cp _main.cpp main.cpp && make -j8 build ARCH=apple-silicon"
    )


def san_line(board: chess.Board, moves) -> str:
    """Suite en SAN NUMÉROTÉE, lisible telle quelle dans un commentaire."""
    out, temp = [], board.copy()
    for move in moves:
        number = temp.fullmove_number
        prefix = f"{number}." if temp.turn == chess.WHITE else (f"{number}…" if not out else "")
        out.append(prefix + temp.san(move))
        temp.push(move)
    return " ".join(out)


def python_literal(board: chess.Board, moves) -> str:
    """Les mêmes coups au format `content/*.py`, prêts à coller."""
    out, temp = [], board.copy()
    for move in moves:
        out.append(f'"{temp.san(move)}"')
        temp.push(move)
    return ", ".join(out)


def main(argv=None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    board = board_from(args)
    engine_path = resolve_engine(args.engine)

    print(f"Position : {board.fen()}")
    print(f"Trait    : {'Blancs' if board.turn == chess.WHITE else 'Noirs'}\n")

    with chess.engine.SimpleEngine.popen_uci(engine_path) as engine:
        infos = engine.analyse(
            board, chess.engine.Limit(depth=args.depth), multipv=args.lines
        )
        if isinstance(infos, dict):
            infos = [infos]
        for rank, info in enumerate(infos, 1):
            pv = info.get("pv", [])[: args.length]
            if not pv:
                continue
            score = info["score"].pov(board.turn)
            label = f"#{rank}" if args.lines > 1 else "  "
            print(f"{label} {score.score(mate_score=10000) / 100:+.2f}  {san_line(board, pv)}")
            print(f"     à coller : {python_literal(board, pv)}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
