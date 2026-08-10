# -*- coding: utf-8 -*-
"""Ouverture Bird (1.f4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "birds-opening",
    "name": "Bird's Opening",
    "side": "white",
    "level": "club",
    "eco": ["A02", "A03"],
    "summary": c(
        "Une sicilienne inversée : 1.f4 contrôle e5 et vise une attaque à l'aile roi. Attention au contre-gambit From, à connaître absolument.",
        "A reversed Sicilian: 1.f4 controls e5 and aims for a kingside attack. Beware From's Gambit — a must-know.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Bird classique — 1…d5", "Classical Bird — 1…d5")},
            "moves": [
                {"san": "f4", "eco": "Bird Opening",
                 "comment": c("On prend e5 sous contrôle et on prépare un fianchetto ou une structure Stonewall.",
                              "Control e5 and prepare a fianchetto or a Stonewall structure.")},
                "d5", "Nf3", "Nf6", "e3", "g6", "Be2", "Bg7", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "from", "title": c("Contre-gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4",
                {"san": "e5", "role": "trap", "critical": True,
                 "eco": "Bird Opening: From's Gambit",
                 "comment": c("Le contre-gambit From : un pion pour une attaque immédiate. À NE PAS prendre à la légère.",
                              "From's Gambit: a pawn for an immediate attack. NOT to be taken lightly.")},
                "fxe5", "d6", "exd6", "Bxd6",
                {"san": "Nf3", "comment": c("Le coup vital : Cf3 empêche le mat …Dh4+ et …Dxf2. Sans lui, les Blancs se font massacrer.",
                                            "The vital move: Nf3 stops the …Qh4+ and …Qxf2 mate. Without it, White gets crushed.")},
                "g5",
            ],
        },
    ],
}
