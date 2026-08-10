# -*- coding: utf-8 -*-
"""Défense Caro-Kann (1.e4 c6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "caro-kann",
    "name": "Caro-Kann Defense",
    "side": "black",
    "level": "club",
    "eco": ["B10", "B19"],
    "summary": c(
        "La solidité incarnée : comme la française, les Noirs jouent …d5, mais SANS enfermer leur fou de cases blanches, qui sort en f5. Structure saine, plan clair.",
        "Solidity itself: like the French, Black plays …d5 — but WITHOUT shutting in the light-squared bishop, which comes out to f5. Sound structure, clear plan.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Variante classique", "Classical Variation")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "Nc3", "comment": c("Le développement classique ; les Noirs vont prendre en e4 et sortir leur fou.",
                                            "The classical development; Black will take on e4 and free the bishop.")},
                "dxe4", "Nxe4",
                {"san": "Bf5", "eco": "Caro-Kann Defense: Classical Variation",
                 "comment": c("Toute l'idée de la Caro : le fou sort AVANT …e6. Aucune pièce enfermée.",
                              "The whole point of the Caro: the bishop develops BEFORE …e6. No piece shut in.")},
                "Ng3", "Bg6", "h4", "h6", "Nf3", "Nd7",
            ],
        },
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance", "Advance Variation")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "e5", "eco": "Caro-Kann Defense: Advance Variation",
                 "comment": c("L'avance : le centre se ferme. Contrairement à la française, le fou noir respire.",
                              "The Advance: the centre closes. Unlike the French, Black's bishop breathes.")},
                {"san": "Bf5", "comment": c("Le fou sort immédiatement — c'est le grand avantage sur la française.",
                                            "The bishop comes out at once — the big edge over the French.")},
                "Nf3", "e6", "Be2", "c5",
            ],
        },
        {
            "chapter": {"id": "panov", "title": c("Attaque Panov", "Panov Attack")},
            "moves": [
                "e4", "c6", "d4", "d5", "exd5", "cxd5",
                {"san": "c4", "eco": "Caro-Kann Defense: Panov Attack",
                 "comment": c("L'attaque Panov : jeu ouvert avec pion isolé — plus dynamique que le reste de la Caro.",
                              "The Panov Attack: open play with an isolated pawn — more dynamic than the rest of the Caro.")},
                "Nf6", "Nc3", "e6", "Nf3", "Be7",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "c6", "d4", "d5", "exd5", "cxd5",
                {"san": "Bd3", "eco": "Caro-Kann Defense: Exchange Variation",
                 "comment": c("L'échange tranquille : structure symétrique, les Noirs égalisent sans difficulté.",
                              "The quiet exchange: symmetrical structure, Black equalises easily.")},
                "Nc6", "c3", "Nf6",
            ],
        },
        {
            "chapter": {"id": "fantasy", "title": c("Variante Fantaisie — 3.f3", "Fantasy Variation — 3.f3")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "f3", "eco": "Caro-Kann Defense: Fantasy Variation",
                 "comment": c("La Fantaisie : les Blancs soutiennent e4 à tout prix. Frapper le centre est la bonne réaction.",
                              "The Fantasy: White props up e4 at all costs. Striking the centre is the right reaction.")},
                "e6", "Nc3", "Bb4",
            ],
        },
    ],
}
