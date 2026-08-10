# -*- coding: utf-8 -*-
"""Gambit dame refusé (1.d4 d5 2.c4 e6) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "queens-gambit-declined",
    "name": "Queen's Gambit Declined",
    "side": "white",
    "level": "club",
    "eco": ["D30", "D69"],
    "summary": c(
        "L'ouverture classique par excellence : le gambit dame met une pression durable au centre. Les Noirs refusent par …e6, sûrs mais un peu passifs.",
        "The classical opening par excellence: the Queen's Gambit puts lasting pressure on the centre. Black declines with …e6, solid but a touch passive.",
    ),
    "lines": [
        {
            "chapter": {"id": "orthodox", "title": c("Défense orthodoxe", "Orthodox Defence")},
            "moves": [
                "d4", "d5",
                {"san": "c4", "comment": c("Le gambit dame : on offre c4 pour dévier le pion d5 et dominer le centre.",
                                           "The Queen's Gambit: offering c4 to deflect the d5 pawn and control the centre.")},
                {"san": "e6", "eco": "Queen's Gambit Declined",
                 "comment": c("Le refus solide : les Noirs soutiennent d5 (mais enferment leur fou c8).",
                              "The solid decline: Black supports d5 (but shuts in the c8 bishop).")},
                "Nc3", "Nf6", "Bg5", "Be7", "e3", "O-O", "Nf3", "h6", "Bh4", "b6",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "d4", "d5", "c4", "e6",
                {"san": "cxd5", "eco": "Queen's Gambit Declined: Exchange Variation",
                 "comment": c("L'échange donne la fameuse attaque de minorité : b4-b5 pour créer une faiblesse en c6.",
                              "The exchange gives the famous minority attack: b4-b5 to create a weakness on c6.")},
                "exd5", "Nc3", "Nf6", "Bg5", "c6", "Qc2", "Be7",
            ],
        },
    ],
}
