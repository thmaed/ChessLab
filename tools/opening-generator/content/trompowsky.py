# -*- coding: utf-8 -*-
"""Attaque Trompowsky (1.d4 Cf6 2.Fg5) — répertoire BLANC.

Arbre : 2…Ce4, 2…e6, 2…c5, 2…d5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "trompowsky",
    "name": "Trompowsky Attack",
    "side": "white",
    "level": "club",
    "eco": ["A45"],
    "summary": c(
        "Dès 2.Fg5, on sort de la théorie lourde : le fou cloue f6 et impose un jeu original. Peu de lignes à mémoriser, beaucoup de plans concrets.",
        "With 2.Bg5 you dodge heavy theory: the bishop pins f6 and imposes original play. Little to memorise, plenty of concrete plans.",
    ),
    "lines": [
        {
            "chapter": {"id": "ne4", "title": c("2…Ce4", "2…Ne4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bg5", "eco": "Trompowsky Attack",
                 "comment": c("On cloue f6 avant même de jouer un pion central : place au jeu concret.",
                              "Pin f6 before even playing a central pawn: concrete play from move two.")},
                {"san": "Ne4", "comment": c("On chasse le fou tout de suite ; il ira en f4 ou h4.",
                                            "Kick the bishop at once; it goes to f4 or h4.")},
                "Bf4", "d5", "e3", "c5", "Bd3", "Nc6", "Nf3", "Qb6", "Qc1", "e6", "O-O", "Be7",
            ],
        },
        {
            "chapter": {"id": "e6", "title": c("2…e6", "2…e6")},
            "moves": [
                "d4", "Nf6", "Bg5", "e6",
                {"san": "e4", "comment": c("La ligne agressive : les Blancs prennent le centre et acceptent les pions doublés après …h6.",
                                           "The aggressive line: White grabs the centre and accepts doubled pawns after …h6.")},
                "h6", "Bxf6", "Qxf6", "Nc3", "d6", "Qd2", "g6", "O-O-O", "Bg7", "f4", "Nd7",
            ],
        },
        {
            "chapter": {"id": "c5", "title": c("2…c5", "2…c5")},
            "moves": [
                "d4", "Nf6", "Bg5", "c5",
                {"san": "Bxf6", "comment": c("On double les pions noirs et on joue la structure ; d5 fixe l'avantage d'espace.",
                                             "Double Black's pawns and play the structure; d5 secures a space edge.")},
                "gxf6", "d5", "Qb6", "Qc1", "f5", "e3", "Bg7", "c3", "d6", "Ne2", "Nd7",
            ],
        },
        {
            "chapter": {"id": "d5", "title": c("2…d5", "2…d5")},
            "moves": [
                "d4", "Nf6", "Bg5", "d5",
                {"san": "Bxf6", "comment": c("Encore l'échange : la paire de fous adverse compensée par une structure et un jeu clairs.",
                                             "The exchange again: Black's bishop pair offset by a clear structure and simple play.")},
                "exf6", "e3", "Bd6", "c4", "dxc4", "Bxc4", "O-O", "Nc3", "Nc6", "Nge2", "Re8",
            ],
        },
    ],
}
