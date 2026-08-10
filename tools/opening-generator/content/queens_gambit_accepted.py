# -*- coding: utf-8 -*-
"""Gambit dame accepté (1.d4 d5 2.c4 dxc4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "queens-gambit-accepted",
    "name": "Queen's Gambit Accepted",
    "side": "white",
    "level": "club",
    "eco": ["D20", "D29"],
    "summary": c(
        "Les Noirs prennent en c4 — mais ne peuvent pas garder le pion. Les Blancs reprennent le centre par e3/e4 et jouissent d'une belle liberté de développement.",
        "Black grabs c4 — but can't hold the pawn. White regains the centre with e3/e4 and enjoys easy, free development.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Ligne principale — 3.Cf3", "Main Line — 3.Nf3")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "dxc4", "eco": "Queen's Gambit Accepted",
                 "comment": c("Accepter le pion : les Noirs ne le garderont pas, mais gagnent du temps de développement.",
                              "Accepting the pawn: Black won't keep it, but gains development time.")},
                {"san": "Nf3", "comment": c("On empêche …e5 avant de reprendre le pion tranquillement.",
                                            "Stopping …e5 before calmly recovering the pawn.")},
                "Nf6", "e3", "e6", "Bxc4", "c5", "O-O", "a6",
            ],
        },
        {
            "chapter": {"id": "central", "title": c("Variante centrale — 3.e4", "Central Variation — 3.e4")},
            "moves": [
                "d4", "d5", "c4", "dxc4",
                {"san": "e4", "eco": "Queen's Gambit Accepted: Central Variation",
                 "comment": c("La version ambitieuse : les Blancs bâtissent d'emblée un centre e4+d4 imposant.",
                              "The ambitious version: White builds a big e4+d4 centre at once.")},
                "e5", "Nf3", "exd4", "Bxc4", "Nc6",
            ],
        },
    ],
}
