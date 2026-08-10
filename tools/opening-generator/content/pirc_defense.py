# -*- coding: utf-8 -*-
"""Défense Pirc (1.e4 d6 2.d4 Cf6 3.Cc3 g6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "pirc-defense",
    "name": "Pirc Defense",
    "side": "black",
    "level": "club",
    "eco": ["B07", "B09"],
    "summary": c(
        "Hypermoderne : on laisse les Blancs bâtir un grand centre… pour mieux le harceler avec le fou g7, …e5 et …c5. Souple et piégeuse.",
        "Hypermodern: let White build a big centre… then harass it with the g7 bishop, …e5 and …c5. Flexible and tricky.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Système classique — 4.Cf3", "Classical System — 4.Nf3")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3",
                {"san": "g6", "eco": "Pirc Defense",
                 "comment": c("Le Pirc : le fou file en g7 et vise le centre à distance.",
                              "The Pirc: the bishop goes to g7 and targets the centre from afar.")},
                {"san": "Nf3", "comment": c("Le développement le plus naturel et le plus sûr.",
                                            "The most natural and safest development.")},
                "Bg7", "Be2", "O-O", "O-O", "c6",
            ],
        },
        {
            "chapter": {"id": "austrian", "title": c("Attaque autrichienne — 4.f4", "Austrian Attack — 4.f4")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6",
                {"san": "f4", "eco": "Pirc Defense: Austrian Attack",
                 "comment": c("L'Attaque autrichienne, la plus ambitieuse : centre massif et poussée f5 en vue.",
                              "The Austrian Attack, the most ambitious: a huge centre with f5 in the air.")},
                "Bg7", "Nf3", "O-O",
                {"san": "Bd3", "comment": c("Les Noirs contre-attaquent au bon moment par …c5 ou …e5.",
                                            "Black counters at the right moment with …c5 or …e5.")},
                "Na6",
            ],
        },
        {
            "chapter": {"id": "150", "title": c("Attaque 150 — 4.Fe3", "150 Attack — 4.Be3")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6",
                {"san": "Be3", "comment": c("L'Attaque 150 : Dd2 et Fh6 pour échanger le fort fou g7, puis h4-h5.",
                                            "The 150 Attack: Qd2 and Bh6 to trade the strong g7 bishop, then h4-h5.")},
                "Bg7", "Qd2", "c6", "f3", "b5",
            ],
        },
    ],
}
