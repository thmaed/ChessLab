# -*- coding: utf-8 -*-
"""Système Colle (1.d4 d5 2.Cf3 Cf6 3.e3) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "colle-system",
    "name": "Colle System",
    "side": "white",
    "level": "club",
    "eco": ["D04", "D05"],
    "summary": c(
        "Un système d'installation facile : e3, Fd3, c3, Cbd2, puis la poussée e4 comme rupture libératrice. Peu de théorie, une attaque à l'aile roi souvent au rendez-vous.",
        "An easy setup system: e3, Bd3, c3, Nbd2, then the freeing e4 break. Little theory, and a kingside attack often on the cards.",
    ),
    "lines": [
        {
            "chapter": {"id": "colle", "title": c("Colle classique — c3 & e4", "Classical Colle — c3 & e4")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6",
                {"san": "Bd3", "eco": "Colle System",
                 "comment": c("La formation Colle : on vise la rupture e3-e4 après c3 et Cbd2.",
                              "The Colle formation: aiming for the e3-e4 break after c3 and Nbd2.")},
                "c5", "c3", "Nc6", "Nbd2", "Bd6", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "zukertort", "title": c("Colle-Zukertort — b3", "Colle-Zukertort — b3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5",
                {"san": "b3", "eco": "Colle-Zukertort System",
                 "comment": c("La version Zukertort : le fou dame va en b2 et vise e5 sur la grande diagonale.",
                              "The Zukertort version: the queen's bishop goes to b2 and eyes e5 on the long diagonal.")},
                "Nc6", "Bb2", "Bd6", "O-O", "O-O",
            ],
        },
    ],
}
