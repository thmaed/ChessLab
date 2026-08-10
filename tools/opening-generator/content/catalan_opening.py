# -*- coding: utf-8 -*-
"""Catalane (1.d4 Cf6 2.c4 e6 3.g3) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "catalan-opening",
    "name": "Catalan Opening",
    "side": "white",
    "level": "advanced",
    "eco": ["E00", "E09"],
    "summary": c(
        "Le meilleur des deux mondes : la structure solide du gambit dame plus un fou en g2 qui rayonne sur la grande diagonale. Pression durable, sans risque.",
        "The best of both worlds: the solid Queen's Gambit structure plus a g2 bishop raking the long diagonal. Lasting pressure, minimal risk.",
    ),
    "lines": [
        {
            "chapter": {"id": "closed", "title": c("Catalane fermée", "Closed Catalan")},
            "moves": [
                "d4", "Nf6", "c4", "e6",
                {"san": "g3", "eco": "Catalan Opening",
                 "comment": c("Le fianchetto catalan : le fou g2 vise b7 et met une pression permanente sur d5.",
                              "The Catalan fianchetto: the g2 bishop eyes b7 and presses permanently on d5.")},
                "d5", "Bg2", "Be7", "Nf3", "O-O", "O-O", "c6",
            ],
        },
        {
            "chapter": {"id": "open", "title": c("Catalane ouverte — …dxc4", "Open Catalan — …dxc4")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "g3", "d5", "Bg2",
                {"san": "dxc4", "eco": "Catalan Opening: Open Defense",
                 "comment": c("Les Noirs prennent le pion. Les Blancs le récupèrent souvent grâce à la pression du fou g2 (Ce5, Da4).",
                              "Black takes the pawn. White usually regains it thanks to the g2 bishop's pressure (Ne5, Qa4).")},
                "Nf3", "a6", "O-O", "Nc6", "e3", "Bd7",
            ],
        },
    ],
}
