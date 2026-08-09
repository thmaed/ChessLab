"""Évaluation moteur en batch (optionnelle) — annote les coups et repère les
pièges (chute d'évaluation brutale après un coup naturel).

Utilise n'importe quel binaire Stockfish via UCI (python-chess). Désactivé si
aucun chemin n'est fourni (`NullEvaluator`) — le pipeline reste pleinement
fonctionnel sans moteur, les `eval` restent simplement absentes.

Convention : évaluation en CENTIPIONS du point de vue des BLANCS (comme le
champ `eval` du modèle). Un mat est ramené à ±100000 borné.
"""
from __future__ import annotations

from typing import Optional

import chess

try:
    import chess.engine
except Exception:  # noqa: BLE001
    chess.engine = None  # type: ignore


class NullEvaluator:
    def eval_cp(self, board: chess.Board) -> Optional[float]:
        return None

    def close(self) -> None:
        pass


class StockfishEvaluator:
    def __init__(self, path: str, depth: int = 16, threads: int = 1, hash_mb: int = 128):
        if chess.engine is None:
            raise RuntimeError("python-chess engine indisponible")
        self.engine = chess.engine.SimpleEngine.popen_uci(path)
        try:
            self.engine.configure({"Threads": threads, "Hash": hash_mb})
        except Exception:  # noqa: BLE001 - options best effort
            pass
        self.limit = chess.engine.Limit(depth=depth)

    def eval_cp(self, board: chess.Board) -> Optional[float]:
        try:
            info = self.engine.analyse(board, self.limit)
        except Exception:  # noqa: BLE001
            return None
        score = info["score"].white()
        if score.is_mate():
            mate = score.mate()
            return 100000.0 if (mate or 0) > 0 else -100000.0
        return float(score.score())

    def close(self) -> None:
        try:
            self.engine.quit()
        except Exception:  # noqa: BLE001
            pass
