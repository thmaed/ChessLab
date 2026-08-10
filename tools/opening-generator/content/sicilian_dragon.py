# -*- coding: utf-8 -*-
"""Sicilienne dragon et dragon accélérée (1.e4 c5 … …g6) — NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-dragon",
    "name": "Sicilian Defense: Dragon",
    "side": "black",
    "level": "advanced",
    "eco": ["B70", "B79"],
    "summary": c(
        "Le fou en g6-g7 crache le feu sur la grande diagonale. Attaques opposées, courses de pions : la sicilienne la plus explosive.",
        "The g7 bishop breathes fire down the long diagonal. Opposite-side castling and pawn races: the most explosive Sicilian.",
    ),
    "lines": [
        {
            "chapter": {"id": "yugoslav", "title": c("Attaque yougoslave", "Yugoslav Attack")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "g6", "eco": "Sicilian Defense: Dragon Variation",
                 "comment": c("Le Dragon : le fou ira en g7, âme de toute la variante.",
                              "The Dragon: the bishop heads for g7, the soul of the whole line.")},
                {"san": "Be3", "comment": c("Les Blancs préparent l'Attaque yougoslave : Dd2, 0-0-0, h4-h5.",
                                            "White prepares the Yugoslav: Qd2, 0-0-0, h4-h5.")},
                "Bg7", "f3", "O-O", "Qd2", "Nc6",
                {"san": "Bc4", "comment": c("Course aux rois : les Blancs attaquent à droite, les Noirs par la colonne c.",
                                            "A race of kings: White attacks on the right, Black down the c-file.")},
            ],
        },
        {
            "chapter": {"id": "accelerated", "title": c("Dragon accélérée", "Accelerated Dragon")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4",
                {"san": "g6", "eco": "Sicilian Defense: Accelerated Dragon",
                 "comment": c("La version accélérée : …g6 sans …d6, pour gagner un temps et viser …d5 d'un coup.",
                              "The accelerated version: …g6 without …d6, saving a tempo and eyeing …d5 in one go.")},
                {"san": "Nc3", "comment": c("Sans le bind Maroczy, les Noirs obtiennent un jeu confortable.",
                                            "Without the Maróczy bind, Black gets comfortable play.")},
                "Bg7", "Be3", "Nf6", "Bc4", "O-O",
            ],
        },
        {
            "chapter": {"id": "maroczy", "title": c("Étau Maroczy — 5.c4", "Maróczy Bind — 5.c4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "g6",
                {"san": "c4", "eco": "Sicilian Defense: Accelerated Dragon, Maróczy Bind",
                 "comment": c("L'étau Maroczy : les pions c4+e4 briment …d5. Les Noirs jouent patient et cherchent …f5 ou …b5.",
                              "The Maróczy bind: the c4+e4 pawns restrain …d5. Black plays patiently, aiming for …f5 or …b5.")},
                "Bg7", "Be3", "Nf6", "Nc3", "d6",
            ],
        },
    ],
}
