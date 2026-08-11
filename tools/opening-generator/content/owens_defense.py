# -*- coding: utf-8 -*-
"""Défense Owen (1.e4 b6) — NOIR.

Hypermoderne et rare : on fianchette en b7 pour contester e4 de loin et sortir
de la théorie dès le 1er coup. Arbre : 2.d4 Fb7 3.Fd3 e6, et 3.Cc3. Vérifié.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "owens-defense",
    "name": "Owen's Defense",
    "side": "black",
    "level": "club",
    "eco": ["B00"],
    "summary": c(
        "Une arme de surprise hypermoderne : 1…b6 et le fou en b7 pressent e4 sur la grande diagonale. On sort de la théorie d'entrée, quitte à céder un peu d'espace.",
        "A hypermodern surprise weapon: 1…b6 and the b7 bishop press e4 along the long diagonal. Out of theory from move one, at the cost of a little space.",
    ),
    "lines": [
        # 1) 2.d4 Fb7 3.Fd3 e6
        {
            "chapter": {"id": "main", "title": c("2.d4 Fb7 3.Fd3 e6", "2.d4 Bb7 3.Bd3 e6")},
            "moves": [
                "e4",
                {"san": "b6", "eco": "Owen Defense",
                 "comment": c("Le coup Owen : on prépare …Fb7 pour viser e4 et g2, à la manière d'une Ouest-indienne côté roi.",
                              "The Owen move: preparing …Bb7 to target e4 and g2, like a kingside Queen's Indian.")},
                "d4", "Bb7", "Bd3", "e6", "Nf3", "c5", "c3", "Nf6", "Qe2", "Be7", "O-O", "O-O",
            ],
        },
        # 2) 2.d4 Fb7 3.Cc3
        {
            "chapter": {"id": "nc3", "title": c("2.d4 Fb7 3.Cc3", "2.d4 Bb7 3.Nc3")},
            "moves": [
                "e4", "b6", "d4", "Bb7", "Nc3", "e6", "Nge2", "Bb4", "a3", "Bxc3", "Nxc3", "Nf6", "Bd3", "d5",
            ],
        },
    ],
}
