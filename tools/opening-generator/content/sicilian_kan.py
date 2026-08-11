# -*- coding: utf-8 -*-
"""Sicilienne Kan / Paulsen (1.e4 c5 2.Cf3 e6 3.d4 cxd4 4.Cxd4 a6) — NOIR.

La plus flexible des siciliennes : …a6 tôt, on retarde …Cc6 et …d6 pour garder
une structure caméléon. Arbre : 5.Fd3 (principale), 5.c4 (étau Maroczy),
5.Cc3 b5 (hérisson). Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-kan",
    "name": "Sicilian Defense: Kan",
    "side": "black",
    "level": "advanced",
    "eco": ["B41", "B43"],
    "summary": c(
        "La sicilienne caméléon : …a6 d'abord, on garde toutes les structures possibles (hérisson, Scheveningen, …Fc5). Peu de théorie forcée, beaucoup de compréhension.",
        "The chameleon Sicilian: …a6 first, keeping every structure available (Hedgehog, Scheveningen, …Bc5). Little forced theory, lots of understanding.",
    ),
    "lines": [
        # 1) 5.Fd3 (principale)
        {
            "chapter": {"id": "bd3", "title": c("5.Fd3", "5.Bd3")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4",
                {"san": "a6", "eco": "Sicilian Defense: Kan Variation",
                 "comment": c("Le coup Kan : …a6 tout de suite, on retarde les autres coups pour rester caméléon.",
                              "The Kan move: …a6 straight away, delaying the rest to stay chameleon-like.")},
                {"san": "Bd3", "comment": c("Le développement le plus naturel ; les Noirs répliquent souvent par …Cf6 et …Dc7.",
                                            "The most natural development; Black usually answers …Nf6 and …Qc7.")},
                "Nf6", "O-O", "Qc7", "Qe2", "d6", "c4", "g6", "Nc3", "Bg7", "Be3", "O-O",
            ],
        },
        # 2) 5.c4 — étau Maroczy
        {
            "chapter": {"id": "maroczy", "title": c("5.c4 — étau Maroczy", "5.c4 — Maróczy bind")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "a6",
                {"san": "c4", "comment": c("L'étau : c4+e4 empêchent …d5 et …b5. Les Noirs jouent …Cf6, …Fb4 et cherchent …d5 plus tard.",
                                           "The bind: c4+e4 stop …d5 and …b5. Black plays …Nf6, …Bb4 and works toward …d5 later.")},
                "Nf6", "Nc3", "Bb4", "Bd3", "Nc6", "Nxc6", "dxc6", "O-O", "e5",
            ],
        },
        # 3) 5.Cc3 b5 — hérisson
        {
            "chapter": {"id": "hedgehog", "title": c("5.Cc3 b5 — hérisson", "5.Nc3 b5 — Hedgehog")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "a6", "Nc3",
                {"san": "b5", "comment": c("Le hérisson : pions en a6-b5-d6-e6, pièces ramassées, prêtes à jaillir par …d5 ou …b4.",
                                           "The Hedgehog: pawns on a6-b5-d6-e6, pieces coiled, ready to spring with …d5 or …b4.")},
                "Bd3", "Bb7", "O-O", "Nf6", "Qe2", "d6",
            ],
        },
    ],
}
