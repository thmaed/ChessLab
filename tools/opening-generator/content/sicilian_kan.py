# -*- coding: utf-8 -*-
"""Sicilienne Kan / Paulsen (1.e4 c5 2.Cf3 e6 3.d4 cxd4 4.Cxd4 a6) — NOIR.

La plus flexible des siciliennes : …a6 tôt, on retarde …Cc6 et …d6 pour garder
une structure caméléon. Arbre : 5.Fd3 (principale), 5.c4 (étau Maroczy),
5.Cc3 b5 (hérisson). Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Le fou en c4, qui empêche la Sicilienne ouverte (16/08) ───────────
        #
        # Toutes les Siciliennes de ce répertoire supposent 2.Cf3 puis 3.d4.
        # Les sorties précoces du fou en c4 l'évitent, et aucun cours ne les
        # traitait. Le remède est le même partout — …e6 coupe la diagonale et
        # prépare …d5 — mais il fallait l'écrire.
        {
            "chapter": {"id": "vs-bc4", "title": c("2.Fc4 et 3.Fc4", "2.Bc4 and 3.Bc4")},
            "moves": [
                "e4", "c5",
                {"san": "Bc4",
                 "comment": c("Le fou sort avant tout, en visant f7. Sans centre pour l'appuyer, l'attaque n'arrivera jamais.",
                              "The bishop develops first, eyeing f7. With no centre behind it, the attack never comes."),
                 "critical": True},
                {"san": "e6", "critical": True,
                 "comment": c("On coupe la diagonale et l'on prépare …d5. Le fou c4 devra bouger une seconde fois — deux temps perdus pour les Blancs.",
                              "We cut the diagonal and prepare …d5. The c4 bishop must move again — two tempi lost for White.")},
                "Nf3", "Nf6", "Qe2", "a6", "d3", "b5",
                {"san": "Bb3",
                 "comment": c("Le fou recule, et notre expansion à l'aile dame est gratuite : c'est exactement le jeu qu'une Sicilienne cherche.",
                              "The bishop retreats and our queenside expansion is free: precisely the kind of play a Sicilian wants.")},
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("2.Fc4 et 3.Fc4", "2.Bc4 and 3.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "e6",
                {"san": "Bc4",
                 "comment": c("Une partie sur sept après 2…e6. Même traitement : on développe, on pousse …b5, et le fou perd son temps.",
                              "One game in seven after 2…e6. Same treatment: develop, play …b5, and the bishop loses time.")},
                "Nf6", "Qe2", "a6", "Bb3", "b5", "d3",
            ],
        },
    ],
}
