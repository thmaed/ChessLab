# -*- coding: utf-8 -*-
"""Gambit dame refusé (1.d4 d5 2.c4 e6) — répertoire BLANC.

Arbre approfondi : Orthodoxe/Tartakower, variante de l'échange (attaque de
minorité), variante Lasker, Cambridge Springs. Lignes vérifiées (Wikipédia).
"""


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
        # 1) Orthodoxe / Tartakower
        {
            "chapter": {"id": "orthodox", "title": c("Orthodoxe / Tartakower", "Orthodox / Tartakower")},
            "moves": [
                "d4", "d5",
                {"san": "c4", "comment": c("Le gambit dame : on offre c4 pour dévier le pion d5 et dominer le centre.",
                                           "The Queen's Gambit: offering c4 to deflect the d5 pawn and control the centre.")},
                {"san": "e6", "eco": "Queen's Gambit Declined",
                 "comment": c("Le refus solide : les Noirs soutiennent d5 (mais enferment leur fou c8).",
                              "The solid decline: Black supports d5 (but shuts in the c8 bishop).")},
                "Nc3", "Nf6", "Bg5", "Be7", "e3", "O-O", "Nf3", "h6", "Bh4",
                {"san": "b6", "comment": c("Le système Tartakower : les Noirs résolvent le fou c8 par …Fb7.",
                                           "The Tartakower system: Black solves the c8 bishop with …Bb7.")},
                "cxd5", "Nxd5", "Bxe7", "Qxe7", "Nxd5", "exd5", "Rc1", "Be6",
            ],
        },
        # 2) Variante de l'échange — attaque de minorité
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "d4", "d5", "c4", "e6",
                {"san": "cxd5", "eco": "Queen's Gambit Declined: Exchange Variation",
                 "comment": c("L'échange donne la fameuse attaque de minorité : b4-b5 pour créer une faiblesse en c6.",
                              "The exchange gives the famous minority attack: b4-b5 to create a weakness on c6.")},
                "exd5", "Nc3", "Nf6", "Bg5", "c6", "Qc2", "Be7", "e3", "O-O", "Bd3", "Nbd7", "Nge2", "Re8", "O-O", "Nf8",
            ],
        },
        # 3) Variante Lasker
        {
            "chapter": {"id": "lasker", "title": c("Variante Lasker", "Lasker Variation")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "Nf6", "Bg5", "Be7", "e3", "O-O", "Nf3", "h6", "Bh4",
                {"san": "Ne4", "comment": c("La Lasker : on échange des pièces pour alléger la position étriquée des Noirs.",
                                            "The Lasker: trade pieces to ease Black's cramped position.")},
                "Bxe7", "Qxe7", "cxd5", "Nxc3", "bxc3", "exd5", "Qb3", "Rd8", "c4", "dxc4", "Bxc4",
            ],
        },
        # 4) Cambridge Springs
        {
            "chapter": {"id": "cambridge-springs", "title": c("Cambridge Springs", "Cambridge Springs")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "Nf6", "Bg5", "Nbd7", "Nf3", "c6", "e3",
                {"san": "Qa5", "eco": "Queen's Gambit Declined: Cambridge Springs Defense",
                 "comment": c("Cambridge Springs : la dame cloue c3 et menace …Ce4 ou …dxc4 avec du contre-jeu.",
                              "Cambridge Springs: the queen pins c3 and threatens …Ne4 or …dxc4 with counterplay.")},
                "Nd2", "Bb4", "Qc2", "O-O", "Bh4", "c5",
            ],
        },
    ],
}
