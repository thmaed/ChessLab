# -*- coding: utf-8 -*-
"""Ouverture Bird (1.f4) — répertoire BLANC.

Arbre : classique (hollandaise inversée, attaque Fe1-h4), gambit From 1…e5,
et l'installation solide contre …e6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "birds-opening",
    "name": "Bird's Opening",
    "side": "white",
    "level": "club",
    "eco": ["A02", "A03"],
    "summary": c(
        "1.f4 : une hollandaise avec les Blancs, un temps en plus. On contrôle e5, on fianchette ou on installe un Stonewall, puis on attaque le roque adverse.",
        "1.f4: a Dutch with White, a tempo up. Control e5, fianchetto or set up a Stonewall, then attack the enemy king.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Classique — hollandaise inversée", "Classical — reversed Dutch")},
            "moves": [
                {"san": "f4", "eco": "Bird's Opening",
                 "comment": c("On prend d'emblée le contrôle de e5 : c'est une hollandaise avec un temps de plus.",
                              "Grab control of e5 at once: it's a Dutch a tempo up.")},
                "d5", "Nf3", "Nf6", "e3", "g6", "Be2", "Bg7", "O-O", "O-O", "d3", "c5", "Nbd2", "Nc6", "Qe1", "b6", "Qh4", "Bb7",
            ],
        },
        {
            "chapter": {"id": "from", "title": c("Gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4",
                {"san": "e5", "comment": c("Le gambit From : un pion pour l'attaque. La bonne voie est de rendre le pion et de finir bien placé.",
                                           "From's Gambit: a pawn for attack. The right path is to return the pawn and end up well placed.")},
                "fxe5", "d6", "exd6", "Bxd6", "Nf3", "g5", "d4", "g4", "Ne5", "Bxe5", "dxe5", "Qxd1+", "Kxd1", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-e6", "title": c("Installation solide contre …e6", "Solid setup vs …e6")},
            "moves": [
                "f4", "d5", "Nf3", "Nf6", "e3", "e6", "b3", "Be7", "Bb2", "O-O", "Be2", "c5", "O-O", "Nc6",
            ],
        },
    ],
}
