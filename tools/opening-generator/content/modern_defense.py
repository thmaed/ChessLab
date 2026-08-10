# -*- coding: utf-8 -*-
"""Défense moderne (1.e4 g6) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "modern-defense",
    "name": "Modern Defense",
    "side": "black",
    "level": "club",
    "eco": ["B06"],
    "summary": c(
        "Cousine du Pirc, en plus flexible : on fianchette d'abord et on retarde …Cf6 pour garder toutes les options (…c6/…b5 ou …c5). Hypermoderne et fuyante.",
        "A cousin of the Pirc, more flexible: fianchetto first and delay …Nf6 to keep every option (…c6/…b5 or …c5). Hypermodern and slippery.",
    ),
    "lines": [
        {
            "chapter": {"id": "tigers", "title": c("Moderne de Tiger — …a6 …b5", "Tiger's Modern — …a6 …b5")},
            "moves": [
                "e4", "g6", "d4", "Bg7", "Nc3", "d6",
                {"san": "Be3", "comment": c("Les Blancs préparent Dd2 et Fh6. Les Noirs ripostent à l'aile dame.",
                                            "White prepares Qd2 and Bh6. Black hits back on the queenside.")},
                {"san": "a6", "eco": "Modern Defense",
                 "comment": c("Le plan de Tiger Hillarp Persson : …a6 et …b5 pour un contre-jeu rapide sans …Cf6.",
                              "Tiger Hillarp Persson's plan: …a6 and …b5 for quick counterplay without …Nf6.")},
                "Qd2", "b5", "f3", "Nd7",
            ],
        },
        {
            "chapter": {"id": "austrian", "title": c("Attaque autrichienne — 4.f4", "Austrian Attack — 4.f4")},
            "moves": [
                "e4", "g6", "d4", "Bg7", "Nc3", "d6",
                {"san": "f4", "comment": c("Le centre massif ; la moderne transpose souvent vers un Pirc après …Cf6.",
                                           "The big centre; the Modern often transposes to a Pirc after …Nf6.")},
                "Nf6", "Nf3", "O-O", "Bd3", "Na6",
            ],
        },
    ],
}
