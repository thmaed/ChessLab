# -*- coding: utf-8 -*-
"""Slave et semi-slave (1.d4 d5 2.c4 c6) — répertoire BLANC (jouer CONTRE)."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "slav-defense",
    "name": "Slav Defense",
    "side": "white",
    "level": "advanced",
    "eco": ["D10", "D19"],
    "summary": c(
        "La Slave (…c6) garde le fou c8 libre — le grand atout sur le gambit refusé. Ce répertoire montre comment les Blancs y font face, Slave pure comme semi-slave.",
        "The Slav (…c6) keeps the c8 bishop free — its big edge over the QGD. This repertoire shows how White handles it, both pure Slav and Semi-Slav.",
    ),
    "lines": [
        {
            "chapter": {"id": "pure-slav", "title": c("Slave pure — 4…dxc4", "Pure Slav — 4…dxc4")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "c6", "eco": "Slav Defense",
                 "comment": c("La Slave : les Noirs soutiennent d5 tout en gardant …Ff5/…Fg4 possible.",
                              "The Slav: Black supports d5 while keeping …Bf5/…Bg4 available.")},
                "Nf3", "Nf6", "Nc3", "dxc4",
                {"san": "a4", "comment": c("Le coup clé : on empêche …b5 qui tiendrait le pion c4.",
                                           "The key move: stopping …b5, which would hold the c4 pawn.")},
                "Bf5", "e3", "e6", "Bxc4", "Bb4",
            ],
        },
        {
            "chapter": {"id": "semi-slav", "title": c("Semi-slave — …e6", "Semi-Slav — …e6")},
            "moves": [
                "d4", "d5", "c4", "c6", "Nf3", "Nf6", "Nc3",
                {"san": "e6", "eco": "Semi-Slav Defense",
                 "comment": c("La semi-slave : plus combative, elle prépare …dxc4 et …b5 avec du contre-jeu.",
                              "The Semi-Slav: more combative, preparing …dxc4 and …b5 with counterplay.")},
                "e3", "Nbd7", "Bd3", "dxc4", "Bxc4", "b5",
            ],
        },
    ],
}
