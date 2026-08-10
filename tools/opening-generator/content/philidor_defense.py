# -*- coding: utf-8 -*-
"""Défense Philidor (1.e4 e5 2.Cf3 d6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "philidor-defense",
    "name": "Philidor Defense",
    "side": "black",
    "level": "club",
    "eco": ["C41"],
    "summary": c(
        "Solide et compacte : les Noirs soutiennent e5 par …d6 et visent une structure ramassée (…Cbd7, …Fe7, …c6). Peu d'espace, mais très peu de faiblesses.",
        "Solid and compact: Black supports e5 with …d6 and aims for a tight setup (…Nbd7, …Be7, …c6). Little space, but very few weaknesses.",
    ),
    "lines": [
        {
            "chapter": {"id": "hanham", "title": c("Système Hanham — 3…Cf6", "Hanham System — 3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "d6",
                {"san": "d4", "comment": c("Les Blancs frappent le centre ; l'ordre des coups noir est essentiel.",
                                           "White strikes the centre; Black's move order matters.")},
                {"san": "Nf6", "eco": "Philidor Defense: Hanham Variation",
                 "comment": c("L'ordre moderne : on garde la tension avant de rentrer dans le set-up Hanham.",
                              "The modern order: keep the tension before entering the Hanham setup.")},
                "Nc3", "Nbd7", "Bc4", "Be7", "O-O", "O-O", "a4", "c6",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("3…exd4", "3…exd4")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "exd4",
                {"san": "Nxd4", "comment": c("Après l'échange, les Noirs jouent solide : …Cf6, …Fe7, roque, sans faiblesse.",
                                             "After the trade, Black plays solidly: …Nf6, …Be7, castle, no weaknesses.")},
                "Nf6", "Nc3", "Be7", "Be2", "O-O",
            ],
        },
    ],
}
