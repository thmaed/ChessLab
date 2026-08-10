# -*- coding: utf-8 -*-
"""Attaque est-indienne / KIA (set-up Cf3, g3, Fg2, d3, Cbd2, e4) — BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-indian-attack",
    "name": "King's Indian Attack",
    "side": "white",
    "level": "club",
    "eco": ["A07", "C00"],
    "summary": c(
        "Un SYSTÈME universel : mêmes coups (Cf3, g3, Fg2, O-O, d3, Cbd2, e4) contre presque tout. On joue des plans, pas de la théorie — l'attaque à l'aile roi vient souvent seule.",
        "A universal SYSTEM: the same moves (Nf3, g3, Bg2, O-O, d3, Nbd2, e4) against almost everything. Play plans, not theory — the kingside attack often comes by itself.",
    ),
    "lines": [
        {
            "chapter": {"id": "vs-french", "title": c("KIA contre la structure française", "KIA vs the French structure")},
            "moves": [
                "e4", "e6",
                {"san": "d3", "eco": "King's Indian Attack",
                 "comment": c("On renonce au grand centre pour un système d'attaque à coup sûr.",
                              "Give up the big centre for a reliable attacking system.")},
                "d5", "Nd2", "Nf6", "Ngf3", "c5", "g3", "Nc6", "Bg2", "Be7", "O-O", "O-O",
                {"san": "Re1", "comment": c("La rupture e4-e5 arrive : elle gagne de l'espace et lance l'assaut Cf1-h4, Ff4, h4.",
                                            "The e4-e5 break is coming: it grabs space and launches the Nf1-h4, Bf4, h4 assault.")},
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("KIA via 1.Cf3 d5", "KIA via 1.Nf3 d5")},
            "moves": [
                "Nf3", "d5", "g3", "Nf6", "Bg2", "e6", "O-O", "Be7", "d3", "O-O", "Nbd2", "c5",
            ],
        },
    ],
}
