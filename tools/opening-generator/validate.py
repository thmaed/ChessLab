"""Validation d'intégrité d'un cours — miroir de `OpeningCourseValidator.swift`.

Rejoue chaque coup avec python-chess et compare la clé normalisée obtenue à
`toFEN` : valide légalité du coup, cohérence du graphe ET normalisation. On
lance cette validation AVANT d'écrire un fichier ; côté app, le validateur
Swift refera le même contrôle sur le fichier embarqué.
"""
from __future__ import annotations

import chess

from fen import board_from_key, normalize_fen


def validate_course(course_dict: dict) -> list[str]:
    """Retourne la liste des problèmes (vide = graphe sain)."""
    issues: list[str] = []
    positions: dict = course_dict.get("positions", {})
    root = course_dict.get("rootFEN")

    if root not in positions:
        issues.append(f"[rootMissing] {root}")

    for key, node in positions.items():
        if node.get("fen") != key:
            issues.append(f"[keyMismatch] {key} != {node.get('fen')}")
        try:
            board = board_from_key(key)
        except Exception:
            issues.append(f"[invalidFEN] {key}")
            continue
        if normalize_fen(board) != key:
            issues.append(f"[nonNormalizedFEN] {key}")
        for edge in node.get("moves", []):
            _validate_edge(edge, key, positions, issues)

    for chapter in course_dict.get("chapters", []):
        for fen in chapter.get("positionFENs", []):
            if fen not in positions:
                issues.append(f"[chapterPositionMissing] {chapter.get('title')} -> {fen}")

    return issues


def _validate_edge(edge: dict, from_key: str, positions: dict, issues: list[str]) -> None:
    to_fen = edge.get("toFEN")
    if to_fen not in positions:
        issues.append(f"[orphanEdge] {from_key} --{edge.get('san')}--> {to_fen}")
    try:
        board = board_from_key(from_key)
        move = chess.Move.from_uci(edge["uci"])
        if move not in board.legal_moves:
            issues.append(f"[illegalMove] {edge.get('san')}/{edge.get('uci')} depuis {from_key}")
            return
        board.push(move)
        got = normalize_fen(board)
        if got != to_fen:
            issues.append(f"[edgeTargetMismatch] {from_key} --{edge['uci']}--> {got} != {to_fen}")
    except Exception as exc:  # noqa: BLE001
        issues.append(f"[illegalMove] {edge.get('uci')} depuis {from_key}: {exc}")
