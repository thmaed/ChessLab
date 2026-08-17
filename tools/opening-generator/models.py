"""Modèles de sortie — miroir EXACT du modèle Codable Swift (OpeningCourse.swift).

Les noms de champs correspondent aux `CodingKeys` Swift. On n'émet PAS les
champs nuls/vides : le décodage défensif Swift traite une clé absente comme
`nil`, ce qui garde les fichiers compacts (chargement paresseux par ouverture).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

SCHEMA_VERSION = 1


def _compact(d: dict) -> dict:
    """Retire les valeurs None et les listes vides pour un JSON compact."""
    out = {}
    for k, v in d.items():
        if v is None:
            continue
        if isinstance(v, list) and len(v) == 0:
            continue
        out[k] = v
    return out


@dataclass
class MoveEdge:
    san: str
    uci: str
    toFEN: str
    role: str = "sideline"  # mainLine|sideline|trap|refutation|inaccuracy
    gamesMasters: Optional[int] = None
    popularityMasters: Optional[float] = None
    gamesClub: Optional[int] = None
    popularityClub: Optional[float] = None
    scoreWhite: Optional[float] = None
    scoreDraw: Optional[float] = None
    scoreBlack: Optional[float] = None
    eval: Optional[float] = None
    comment: Optional[str] = None
    commentStatus: Optional[str] = None  # draft|validated
    isCritical: bool = False

    def to_dict(self) -> dict:
        d = {
            "san": self.san,
            "uci": self.uci,
            "toFEN": self.toFEN,
            "role": self.role,
            "gamesMasters": self.gamesMasters,
            "popularityMasters": self.popularityMasters,
            "gamesClub": self.gamesClub,
            "popularityClub": self.popularityClub,
            "scoreWhite": self.scoreWhite,
            "scoreDraw": self.scoreDraw,
            "scoreBlack": self.scoreBlack,
            "eval": self.eval,
            "comment": self.comment,
            "commentStatus": self.commentStatus,
        }
        d = _compact(d)
        if self.isCritical:
            d["isCritical"] = True
        return d


@dataclass
class PositionNode:
    fen: str
    ecoName: Optional[str] = None
    plan: Optional[str] = None
    keySquares: Optional[list] = None
    moves: list = field(default_factory=list)  # list[MoveEdge]

    def to_dict(self) -> dict:
        d = _compact({
            "fen": self.fen,
            "ecoName": self.ecoName,
            "plan": self.plan,
            "keySquares": self.keySquares,
        })
        d["moves"] = [m.to_dict() for m in self.moves]
        return d


@dataclass
class OpeningChapter:
    id: str
    title: str
    summary: Optional[str] = None
    positionFENs: list = field(default_factory=list)

    def to_dict(self) -> dict:
        return _compact({
            "id": self.id,
            "title": self.title,
            "summary": self.summary,
            "positionFENs": self.positionFENs,
        })


@dataclass
class OpeningCourse:
    id: str
    name: str
    rootFEN: str
    side: str = "white"
    level: str = "club"
    eco: Optional[list] = None
    summary: Optional[str] = None
    # Finales : "endgame" (absent = ouverture, les 58 cours existants ne
    # changent pas d'un octet) et famille de regroupement
    # (pawns|rooks|queens|minor|mates|practical).
    kind: Optional[str] = None
    family: Optional[str] = None
    chapters: list = field(default_factory=list)   # list[OpeningChapter]
    positions: dict = field(default_factory=dict)  # key -> PositionNode

    def to_dict(self) -> dict:
        d = _compact({
            "schemaVersion": SCHEMA_VERSION,
            "id": self.id,
            "name": self.name,
            "eco": self.eco,
            "side": self.side,
            "level": self.level,
            "summary": self.summary,
            "kind": self.kind,
            "family": self.family,
            "rootFEN": self.rootFEN,
        })
        d["chapters"] = [c.to_dict() for c in self.chapters]
        d["positions"] = {k: n.to_dict() for k, n in self.positions.items()}
        return d


@dataclass
class CatalogEntry:
    id: str
    name: str
    side: str
    level: str
    eco: Optional[list]
    summary: Optional[str]
    positionCount: int
    maxDepth: int
    kind: Optional[str] = None
    family: Optional[str] = None

    def to_dict(self) -> dict:
        return _compact({
            "id": self.id,
            "name": self.name,
            "eco": self.eco,
            "side": self.side,
            "level": self.level,
            "summary": self.summary,
            "kind": self.kind,
            "family": self.family,
            "positionCount": self.positionCount,
            "maxDepth": self.maxDepth,
        })
