# -*- coding: utf-8 -*-
"""Attaque Trompowsky (1.d4 Cf6 2.Fg5) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "trompowsky",
    "name": "Trompowsky Attack",
    "side": "white",
    "level": "club",
    "eco": ["A45"],
    "summary": c(
        "On sort le fou dès le 2e coup pour esquiver toute la théorie indienne : le fou menace de doubler les pions f noirs. Peu de mémorisation, des plans clairs.",
        "Develop the bishop on move two to dodge all the Indian theory: it threatens to double Black's f-pawns. Little memorisation, clear plans.",
    ),
    "lines": [
        {
            "chapter": {"id": "ne4", "title": c("2…Ce4", "2…Ne4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bg5", "eco": "Trompowsky Attack",
                 "comment": c("Le Trompowsky : le fou cloue f6 et menace de doubler les pions.",
                              "The Trompowsky: the bishop pins f6 and threatens to double the pawns.")},
                {"san": "Ne4", "comment": c("La réponse la plus fréquente : le cavalier attaque le fou.",
                                            "The most common reply: the knight hits the bishop.")},
                "Bf4", "d5", "e3", "c5", "Bd3", "Nc6",
            ],
        },
        {
            "chapter": {"id": "e6", "title": c("2…e6 3.e4", "2…e6 3.e4")},
            "moves": [
                "d4", "Nf6", "Bg5", "e6",
                {"san": "e4", "comment": c("On saisit tout le centre pendant que le fou tient f6.",
                                           "Grab the whole centre while the bishop holds f6.")},
                "h6", "Bxf6", "Qxf6", "Nc3", "d6",
            ],
        },
        {
            "chapter": {"id": "c5", "title": c("2…c5 3.Fxf6", "2…c5 3.Bxf6")},
            "moves": [
                "d4", "Nf6", "Bg5", "c5",
                {"san": "Bxf6", "comment": c("On abandonne la paire de fous pour les pions doublés noirs et un jeu de structure.",
                                             "Give up the bishop pair for Black's doubled pawns and a structural game.")},
                "gxf6", "d5", "Qb6", "Qc1", "f5",
            ],
        },
    ],
}
