# -*- coding: utf-8 -*-
"""Gambit letton (1.e4 e5 2.Cf3 f5) — répertoire NOIR (gambit)."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "latvian-gambit",
    "name": "Latvian Gambit",
    "side": "black",
    "level": "advanced",
    "eco": ["C40"],
    "summary": c(
        "Une sicilienne à l'envers et à un temps de moins : …f5 très tôt, follement risqué. Une arme de surprise pour les joueurs qui aiment le chaos.",
        "A reversed Sicilian a tempo down: …f5 very early, wildly risky. A surprise weapon for players who love chaos.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("3.Cxe5 — ligne principale", "3.Nxe5 — Main Line")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "f5", "eco": "Latvian Gambit",
                 "comment": c("Le gambit letton : on frappe e4 tout de suite, au mépris de la sécurité du roi.",
                              "The Latvian Gambit: hitting e4 at once, heedless of king safety.")},
                {"san": "Nxe5", "comment": c("Le plus critique : les Blancs prennent le pion et le cavalier trône en e5.",
                                             "The most critical: White grabs the pawn and the knight sits proudly on e5.")},
                {"san": "Qf6", "critical": True,
                 "comment": c("On attaque le cavalier e5 et on prépare …d6 pour le chasser avec du jeu.",
                              "Attacking the e5 knight and preparing …d6 to kick it away with active play.")},
                "d4", "d6", "Nc4", "fxe4", "Nc3", "Qg6",
            ],
        },
        {
            "chapter": {"id": "exf5", "title": c("3.exf5", "3.exf5")},
            "moves": [
                "e4", "e5", "Nf3", "f5",
                {"san": "exf5", "comment": c("Prendre en f5 rend le pion e5 fort : …e4 chasse le cavalier et les Noirs avancent.",
                                             "Taking on f5 makes the e5 pawn strong: …e4 kicks the knight and Black rolls forward.")},
                "e4", "Ne5", "Nf6",
            ],
        },
    ],
}
