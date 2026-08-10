# -*- coding: utf-8 -*-
"""Attaque Nimzowitsch-Larsen (1.b3) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "nimzo-larsen",
    "name": "Nimzo-Larsen Attack",
    "side": "white",
    "level": "club",
    "eco": ["A01"],
    "summary": c(
        "Hypermoderne : le fou dame se fianchette en b2 et rayonne sur la grande diagonale vers e5 et g7. Ouverture de flanc originale, dépaysante pour l'adversaire.",
        "Hypermodern: the queen's bishop fianchettoes to b2, raking the long diagonal toward e5 and g7. An original flank opening that takes opponents out of book.",
    ),
    "lines": [
        {
            "chapter": {"id": "vs-e5", "title": c("Contre 1…e5", "Against 1…e5")},
            "moves": [
                {"san": "b3", "eco": "Nimzo-Larsen Attack",
                 "comment": c("Le fianchetto dame : le fou b2 vise déjà e5 et la grande diagonale.",
                              "The queenside fianchetto: the b2 bishop already eyes e5 and the long diagonal.")},
                "e5", "Bb2",
                {"san": "Nc6", "comment": c("Les Noirs défendent e5 ; les Blancs le pressent par Cf3 puis e3, Fb5.",
                                            "Black defends e5; White presses it with Nf3, then e3 and Bb5.")},
                "e3", "Nf6", "Bb5", "Bd6", "Nf3", "Qe7",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre 1…d5", "Against 1…d5")},
            "moves": [
                "b3", "d5", "Bb2", "Nf6", "e3", "e6", "Nf3", "Be7", "c4", "O-O",
            ],
        },
    ],
}
