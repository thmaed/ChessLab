# -*- coding: utf-8 -*-
"""Gambit Blackmar-Diemer (1.d4 d5 2.e4) — répertoire BLANC (gambit)."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "blackmar-diemer",
    "name": "Blackmar-Diemer Gambit",
    "side": "white",
    "level": "club",
    "eco": ["D00"],
    "summary": c(
        "Un pion contre un développement fulgurant et une colonne f ouverte droit sur f7. Théoriquement douteux, mais un cauchemar à défendre à la pendule.",
        "A pawn for lightning development and an open f-file aimed at f7. Theoretically dubious, but a nightmare to defend on the clock.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Ligne acceptée", "Accepted Main Line")},
            "moves": [
                "d4", "d5",
                {"san": "e4", "eco": "Blackmar-Diemer Gambit",
                 "comment": c("Le gambit : on offre e4 pour ouvrir le jeu immédiatement.",
                              "The gambit: offering e4 to blow the game open at once.")},
                "dxe4", "Nc3", "Nf6",
                {"san": "f3", "comment": c("Le second pion offert : on veut à tout prix la colonne f et un centre dynamique.",
                                           "The second pawn offered: White wants the f-file and a dynamic centre at all costs.")},
                "exf3", "Nxf3",
                {"san": "g6", "comment": c("Après Cxf3, les Blancs ont Fc4, Dd3/De1-h4 et une attaque bien réelle sur f7 et le roi.",
                                           "After Nxf3, White has Bc4, Qd3/Qe1-h4 and a very real attack on f7 and the king.")},
                "Bc4", "Bg7", "O-O", "O-O",
            ],
        },
    ],
}
