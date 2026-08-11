# -*- coding: utf-8 -*-
"""Défense Nimzowitsch (1.e4 Cc6) — NOIR.

Provocante et hypermoderne : …Cc6 dès le 1er coup, on invite d4-d5 pour attaquer
le centre à revers. Arbre : 2.d4 d5 3.Cc3 et 2.d4 d5 3.e5. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "nimzowitsch-defense",
    "name": "Nimzowitsch Defense",
    "side": "black",
    "level": "club",
    "eco": ["B00"],
    "summary": c(
        "Une arme de surprise hypermoderne : 1…Cc6 invite les Blancs à avancer d4-d5, puis on harcèle ce centre. Peu de théorie connue de l'adversaire — son grand atout.",
        "A hypermodern surprise weapon: 1…Nc6 invites White to push d4-d5, then Black harasses that centre. Its big plus: opponents rarely know the theory.",
    ),
    "lines": [
        # 1) 2.d4 d5 3.Cc3
        {
            "chapter": {"id": "nc3", "title": c("2.d4 d5 3.Cc3", "2.d4 d5 3.Nc3")},
            "moves": [
                "e4",
                {"san": "Nc6", "eco": "Nimzowitsch Defense",
                 "comment": c("Le coup Nimzowitsch : le cavalier sort avant les pions, prêt à mordre le centre blanc.",
                              "The Nimzowitsch move: the knight comes out before the pawns, ready to bite the centre.")},
                "d4",
                {"san": "d5", "comment": c("On frappe e4 tout de suite ; la partie prend un tour concret.",
                                           "Strike e4 at once; the game turns concrete.")},
                "Nc3", "dxe4", "d5", "Ne5", "Qd4", "Ng6", "Nxe4", "Nf6",
            ],
        },
        # 2) 2.d4 d5 3.e5 (avance)
        {
            "chapter": {"id": "advance", "title": c("2.d4 d5 3.e5 (avance)", "2.d4 d5 3.e5 (advance)")},
            "moves": [
                "e4", "Nc6", "d4", "d5",
                {"san": "e5", "comment": c("L'avance ferme le centre ; le fou noir sort en f5 avant …e6, comme dans une Caro-Kann d'avance.",
                                           "The advance closes the centre; Black's bishop comes to f5 before …e6, as in an Advance Caro-Kann.")},
                "Bf5", "Ne2", "e6", "Ng3", "Bg6", "h4", "h5",
            ],
        },
    ],
}
