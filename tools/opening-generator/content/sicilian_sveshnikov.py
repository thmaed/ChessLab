# -*- coding: utf-8 -*-
"""Sicilienne Sveshnikov (1.e4 c5 2.Cf3 Cc6 3.d4 cxd4 4.Cxd4 Cf6 5.Cc3 e5) — NOIR.

Le pari …e5 : les Noirs acceptent un trou en d5 pour une activité de pièces
énorme. Arbre : ligne principale 6.Cdb5 d6 7.Fg5, la variante 7.Cd5, et la
Kalashnikov (4…e5 sans …Cf6). Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-sveshnikov",
    "name": "Sicilian Defense: Sveshnikov",
    "side": "black",
    "level": "advanced",
    "eco": ["B32", "B33"],
    "summary": c(
        "Le grand pari moderne : …e5 concède le trou d5 mais donne aux pièces noires une activité folle. Théorie dense, mais des plans dynamiques très clairs.",
        "The great modern gamble: …e5 concedes the d5 hole but gives Black's pieces wild activity. Heavy theory, but very clear dynamic plans.",
    ),
    "lines": [
        # 1) Ligne principale — 6.Cdb5 d6 7.Fg5
        {
            "chapter": {"id": "main", "title": c("Principale — 6.Cdb5 d6 7.Fg5", "Main — 6.Ndb5 d6 7.Bg5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "e5", "eco": "Sicilian Defense: Sveshnikov Variation",
                 "comment": c("Le coup Sveshnikov : on repousse le cavalier et on revendique le centre malgré le trou en d5.",
                              "The Sveshnikov move: kick the knight and claim the centre despite the d5 hole.")},
                {"san": "Ndb5", "comment": c("Le cavalier saute en b5 pour viser d6 ; les Noirs vont le chasser et jouer …f5.",
                                             "The knight leaps to b5 to eye d6; Black will chase it and play …f5.")},
                "d6",
                {"san": "Bg5", "comment": c("Le clouage sur f6 pèse sur d5, la case-clé. La bataille tourne autour de d5.",
                                            "The pin on f6 presses d5, the key square. The whole fight is about d5.")},
                "a6", "Na3", "b5", "Bxf6", "gxf6",
                {"san": "Nd5", "comment": c("Les Blancs occupent d5 ; en retour, les Noirs ont la paire de fous et …f5.",
                                            "White plants a knight on d5; in return Black has the bishop pair and …f5.")},
                "f5", "Bd3", "Be6", "O-O", "Bxd5", "exd5", "Ne7", "c4", "Bg7",
            ],
        },
        # 2) Variante 7.Cd5
        {
            "chapter": {"id": "nd5", "title": c("Variante 7.Cd5", "The 7.Nd5 line")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "e5", "Ndb5", "d6",
                {"san": "Nd5", "comment": c("On installe le cavalier en d5 tout de suite. Les Noirs le prennent et jouent contre le pion d5.",
                                            "Planting the knight on d5 at once. Black takes it and plays against the d5 pawn.")},
                "Nxd5", "exd5", "Nb8", "c4", "a6", "Nc3", "Be7", "Bd3", "O-O",
            ],
        },
        # 3) Kalashnikov — 4…e5 (sans …Cf6)
        {
            "chapter": {"id": "kalashnikov", "title": c("Kalashnikov — 4…e5", "Kalashnikov — 4…e5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4",
                {"san": "e5", "comment": c("La Kalashnikov : …e5 AVANT …Cf6, pour garder le cavalier roi plus souple.",
                                           "The Kalashnikov: …e5 BEFORE …Nf6, keeping the king's knight more flexible.")},
                "Nb5", "d6",
                {"san": "c4", "comment": c("L'étau : c4+e4 brident …d5. Les Noirs manœuvrent (…Fe7, …Cf6, …Fe6) et visent …b5/…f5.",
                                           "The bind: c4+e4 restrain …d5. Black manoeuvres (…Be7, …Nf6, …Be6) and aims for …b5/…f5.")},
                "Be7", "N1c3", "a6", "Na3", "Be6", "Be2", "Nf6", "O-O", "O-O",
            ],
        },
    ],
}
