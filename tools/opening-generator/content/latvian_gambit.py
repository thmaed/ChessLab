# -*- coding: utf-8 -*-
"""Gambit letton (1.e4 e5 2.Cf3 f5) — répertoire NOIR.

Une sicilienne inversée ultra-agressive et douteuse : contre-attaque immédiate.
Arbre : 3.Cxe5 (principale), 3.exf5, 3.Fc4 (le plus tranchant). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "latvian-gambit",
    "name": "Latvian Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C40"],
    "summary": c(
        "Le miroir du gambit du Roi, mais côté noir : …f5 dès le 2e coup, un jeu de tout ou rien. Objectivement risqué, mais un cauchemar pour qui n'est pas préparé.",
        "The mirror of the King's Gambit, but for Black: …f5 on move two, all-or-nothing play. Objectively risky, but a nightmare for the unprepared.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3.Cxe5", "Main Line — 3.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "f5", "eco": "Latvian Gambit",
                 "comment": c("Le gambit letton : contre-attaque immédiate au lieu de défendre e5.",
                              "The Latvian Gambit: an immediate counterattack instead of defending e5.")},
                "Nxe5", "Qf6", "d4", "d6", "Nc4", "fxe4", "Nc3", "Qg6", "Ne3", "Nf6", "Be2", "Be7",
            ],
        },
        {
            "chapter": {"id": "exf5", "title": c("3.exf5", "3.exf5")},
            "moves": [
                "e4", "e5", "Nf3", "f5",
                {"san": "exf5", "comment": c("Les Blancs prennent en f5 ; …e4 gagne du temps sur le cavalier et ouvre le jeu.",
                                             "White takes on f5; …e4 gains time on the knight and opens the game.")},
                "e4", "Ne5", "Nf6", "Be2", "d6", "Nc4", "Bxf5",
            ],
        },
        {
            "chapter": {"id": "bc4", "title": c("3.Fc4 — le plus tranchant", "3.Bc4 — the sharpest")},
            "moves": [
                "e4", "e5", "Nf3", "f5",
                {"san": "Bc4", "comment": c("La réfutation ambitieuse : le fou vise f7. Les Noirs plongent dans le chaos.",
                                            "The ambitious refutation: the bishop eyes f7. Black plunges into chaos.")},
                "fxe4", "Nxe5", "Qg5", "d4", "Qxg2", "Qh5+", "g6", "Bf7+", "Kd8", "Bxg6", "Qxh1+",
            ],
        },
    ],
}
