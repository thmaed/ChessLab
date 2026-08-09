"""Tests hors ligne du pipeline (aucun réseau). Exécutables via :
    python3 tests/test_pipeline.py
    python3 -m pytest tools/opening-generator/tests
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import chess  # noqa: E402

from fen import normalize_fen  # noqa: E402
from selftest import run_selftest  # noqa: E402


def test_normalization_matches_swift_keys():
    # Doit être IDENTIQUE à OpeningFENKey.swift (mêmes assertions que les tests Swift).
    assert normalize_fen(chess.Board()) == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"

    b = chess.Board()
    b.push_san("e4")
    assert normalize_fen(b).endswith("b KQkq -")  # e.p. retirée (aucun preneur)

    b = chess.Board()
    for m in ["e4", "c5", "e5", "d5"]:
        b.push_san(m)
    assert normalize_fen(b).endswith("w KQkq d6")  # e.p. conservée (prise légale)

    a = chess.Board()
    for m in ["Nf3", "d5", "d4"]:
        a.push_san(m)
    c = chess.Board()
    for m in ["d4", "d5", "Nf3"]:
        c.push_san(m)
    assert a.fen() != c.fen() and normalize_fen(a) == normalize_fen(c)  # transposition fusionnée


def test_selftest_builds_valid_graph():
    stats = run_selftest()
    assert stats["positions"] > 5
    assert stats["edges"] > 0
    assert stats["max_depth_plies"] >= len(["e4", "e5", "Nf3", "Nc6", "Bc4"])


if __name__ == "__main__":
    test_normalization_matches_swift_keys()
    test_selftest_builds_valid_graph()
    print("tests OK")
