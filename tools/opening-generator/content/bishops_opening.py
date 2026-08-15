# -*- coding: utf-8 -*-
"""Partie du Fou (1.e4 e5 2.Fc4) — répertoire BLANC.

Arbre : 2…Cf6 (avec d3), 2…Fc5 (c3+d4), et le gambit Urusov 2…Cf6 3.d4.
Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "bishops-opening",
    "name": "Bishop's Opening",
    "side": "white",
    "level": "club",
    "eco": ["C23", "C24"],
    "summary": c(
        "Le fou file en c4 dès le 2e coup, visant f7 sans engager le cavalier roi. Souvent une italienne détournée, avec la possibilité d'un centre par d4 ou d'un jeu tranquille par d3.",
        "The bishop hits c4 on move two, eyeing f7 without committing the king's knight. Often a rerouted Italian, with the option of a d4 centre or quiet play with d3.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("2…Cf6 — 3.d3", "2…Nf6 — 3.d3")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4", "eco": "Bishop's Opening",
                 "comment": c("Le fou italien sans …Cf3 : on garde le choix entre d3 tranquille et d4 tranchant.",
                              "The Italian bishop without …Nf3: keeping the choice between quiet d3 and sharp d4.")},
                "Nf6", "d3", "c6", "Nf3", "d5", "Bb3", "Bd6", "exd5", "cxd5", "O-O", "O-O", "Nc3", "Nc6",
            ],
        },
        {
            "chapter": {"id": "bc5", "title": c("2…Fc5 — 3.c3 & d4", "2…Bc5 — 3.c3 & d4")},
            "moves": [
                "e4", "e5", "Bc4", "Bc5",
                {"san": "c3", "comment": c("On prépare d4 pour bâtir un centre : c'est l'esprit du gambit Evans, sans …b4.",
                                           "Preparing d4 to build a centre: the spirit of the Evans Gambit, without …b4.")},
                "Nf6", "d4", "exd4", "cxd4", "Bb4+", "Bd2", "Bxd2+", "Nbxd2", "d5", "exd5", "Nxd5", "Ngf3", "O-O",
            ],
        },
        {
            "chapter": {"id": "urusov", "title": c("Gambit Urusov — 3.d4", "Urusov Gambit — 3.d4")},
            "moves": [
                "e4", "e5", "Bc4", "Nf6",
                {"san": "d4", "comment": c("Le gambit Urusov : un pion contre un développement fulgurant et une attaque sur f7.",
                                           "The Urusov Gambit: a pawn for lightning development and an attack on f7.")},
                "exd4", "Nf3", "Nc6", "e5", "d5", "Bb5", "Ne4", "Nxd4", "Bc5",
            ],
        },
    ],
}
