# -*- coding: utf-8 -*-
"""Défense moderne (1.e4 g6 2.d4 Fg7) — répertoire NOIR.

Arbre : Modern de Tiger (…a6 …b5), Autrichienne (f4), système Gurgenidze
(…c6 …d5). Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "modern-defense",
    "name": "Modern Defense",
    "side": "black",
    "level": "club",
    "eco": ["B06"],
    "summary": c(
        "Encore plus souple que la Pirc : on fianchette sans …Cf6 pour garder toutes les options. On laisse le centre puis on frappe par …c5, …b5 ou …e5.",
        "Even more flexible than the Pirc: fianchetto without …Nf6 to keep every option. Give up the centre, then hit with …c5, …b5 or …e5.",
    ),
    "lines": [
        {
            "chapter": {"id": "tigers", "title": c("Modern de Tiger — …a6 …b5", "Tiger's Modern — …a6 …b5")},
            "moves": [
                "e4", "g6", "d4", "Bg7", "Nc3", "d6", "Be3", "a6",
                {"san": "Qd2", "comment": c("Les Blancs visent Fh6 et 0-0-0 ; les Noirs ripostent vite à l'aile dame par …b5.",
                                            "White aims for Bh6 and 0-0-0; Black counters fast on the queenside with …b5.")},
                "b5", "f3", "Nd7", "O-O-O", "Bb7", "h4", "h5",
            ],
        },
        {
            "chapter": {"id": "austrian", "title": c("Autrichienne — 4.f4", "Austrian — 4.f4")},
            "moves": [
                "e4", "g6", "d4", "Bg7", "Nc3", "d6",
                {"san": "f4", "comment": c("Le centre massif ; les Noirs le harcèlent par …Cf6, …Ca6-c7 et …c5.",
                                           "The big centre; Black harasses it with …Nf6, …Na6-c7 and …c5.")},
                "Nf6", "Nf3", "O-O", "Bd3", "Na6", "O-O", "c5", "d5", "Bg4",
            ],
        },
        {
            "chapter": {"id": "gurgenidze", "title": c("Système Gurgenidze — …c6 …d5", "Gurgenidze System — …c6 …d5")},
            "moves": [
                "e4", "g6", "d4", "Bg7", "Nc3", "c6",
                {"san": "f4", "comment": c("Contre f4, le Gurgenidze frappe par …d5 : on ferme le centre et on cible e5/f4.",
                                           "Against f4, the Gurgenidze hits …d5: close the centre and target e5/f4.")},
                "d5", "e5", "h5", "Nf3", "Bg4",
            ],
        },
    ],
}
