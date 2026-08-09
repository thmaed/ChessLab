"""Client de l'API publique Lichess Opening Explorer, robuste au rate limiting.

Deux bases (double pondération du brief) :
- masters  → https://explorer.lichess.ovh/masters  (théoriquement correct)
- lichess  → https://explorer.lichess.ovh/lichess  (parties en ligne, filtrées
             par tranche Elo — ce que le joueur affronte VRAIMENT en club)

Robustesse (l'API a connu indisponibilités et 429 agressifs) :
- Cache DISQUE de chaque réponse, indexé par (endpoint, FEN normalisée, params).
  Le cache EST le mécanisme de reprise : re-lancer ne refait aucune requête déjà
  faite (transpositions incluses, puisque la clé est la FEN normalisée).
- Backoff exponentiel sur HTTP 429, délai minimal configurable entre requêtes.
- Journal des positions en échec (rejouable).

`MockExplorer` fournit des réponses en dur pour les tests hors ligne.
"""
from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path
from typing import Optional

import requests

from fen import normalize_fen
import chess

MASTERS_URL = "https://explorer.lichess.ovh/masters"
LICHESS_URL = "https://explorer.lichess.ovh/lichess"


class ExplorerError(Exception):
    pass


class LichessExplorer:
    def __init__(
        self,
        cache_dir: Path,
        speeds: str = "blitz,rapid,classical",
        ratings: str = "1400,1600,1800",
        min_delay: float = 1.0,
        max_retries: int = 6,
        moves: int = 12,
        dry_run: bool = False,
    ):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.speeds = speeds
        self.ratings = ratings
        self.min_delay = min_delay
        self.max_retries = max_retries
        self.moves = moves
        self.dry_run = dry_run
        self._last_request_at = 0.0
        self.failed: list[dict] = []
        self.request_count = 0
        self.cache_hits = 0

    # -- API publique ------------------------------------------------------

    def masters(self, board: chess.Board) -> Optional[dict]:
        params = {"fen": board.fen(), "moves": self.moves, "topGames": 0}
        return self._get(MASTERS_URL, board, params, tag="masters")

    def lichess(self, board: chess.Board) -> Optional[dict]:
        params = {
            "fen": board.fen(),
            "moves": self.moves,
            "topGames": 0,
            "recentGames": 0,
            "speeds": self.speeds,
            "ratings": self.ratings,
        }
        return self._get(LICHESS_URL, board, params, tag="lichess")

    # -- Interne -----------------------------------------------------------

    def _cache_path(self, tag: str, board: chess.Board, params: dict) -> Path:
        key = normalize_fen(board)
        sig = f"{tag}|{key}|{self.speeds}|{self.ratings}|{self.moves}"
        digest = hashlib.sha1(sig.encode("utf-8")).hexdigest()[:20]
        return self.cache_dir / f"{tag}_{digest}.json"

    def _get(self, url: str, board: chess.Board, params: dict, tag: str) -> Optional[dict]:
        path = self._cache_path(tag, board, params)
        if path.exists():
            self.cache_hits += 1
            return json.loads(path.read_text())

        if self.dry_run:
            # En dry-run on ne fait AUCUNE requête réseau : seul le cache existant
            # est utilisé, le reste est traité comme « donnée absente ».
            return None

        data = self._request_with_backoff(url, params, board)
        if data is not None:
            path.write_text(json.dumps(data))
        return data

    def _request_with_backoff(self, url: str, params: dict, board: chess.Board) -> Optional[dict]:
        for attempt in range(self.max_retries):
            self._respect_min_delay()
            try:
                resp = requests.get(url, params=params, timeout=30)
            except requests.RequestException as exc:
                self._sleep_backoff(attempt, reason=str(exc))
                continue

            self.request_count += 1
            if resp.status_code == 200:
                try:
                    return resp.json()
                except ValueError:
                    # 200 mais corps non-JSON (page d'erreur d'un proxy, HTML…) :
                    # on retente plutôt que de crasher tout le lot.
                    self._sleep_backoff(attempt, reason="réponse non-JSON")
                    continue
            if resp.status_code == 429:
                # Respecte Retry-After s'il est fourni, sinon backoff exponentiel.
                retry_after = resp.headers.get("Retry-After")
                delay = float(retry_after) if retry_after else (2 ** attempt) * self.min_delay
                time.sleep(min(delay, 120))
                continue
            if resp.status_code in (500, 502, 503, 504):
                self._sleep_backoff(attempt, reason=f"HTTP {resp.status_code}")
                continue
            # Autre erreur : on abandonne cette position.
            break

        self.failed.append({"fen": normalize_fen(board), "url": url})
        return None

    def _respect_min_delay(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        if elapsed < self.min_delay:
            time.sleep(self.min_delay - elapsed)
        self._last_request_at = time.monotonic()

    def _sleep_backoff(self, attempt: int, reason: str) -> None:
        time.sleep(min((2 ** attempt) * self.min_delay, 60))

    def dump_failures(self, path: Path) -> None:
        if self.failed:
            Path(path).write_text(json.dumps(self.failed, indent=2))


class MockExplorer:
    """Réponses déterministes pour les tests hors ligne, indexées par FEN
    normalisée. Format identique à l'API réelle (white/draws/black + moves)."""

    def __init__(self, masters_by_fen: dict, lichess_by_fen: dict):
        self._masters = masters_by_fen
        self._lichess = lichess_by_fen
        self.failed: list = []
        self.request_count = 0
        self.cache_hits = 0

    def masters(self, board: chess.Board) -> Optional[dict]:
        return self._masters.get(normalize_fen(board))

    def lichess(self, board: chess.Board) -> Optional[dict]:
        return self._lichess.get(normalize_fen(board))

    def dump_failures(self, path):  # noqa: D401 - interface commune
        pass
