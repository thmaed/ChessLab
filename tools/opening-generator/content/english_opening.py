# -*- coding: utf-8 -*-
"""Anglaise (1.c4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "english-opening",
    "name": "English Opening",
    "side": "white",
    "level": "club",
    "eco": ["A10", "A39"],
    "summary": c(
        "Une ouverture de flanc hypermoderne : on contrôle d5 à distance et on garde une flexibilité totale. Souvent une sicilienne avec un temps de plus.",
        "A hypermodern flank opening: control d5 from afar and keep total flexibility. Often a Sicilian with an extra tempo.",
    ),
    "lines": [
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                {"san": "c4", "eco": "English Opening",
                 "comment": c("On revendique d5 sans engager les pions centraux : jeu souple.",
                              "Claiming d5 without committing the central pawns: flexible play.")},
                {"san": "e5", "comment": c("Les Noirs prennent le centre : c'est une sicilienne à camps inversés, un temps en plus pour les Blancs.",
                                           "Black grabs the centre: it's a Sicilian with colours reversed, White a tempo up.")},
                "Nc3", "Nf6", "Nf3", "Nc6", "g3", "d5", "cxd5", "Nxd5", "Bg2",
            ],
        },
        {
            "chapter": {"id": "symmetrical", "title": c("Variante symétrique — 1…c5", "Symmetrical — 1…c5")},
            "moves": [
                "c4",
                {"san": "c5", "eco": "English Opening: Symmetrical Variation",
                 "comment": c("La symétrique : chacun campe sur ses positions. Les Blancs cherchent à rompre la symétrie au bon moment.",
                              "The Symmetrical: both sides mirror. White looks to break the symmetry at the right moment.")},
                "Nc3", "Nc6", "g3", "g6", "Bg2", "Bg7", "Nf3", "Nf6",
            ],
        },
    ],
}
