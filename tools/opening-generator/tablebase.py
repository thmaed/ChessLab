"""Client de la tablebase Lichess (Syzygy, ≤ 7 pièces) — l'oracle des finales.

Contrairement à l'Explorer, cette API est publique et SANS jeton. Elle rend,
pour une position, son verdict théorique exact (`category` : win/draw/loss du
point de vue du camp au trait) et, pour chaque coup légal, le verdict de la
position atteinte (du point de vue de l'ADVERSAIRE, donc `loss` = bon coup).

C'est ce qui rend l'audit des finales plus fort que celui des ouvertures :
pas une évaluation, un THÉORÈME. Un cours de finale qui passe l'audit
n'enseigne aucun coup qui lâche le gain, aucune défense qui perde la nulle —
prouvé, pas estimé.

Même discipline que `explorer.py` : cache disque (une position ne se demande
qu'une fois, les re-générations sont gratuites) et throttling poli — l'API est
un service gracieux, pas un droit.
"""
from __future__ import annotations

import hashlib
import json
import time
import urllib.parse
from pathlib import Path

import requests  # comme `explorer.py` : certificats fournis par certifi

BASE_URL = "https://tablebase.lichess.ovh/standard"
HERE = Path(__file__).resolve().parent
DEFAULT_CACHE = HERE / ".cache" / "tablebase"


class Tablebase:
    def __init__(self, cache_dir: Path = DEFAULT_CACHE, min_delay: float = 0.8):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.min_delay = min_delay
        self._last_request = 0.0
        self.requests = 0
        self.cache_hits = 0

    def probe(self, fen: str) -> dict:
        """Réponse brute de l'API pour `fen` (4 ou 6 champs acceptés)."""
        cached = self._cached(fen)
        if cached is not None:
            self.cache_hits += 1
            return cached

        wait = self.min_delay - (time.monotonic() - self._last_request)
        if wait > 0:
            time.sleep(wait)
        url = f"{BASE_URL}?fen={urllib.parse.quote(fen)}"
        headers = {"User-Agent": "ChessLab endgame audit"}
        # Trois essais : l'API rend parfois un 429 sous rafale malgré le
        # throttling ; on recule et on réessaie plutôt que d'invalider l'audit.
        for attempt in range(3):
            try:
                response = requests.get(url, headers=headers, timeout=30)
                response.raise_for_status()
                data = response.json()
                break
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(5.0 * (attempt + 1))
        self._last_request = time.monotonic()
        self.requests += 1
        self._store(fen, data)
        return data

    def category(self, fen: str) -> str:
        """Verdict de la position, POINT DE VUE DU CAMP AU TRAIT :
        win | draw | loss (les nuances cursed-win/blessed-loss — règle des
        50 coups — sont repliées sur win/loss : pour l'enseignement, un gain
        maudit reste la bonne direction)."""
        raw = self.probe(fen)["category"]
        if raw in ("cursed-win",):
            return "win"
        if raw in ("blessed-loss", "maybe-loss"):
            return "loss"
        if raw in ("maybe-win",):
            return "win"
        return raw

    def move_categories(self, fen: str) -> dict[str, str]:
        """`uci -> catégorie` de chaque coup légal, TOUJOURS convertie au
        point de vue du camp QUI JOUE le coup (l'API la donne du point de vue
        du camp au trait APRÈS le coup) : `win` = ce coup gagne."""
        flip = {"win": "loss", "loss": "win", "cursed-win": "loss",
                "blessed-loss": "win", "maybe-win": "loss", "maybe-loss": "win",
                "draw": "draw"}
        return {m["uci"]: flip[m["category"]] for m in self.probe(fen)["moves"]}

    # ── Cache disque ─────────────────────────────────────────────────────────

    def _path(self, fen: str) -> Path:
        digest = hashlib.sha256(fen.encode()).hexdigest()[:24]
        return self.cache_dir / f"{digest}.json"

    def _cached(self, fen: str) -> dict | None:
        path = self._path(fen)
        if path.exists():
            try:
                return json.loads(path.read_text())
            except Exception:
                return None
        return None

    def _store(self, fen: str, data: dict) -> None:
        self._path(fen).write_text(json.dumps(data, ensure_ascii=False))
