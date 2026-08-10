# -*- coding: utf-8 -*-
"""Benoni moderne (1.d4 Cf6 2.c4 c5 3.d5 e6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "modern-benoni",
    "name": "Modern Benoni",
    "side": "black",
    "level": "advanced",
    "eco": ["A60", "A79"],
    "summary": c(
        "Déséquilibre assumé : centre blanc contre majorité noire à l'aile dame et fou g7 mordant. Tactique, risquée, mais riche en contre-jeu par …b5.",
        "Deliberate imbalance: White's centre versus Black's queenside majority and a biting g7 bishop. Tactical, risky, but full of counterplay with …b5.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Ligne classique", "Classical Main Line")},
            "moves": [
                "d4", "Nf6", "c4", "c5",
                {"san": "d5", "comment": c("Les Blancs ferment ; la structure Benoni se met en place.",
                                           "White closes; the Benoni structure takes shape.")},
                {"san": "e6", "eco": "Benoni Defense: Modern Variation",
                 "comment": c("On attaque d5 pour ouvrir la colonne e et fixer la structure caractéristique.",
                              "Striking d5 to open the e-file and fix the signature structure.")},
                "Nc3", "exd5", "cxd5", "d6", "e4", "g6", "Nf3", "Bg7", "Be2", "O-O", "O-O", "Re8",
            ],
        },
        {
            "chapter": {"id": "taimanov", "title": c("Attaque Taimanov — 7.f4 Fb5+", "Taimanov — 7.f4 Bb5+")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "e6", "Nc3", "exd5", "cxd5", "d6", "e4", "g6",
                {"san": "f4", "comment": c("L'Attaque Taimanov, la plus redoutée : les Blancs menacent e4-e5 pour balayer le centre.",
                                           "The feared Taimanov Attack: White threatens e4-e5 to sweep the centre.")},
                "Bg7",
                {"san": "Bb5+", "comment": c("L'échec précis avant d'installer le centre. …Cfd7 est la réponse principale.",
                                             "The precise check before setting up the centre. …Nfd7 is the main reply.")},
                "Nfd7",
            ],
        },
        {
            "chapter": {"id": "fianchetto", "title": c("Variante du fianchetto — g3", "Fianchetto Variation — g3")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "e6", "Nc3", "exd5", "cxd5", "d6", "Nf3", "g6",
                {"san": "g3", "comment": c("Le fianchetto : jeu plus calme et positionnel, le fou g2 surveille d5 et b7.",
                                           "The fianchetto: calmer, positional play; the g2 bishop watches d5 and b7.")},
                "Bg7", "Bg2", "O-O", "O-O", "Re8",
            ],
        },
    ],
}
