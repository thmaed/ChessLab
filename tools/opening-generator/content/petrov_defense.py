# -*- coding: utf-8 -*-
"""Défense russe / Petrov (1.e4 e5 2.Cf3 Cf6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "petrov-defense",
    "name": "Petrov Defense",
    "side": "black",
    "level": "club",
    "eco": ["C42", "C43"],
    "summary": c(
        "La défense de la solidité : au lieu de défendre e5, les Noirs contre-attaquent e4 par symétrie. Réputation d'égalité tenace — la bête noire des joueurs d'attaque.",
        "The defence of solidity: instead of defending e5, Black counterattacks e4 by symmetry. A famously tough equaliser — the bane of attacking players.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3.Cxe5", "Main Line — 3.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6", "eco": "Petrov Defense",
                 "comment": c("La symétrie : les Noirs répondent à l'attaque de e5 en attaquant e4.",
                              "Symmetry: Black meets the attack on e5 by attacking e4.")},
                {"san": "Nxe5", "comment": c("Attention : reprendre tout de suite par …Cxe4 est une erreur (Dd5+/Cc6). D'abord …d6 !",
                                             "Careful: recapturing with …Nxe4 at once is a mistake (Qd5+/Nc6). First …d6!")},
                {"san": "d6", "comment": c("On chasse le cavalier AVANT de reprendre en e4 : l'ordre des coups est capital.",
                                           "Kick the knight BEFORE taking on e4: move order is crucial.")},
                "Nf3", "Nxe4", "d4", "d5", "Bd3", "Bd6",
            ],
        },
        {
            "chapter": {"id": "steinitz", "title": c("Attaque Steinitz — 3.d4", "Steinitz Attack — 3.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "d4", "eco": "Petrov Defense: Steinitz Variation",
                 "comment": c("Les Blancs ouvrent le centre plutôt que de prendre e5. …Cxe4 est correct.",
                              "White opens the centre instead of taking e5. …Nxe4 is correct.")},
                "Nxe4", "Bd3", "d5", "Nxe5", "Nd7",
            ],
        },
    ],
}
