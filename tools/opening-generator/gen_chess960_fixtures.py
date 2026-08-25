#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fixtures d'ORACLE pour la couche Chess960 de l'app.

python-chess implémente le Chess960 nativement (génération Scharnagl, roque
roi-prend-tour, SAN, droits Shredder) : c'est une base de code indépendante et
éprouvée — même rôle que la tablebase Syzygy pour les Finales. Les fixtures
sont générées ICI et consommées par les tests Swift : le Swift se conforme à
l'oracle, jamais l'inverse.

Trois fichiers, écrits dans ChessLabTests/ (embarqués dans le bundle de test) :

- Fixtures_chess960_starts.json   : les 960 FEN de départ (Shredder), par n°.
- Fixtures_chess960_perft.json    : comptes perft — départs et milieux de
  partie riches en droits de roque. C'est LE garde-fou : une génération de
  coups fausse ne peut pas donner les bons comptes.
- Fixtures_chess960_playouts.json : parties aléatoires BIAISÉES VERS LE ROQUE
  (le geste le plus délicat de la variante), coup par coup — uci
  roi-prend-tour comme sous UCI_Chess960, SAN, et FEN Shredder après coup.
  Valide l'application des coups, la tenue des droits et la notation.

Déterministe (graine fixe) : regénérer ne change rien tant que python-chess
ne change pas — les diffs de fixtures restent lisibles.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

import chess

OUT = Path(__file__).resolve().parents[2] / "ChessLabTests"
SEED = 960


def perft(board: chess.Board, depth: int) -> int:
    if depth == 0:
        return 1
    total = 0
    for move in board.legal_moves:
        board.push(move)
        total += perft(board, depth - 1)
        board.pop()
    return total


def starts() -> dict:
    return {str(n): chess.Board.from_chess960_pos(n).fen(shredder=True, en_passant="fen") for n in range(960)}


def midgame_positions(rng: random.Random, count: int) -> list[chess.Board]:
    """Positions de milieu de partie qui CONSERVENT des droits de roque —
    c'est là que la génération 960 se distingue le plus de la classique."""
    found = []
    while len(found) < count:
        board = chess.Board.from_chess960_pos(rng.randrange(960))
        for _ in range(rng.randrange(6, 16)):
            moves = list(board.legal_moves)
            if not moves or board.is_game_over():
                break
            board.push(rng.choice(moves))
        if board.is_game_over() or not board.castling_rights:
            continue
        found.append(board)
    return found


def perft_fixture(rng: random.Random) -> list[dict]:
    entries = []
    start_numbers = rng.sample(range(960), 20)
    for n in start_numbers:
        board = chess.Board.from_chess960_pos(n)
        depths = {str(d): perft(board, d) for d in (1, 2, 3)}
        entries.append({"name": f"start-{n}", "fen": board.fen(shredder=True, en_passant="fen"), "perft": depths})
    # Quelques départs plus profonds : la profondeur 4 exerce les interactions
    # roque × clouages × en passant qu'une profondeur 3 peut rater.
    for n in rng.sample(start_numbers, 4):
        board = chess.Board.from_chess960_pos(n)
        entries.append({"name": f"start-{n}-d4", "fen": board.fen(shredder=True, en_passant="fen"),
                        "perft": {"4": perft(board, 4)}})
    for i, board in enumerate(midgame_positions(rng, 15)):
        depths = {str(d): perft(board, d) for d in (1, 2, 3)}
        entries.append({"name": f"midgame-{i}", "fen": board.fen(shredder=True, en_passant="fen"), "perft": depths})
    return entries


def playouts_fixture(rng: random.Random) -> list[dict]:
    games = []
    castles_seen = 0
    while len(games) < 40:
        n = rng.randrange(960)
        board = chess.Board.from_chess960_pos(n)
        moves = []
        for _ in range(60):
            if board.is_game_over():
                break
            legal = list(board.legal_moves)
            castles = [m for m in legal if board.is_castling(m)]
            # Biais assumé : le roque est LE geste à valider, on le joue dès
            # qu'il se présente (7 fois sur 10).
            move = rng.choice(castles) if castles and rng.random() < 0.7 else rng.choice(legal)
            san = board.san(move)
            uci = move.uci()  # en mode chess960 : roi-prend-tour, comme l'UCI moteur
            if board.is_castling(move):
                castles_seen += 1
            board.push(move)
            moves.append({"uci": uci, "san": san, "fen": board.fen(shredder=True, en_passant="fen")})
        games.append({"number": n,
                      "startFEN": chess.Board.from_chess960_pos(n).fen(shredder=True, en_passant="fen"),
                      "moves": moves})
    assert castles_seen >= 40, f"trop peu de roques exercés : {castles_seen}"
    return games


def main() -> None:
    rng = random.Random(SEED)
    (OUT / "Fixtures_chess960_starts.json").write_text(
        json.dumps(starts(), indent=1) + "\n")
    fixture = perft_fixture(rng)
    (OUT / "Fixtures_chess960_perft.json").write_text(
        json.dumps(fixture, indent=1) + "\n")
    playouts = playouts_fixture(rng)
    (OUT / "Fixtures_chess960_playouts.json").write_text(
        json.dumps(playouts, indent=1) + "\n")
    total_nodes = sum(sum(e["perft"].values()) for e in fixture)
    total_moves = sum(len(g["moves"]) for g in playouts)
    print(f"starts: 960 | perft: {len(fixture)} positions, {total_nodes} nœuds "
          f"| playouts: {len(playouts)} parties, {total_moves} coups")


if __name__ == "__main__":
    main()
