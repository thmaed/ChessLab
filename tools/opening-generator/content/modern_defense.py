# -*- coding: utf-8 -*-
"""Défense moderne (1.e4 g6 2.d4 Fg7) — répertoire NOIR.

Arbre : Modern de Tiger (…a6 …b5), Autrichienne (f4), système Gurgenidze
(…c6 …d5). Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-nf3", "title": c("2.Cf3 — sans d4", "2.Nf3 — without d4")},
            "moves": [
                "e4", "g6",
                {"san": "Nf3",
                 "comment": c("Plus d'un quart des parties, et le cours partait de 2.d4. Les Blancs gardent le centre souple pour éviter notre contre-attaque.",
                              "Over a quarter of games, and the course started from 2.d4. White keeps the centre flexible to dodge our counterattack."),
                 "critical": True},
                {"san": "c5", "critical": True,
                 "comment": c("On frappe avant qu'ils n'installent d4 : c'est une Sicilienne avec le fianchetto déjà décidé, terrain favorable pour nous.",
                              "We strike before they establish d4: it becomes a Sicilian with the fianchetto already decided — favourable ground for us.")},
                "d4", "cxd4", "Qxd4", "Nf6", "e5", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-nf3-late", "title": c("3.Cf3 — le développement lent", "3.Nf3 — slow development")},
            "moves": [
                "e4", "g6", "d4", "Bg7",
                {"san": "Nf3",
                 "comment": c("Près de quatre parties sur dix ici, et le chapitre continuait autrement. Sans Cc3, les Blancs renoncent à l'attaque directe.",
                              "Nearly four games in ten here, and the chapter went elsewhere. Without Nc3, White gives up on the direct attack.")},
                "d6", "Nc3", "Nf6", "Bg5", "h6", "Bf4",
                {"san": "c5",
                 "comment": c("La rupture au bon moment : le fou f4 ne défend plus d4 et la colonne c s'ouvre pour nous.",
                              "The break at the right moment: the f4 bishop no longer guards d4 and the c-file opens for us.")},
            ],
        },
    ],
}
