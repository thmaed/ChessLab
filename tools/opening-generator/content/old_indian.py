# -*- coding: utf-8 -*-
"""Défense est-indienne ancienne / Old Indian (1.d4 Cf6 2.c4 d6) — NOIR.

La version solide et sans fianchetto de l'est-indienne : …d6 et …e5, un jeu de
manœuvre à la Tchigorine des indiennes. Arbre : 3.Cc3 e5 4.Cf3, l'échange
4.dxe5, et 3.Cf3 Fg4. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "old-indian",
    "name": "Old Indian Defense",
    "side": "black",
    "level": "club",
    "eco": ["A53", "A55"],
    "summary": c(
        "La grande sœur discrète de l'est-indienne : …d6 et …e5 SANS fianchetto, un jeu de manœuvre solide et sans faiblesse. Simple à comprendre, dure à casser.",
        "The quiet elder sister of the King's Indian: …d6 and …e5 WITHOUT the fianchetto, solid manoeuvring play with no weaknesses. Easy to grasp, hard to break.",
    ),
    "lines": [
        # 1) 3.Cc3 e5 4.Cf3 (principale)
        {
            "chapter": {"id": "main", "title": c("3.Cc3 e5 4.Cf3", "3.Nc3 e5 4.Nf3")},
            "moves": [
                "d4", "Nf6", "c4",
                {"san": "d6", "eco": "Old Indian Defense",
                 "comment": c("L'Old Indian : …d6 pour soutenir …e5, sans fianchetto — solide et facile à jouer.",
                              "The Old Indian: …d6 to support …e5, no fianchetto — solid and easy to play.")},
                "Nc3",
                {"san": "e5", "comment": c("La rupture centrale : on conteste d4 tout de suite.",
                                           "The central break: challenging d4 at once.")},
                "Nf3", "Nbd7", "e4", "Be7", "Be2", "O-O", "O-O", "c6",
            ],
        },
        # 2) Échange — 4.dxe5
        {
            "chapter": {"id": "exchange", "title": c("Échange — 4.dxe5", "Exchange — 4.dxe5")},
            "moves": [
                "d4", "Nf6", "c4", "d6", "Nc3", "e5",
                {"san": "dxe5", "comment": c("L'échange mène à une finale de dames absente, saine et parfaitement tenable pour les Noirs.",
                                             "The exchange leads to a queenless, sound endgame, perfectly holdable for Black.")},
                "dxe5", "Qxd8+", "Kxd8", "g3", "c6", "Bg2", "Nbd7", "Nf3", "Bd6",
            ],
        },
        # 3) 3.Cf3 Fg4
        {
            "chapter": {"id": "bg4", "title": c("3.Cf3 Fg4", "3.Nf3 Bg4")},
            "moves": [
                "d4", "Nf6", "c4", "d6", "Nf3",
                {"san": "Bg4", "comment": c("Le clouage : on échange le fou contre le cavalier f3 pour mieux jouer …e5.",
                                            "The pin: trade the bishop for the f3-knight to make …e5 stronger.")},
                "Nc3", "Nbd7", "e4", "e5", "Be2", "Be7", "O-O", "O-O",
            ],
        },
    ],
}
