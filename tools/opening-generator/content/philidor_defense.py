# -*- coding: utf-8 -*-
"""Défense Philidor (1.e4 e5 2.Cf3 d6) — répertoire NOIR.

Arbre : système Hanham (…Cbd7/…Fe7), variante de l'échange (…exd4), et
l'hybride Philidor-Pirc (…exd4 …g6). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "philidor-defense",
    "name": "Philidor Defense",
    "side": "black",
    "level": "club",
    "eco": ["C41"],
    "summary": c(
        "Solide et discrète : les Noirs soutiennent e5 par …d6 au lieu de …Cc6. Peu d'espace, mais une position sans faiblesse et des plans clairs (…c6, …Fe7, …0-0).",
        "Solid and quiet: Black supports e5 with …d6 instead of …Nc6. Little space, but a weakness-free position with clear plans (…c6, …Be7, …0-0).",
    ),
    "lines": [
        {
            "chapter": {"id": "hanham", "title": c("Système Hanham", "Hanham System")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6", "Nc3", "Nbd7", "Bc4", "Be7", "O-O", "O-O",
                {"san": "a4", "comment": c("Les Blancs freinent …b5 ; les Noirs manœuvrent tranquillement derrière leur petit centre.",
                                           "White restrains …b5; Black manoeuvres calmly behind the small centre.")},
                "c6", "h3", "Qc7", "Qe2", "b6", "Rd1", "Bb7",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4",
                {"san": "exd4", "comment": c("On échange au centre pour un jeu simple et solide, sans souci d'espace.",
                                             "Trade in the centre for simple, solid play, free of space worries.")},
                "Nxd4", "Nf6", "Nc3", "Be7", "Be2", "O-O", "O-O", "Re8", "h3", "Bf8", "Bf4", "Nbd7", "Qd2", "a6",
            ],
        },
        {
            "chapter": {"id": "pirc-hybrid", "title": c("Hybride Philidor-Pirc — …g6", "Philidor-Pirc hybrid — …g6")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "exd4", "Nxd4", "g6", "Nc3", "Bg7", "Be3", "Nf6", "f3", "O-O", "Qd2", "Re8",
            ],
        },
    ],
}
