"""Noms et codes ECO — dataset public `lichess-org/chess-openings` (a.tsv..e.tsv).

Domaine public. Sert UNIQUEMENT à nommer les positions atteintes (champ
`ecoName`). On construit une table {FEN normalisée -> (eco, name)} en rejouant
le mouvement de chaque entrée du dataset jusqu'à sa position finale.

Les fichiers sont téléchargés une fois puis mis en cache ; on peut aussi
pointer un dossier local (`--chess-openings-dir`) pour un fonctionnement
entièrement hors ligne / reproductible.
"""
from __future__ import annotations

from pathlib import Path
from typing import Optional

import chess
import requests

from fen import normalize_fen

RAW_BASE = "https://raw.githubusercontent.com/lichess-org/chess-openings/master"
VOLUMES = ["a", "b", "c", "d", "e"]


def _sans_from_pgn(pgn: str) -> list[str]:
    """Extrait la séquence SAN d'un mouvement PGN (jette les jetons de
    numérotation, seuls à contenir un point) — même logique que Swift."""
    return [tok for tok in pgn.split() if tok and "." not in tok]


class EcoNames:
    def __init__(self, by_fen: dict[str, tuple[str, str]]):
        self._by_fen = by_fen

    def lookup(self, key: str) -> Optional[str]:
        entry = self._by_fen.get(key)
        return entry[1] if entry else None

    def eco_code(self, key: str) -> Optional[str]:
        entry = self._by_fen.get(key)
        return entry[0] if entry else None

    @classmethod
    def load(cls, cache_dir: Path, local_dir: Optional[Path] = None) -> "EcoNames":
        by_fen: dict[str, tuple[str, str]] = {}
        for vol in VOLUMES:
            text = cls._read_volume(vol, cache_dir, local_dir)
            if not text:
                continue
            for line in text.splitlines():
                if not line or line.startswith("eco\t"):
                    continue
                parts = line.split("\t")
                if len(parts) < 3:
                    continue
                eco, name, pgn = parts[0], parts[1], parts[2]
                board = chess.Board()
                try:
                    for san in _sans_from_pgn(pgn):
                        board.push_san(san)
                except Exception:  # noqa: BLE001 - ligne illisible ignorée
                    continue
                by_fen[normalize_fen(board)] = (eco, name)
        return cls(by_fen)

    @staticmethod
    def _read_volume(vol: str, cache_dir: Path, local_dir: Optional[Path]) -> Optional[str]:
        if local_dir:
            p = Path(local_dir) / f"{vol}.tsv"
            if p.exists():
                return p.read_text()
        cache_dir = Path(cache_dir)
        cache_dir.mkdir(parents=True, exist_ok=True)
        cached = cache_dir / f"{vol}.tsv"
        if cached.exists():
            return cached.read_text()
        try:
            resp = requests.get(f"{RAW_BASE}/{vol}.tsv", timeout=30)
            if resp.status_code == 200:
                cached.write_text(resp.text)
                return resp.text
        except requests.RequestException:
            return None
        return None
