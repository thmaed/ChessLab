"""Normalisation FEN — clé canonique du graphe et de la progression.

DOIT rester rigoureusement identique à `OpeningFENKey.swift` côté app : les
clés produites ici sont lues telles quelles par Swift et indexent la
progression FSRS synchronisée. Toute divergence casserait la fusion des
transpositions et, pire, dissocierait la progression de l'utilisateur des
positions.

Règle (cf. OpeningFENKey.key) : on garde les 4 premiers champs FEN (placement,
trait, roques, prise en passant), on jette les compteurs, et le champ « en
passant » n'est conservé que si une prise en passant est réellement LÉGALE —
exactement `board.has_legal_en_passant()` de python-chess, qui correspond au
critère « legalMoves contient la case e.p. » du Swift (vérifié).
"""
from __future__ import annotations

import chess


def normalize_fen(board: chess.Board) -> str:
    """Clé canonique de la position (4 champs, e.p. légale seulement)."""
    placement, turn, castling = board.fen().split(" ")[:3]
    ep = "-"
    if board.ep_square is not None and board.has_legal_en_passant():
        ep = chess.square_name(board.ep_square)
    return f"{placement} {turn} {castling} {ep}"


def board_from_key(key: str) -> chess.Board:
    """Reconstruit un Board depuis une clé (4 champs) en complétant les
    compteurs, symétrique de `OpeningFENKey.position(from:)`."""
    fields = key.split(" ")
    if len(fields) == 4:
        key = key + " 0 1"
    return chess.Board(key)


def side_to_move(key: str) -> str:
    """« white »/« black » d'après le champ 2 de la clé."""
    return "black" if key.split(" ")[1] == "b" else "white"
