"""Catalogue des cours à générer : la liste CORE (24) pondérée sur ce qu'un
joueur de club rencontre vraiment, plus la catégorie transverse « Pièges et
gambits de club ».

Chaque entrée fixe la LIGNE D'ENTRÉE (coups SAN qui définissent l'ouverture) ;
le générateur la joue puis explore le graphe au-delà. `summary` reste None :
les textes pédagogiques sont rédigés à la main, jamais générés (règle stricte).
Les codes ECO sont indicatifs. `id` = identifiant de fichier (a-z0-9-).
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Opening:
    id: str
    name: str
    side: str            # white|black
    entry_moves: list    # SAN depuis la position initiale
    eco: list = field(default_factory=list)
    level: str = "club"
    profile: str = "core"
    summary: str = None


CORE: list[Opening] = [
    # Blancs — 1.e4
    Opening("italian-game", "Italian Game", "white", ["e4", "e5", "Nf3", "Nc6", "Bc4"], ["C50", "C55"]),
    Opening("ruy-lopez", "Ruy Lopez", "white", ["e4", "e5", "Nf3", "Nc6", "Bb5"], ["C60", "C99"]),
    Opening("scotch-game", "Scotch Game", "white", ["e4", "e5", "Nf3", "Nc6", "d4"], ["C44", "C45"]),
    Opening("vienna-game", "Vienna Game", "white", ["e4", "e5", "Nc3"], ["C25", "C29"]),
    Opening("kings-gambit", "King's Gambit", "white", ["e4", "e5", "f4"], ["C30", "C39"]),

    # Réponses noires à 1.e4
    Opening("sicilian-najdorf", "Sicilian Defense: Najdorf", "black",
            ["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6"], ["B90", "B99"], level="advanced"),
    Opening("sicilian-dragon", "Sicilian Defense: Dragon", "black",
            ["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6"], ["B70", "B79"], level="advanced"),
    # Anti-siciliennes : entrée courte 1.e4 c5, le branchement fait surgir
    # Alapin/Rossolimo/Grand Prix/Smith-Morra/Fermée (priorité haute du brief).
    Opening("anti-sicilians", "Anti-Sicilians", "black", ["e4", "c5"], ["B20", "B29"]),
    Opening("french-defense", "French Defense", "black", ["e4", "e6"], ["C00", "C19"]),
    Opening("caro-kann", "Caro-Kann Defense", "black", ["e4", "c6"], ["B10", "B19"]),
    Opening("scandinavian", "Scandinavian Defense", "black", ["e4", "d5"], ["B01"]),
    Opening("pirc-defense", "Pirc Defense", "black", ["e4", "d6"], ["B07", "B09"]),
    Opening("alekhine-defense", "Alekhine Defense", "black", ["e4", "Nf6"], ["B02", "B05"]),
    Opening("petrov-defense", "Petrov Defense", "black", ["e4", "e5", "Nf3", "Nf6"], ["C42", "C43"]),

    # Blancs — 1.d4 et systèmes
    Opening("london-system", "London System", "white", ["d4", "d5", "Bf4"], ["D02", "A48"]),
    Opening("queens-gambit-declined", "Queen's Gambit Declined", "white", ["d4", "d5", "c4", "e6"], ["D30", "D69"]),
    Opening("queens-gambit-accepted", "Queen's Gambit Accepted", "white", ["d4", "d5", "c4", "dxc4"], ["D20", "D29"]),
    Opening("slav-defense", "Slav Defense", "white", ["d4", "d5", "c4", "c6"], ["D10", "D19"]),
    Opening("catalan-opening", "Catalan Opening", "white", ["d4", "Nf6", "c4", "e6", "g3"], ["E00", "E09"]),
    Opening("english-opening", "English Opening", "white", ["c4"], ["A10", "A39"]),

    # Réponses noires à 1.d4
    Opening("kings-indian", "King's Indian Defense", "black", ["d4", "Nf6", "c4", "g6", "Nc3", "Bg7"], ["E60", "E99"], level="advanced"),
    Opening("nimzo-indian", "Nimzo-Indian Defense", "black", ["d4", "Nf6", "c4", "e6"], ["E20", "E59"], level="advanced"),
    Opening("gruenfeld-defense", "Grünfeld Defense", "black", ["d4", "Nf6", "c4", "g6", "Nc3", "d5"], ["D80", "D99"], level="advanced"),
    Opening("dutch-defense", "Dutch Defense", "black", ["d4", "f5"], ["A80", "A99"]),
]

# Catégorie transverse « Pièges et gambits de club » : très rentable en
# engagement, faible coût de production.
TRAPS: list[Opening] = [
    Opening("stafford-gambit", "Stafford Gambit", "black", ["e4", "e5", "Nf3", "Nf6", "Nxe5", "Nc6"], ["C42"], profile="trap"),
    Opening("englund-gambit", "Englund Gambit", "black", ["d4", "e5"], ["A40"], profile="trap"),
    Opening("blackmar-diemer", "Blackmar-Diemer Gambit", "white", ["d4", "d5", "e4"], ["D00"], profile="trap"),
    Opening("elephant-gambit", "Elephant Gambit", "black", ["e4", "e5", "Nf3", "d5"], ["C40"], profile="trap"),
    Opening("latvian-gambit", "Latvian Gambit", "black", ["e4", "e5", "Nf3", "f5"], ["C40"], profile="trap"),
    Opening("fried-liver", "Fried Liver Attack", "white", ["e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5"], ["C57"], profile="trap"),
]

ALL: list[Opening] = CORE + TRAPS


def by_id(identifier: str) -> Opening | None:
    return next((o for o in ALL if o.id == identifier), None)
