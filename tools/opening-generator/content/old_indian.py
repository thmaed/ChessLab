# -*- coding: utf-8 -*-
"""Défense est-indienne ancienne / Old Indian (1.d4 Cf6 2.c4 d6) — NOIR.

La version solide et sans fianchetto de l'est-indienne : …d6 et …e5, un jeu de
manœuvre à la Tchigorine des indiennes. Arbre : 3.Cc3 e5 4.Cf3, l'échange
4.dxe5, et 3.Cf3 Fg4. Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Quand les Blancs ne jouent pas c4 (16/08) ─────────────────────────
        {
            "chapter": {"id": "vs-london", "title": c("Contre la London — 2.Ff4", "vs the London — 2.Bf4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bf4",
                 "comment": c("Une partie sur six. L'Est-Indienne ancienne se joue …d6 et …e5 ; contre la London, …d5 est plus net, le fou f4 n'ayant plus de cible.",
                              "One game in six. The Old Indian plays …d6 and …e5; against the London, …d5 is cleaner — the f4 bishop has no target left."),
                 "critical": True},
                "d5", "e3", "c5", "Nc3", "cxd4", "exd4", "a6",
            ],
        },
        {
            "chapter": {"id": "vs-nf3", "title": c("Contre 2.Cf3", "vs 2.Nf3")},
            "moves": [
                "d4", "Nf6", "Nf3", "e6", "c4", "d5", "cxd5", "exd5", "Nc3",
                {"san": "Bb4",
                 "comment": c("Le clouage reste disponible : on est passé d'une Est-Indienne ancienne à une Nimzo par transposition, ce qui est un bon échange.",
                              "The pin is still available: we've slipped from an Old Indian into a Nimzo by transposition, which is a good trade.")},
            ],
        },
    ],
}
