# -*- coding: utf-8 -*-
"""Défense Alekhine (1.e4 Cf6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "alekhine-defense",
    "name": "Alekhine Defense",
    "side": "black",
    "level": "club",
    "eco": ["B02", "B05"],
    "summary": c(
        "Provocante : le cavalier invite les pions blancs à avancer… pour en faire des cibles. Une arme hypermoderne pleine de venin.",
        "Provocative: the knight invites White's pawns forward… to turn them into targets. A venomous hypermodern weapon.",
    ),
    "lines": [
        {
            "chapter": {"id": "modern", "title": c("Variante moderne — 4.Cf3", "Modern Variation — 4.Nf3")},
            "moves": [
                "e4",
                {"san": "Nf6", "eco": "Alekhine Defense",
                 "comment": c("Le cavalier attaque e4 dès le 1er coup et provoque l'avance des pions blancs.",
                              "The knight hits e4 on move one and provokes White's pawns forward.")},
                "e5", "Nd5", "d4", "d6",
                {"san": "Nf3", "eco": "Alekhine Defense: Modern Variation",
                 "comment": c("La ligne moderne, saine : les Blancs se contentent d'un centre raisonnable.",
                              "The sound modern line: White settles for a reasonable centre.")},
                "dxe5", "Nxe5", "g6",
            ],
        },
        {
            "chapter": {"id": "four-pawns", "title": c("Attaque des Quatre Pions", "Four Pawns Attack")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "d4", "d6",
                {"san": "c4", "comment": c("Les Blancs prennent tout l'espace…",
                                           "White grabs all the space…")},
                "Nb6",
                {"san": "f4", "eco": "Alekhine Defense: Four Pawns Attack",
                 "comment": c("L'Attaque des Quatre Pions : impressionnante, mais ces pions deviennent des cibles après …dxe5 et …c5.",
                              "The Four Pawns Attack: impressive, but those pawns become targets after …dxe5 and …c5.")},
                "dxe5", "fxe5", "Nc6",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "d4", "d6", "c4", "Nb6",
                {"san": "exd6", "eco": "Alekhine Defense: Exchange Variation",
                 "comment": c("L'échange : jeu tranquille où les Noirs finissent bien développés, sans faiblesse.",
                              "The exchange: quiet play where Black ends up well developed and solid.")},
                "cxd6", "Nc3", "g6",
            ],
        },
    ],
}
