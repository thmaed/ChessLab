# -*- coding: utf-8 -*-
"""Défense Grünfeld (1.d4 Cf6 2.c4 g6 3.Cc3 d5) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "gruenfeld-defense",
    "name": "Grünfeld Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["D80", "D99"],
    "summary": c(
        "Hypermoderne et tranchante : les Noirs laissent les Blancs prendre un grand centre… pour le prendre à revers par …Fg7, …c5 et la pression sur d4.",
        "Hypermodern and sharp: Black lets White build a big centre… then attacks it from behind with …Bg7, …c5 and pressure on d4.",
    ),
    "lines": [
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3",
                {"san": "d5", "eco": "Grünfeld Defense",
                 "comment": c("Le coup Grünfeld : on frappe le centre au lieu de le fianchetter comme dans l'est-indienne.",
                              "The Grünfeld move: strike the centre instead of just fianchettoing as in the King's Indian.")},
                "cxd5", "Nxd5", "e4", "Nxc3", "bxc3",
                {"san": "Bg7", "comment": c("Le centre blanc est massif mais deviendra une cible : …c5 arrive.",
                                            "White's centre is huge but will become a target: …c5 is coming.")},
                "Bc4", "c5", "Ne2", "O-O",
            ],
        },
        {
            "chapter": {"id": "russian", "title": c("Système russe — 4.Cf3 & Db3", "Russian System — 4.Nf3 & Qb3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "d5", "Nf3", "Bg7",
                {"san": "Qb3", "eco": "Grünfeld Defense: Russian Variation",
                 "comment": c("Le Système russe : la dame frappe d5 et b7. Les Noirs prennent en c4 avec du contre-jeu.",
                              "The Russian System: the queen hits d5 and b7. Black takes on c4 with counterplay.")},
                "dxc4", "Qxc4", "O-O", "e4", "a6",
            ],
        },
    ],
}
