# -*- coding: utf-8 -*-
"""Ouverture Ponziani (1.e4 e5 2.Cf3 Cc6 3.c3) — répertoire BLANC.

Une des plus vieilles ouvertures : c3 prépare d4 pour un grand centre. Peu
jouée, donc piégeuse. Arbre : 3…Cf6 et 3…d5. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "ponziani",
    "name": "Ponziani Opening",
    "side": "white",
    "level": "club",
    "eco": ["C44"],
    "summary": c(
        "Une antiquité pleine de venin : 3.c3 prépare d4 pour bâtir un grand centre. Rare, donc désarçonnante ; les deux réponses saines (…Cf6 et …d5) demandent de la précision.",
        "A venomous antique: 3.c3 prepares d4 to build a big centre. Rare, so disorienting; the two sound replies (…Nf6 and …d5) both require precision.",
    ),
    "lines": [
        # 1) 3…Cf6
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6", "3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "c3", "eco": "Ponziani Opening",
                 "comment": c("Le coup Ponziani : c3 soutient d4, on vise un centre e4+d4 imposant.",
                              "The Ponziani move: c3 supports d4, aiming for an imposing e4+d4 centre.")},
                {"san": "Nf6", "comment": c("La réponse active : on attaque e4 pendant que le cavalier b1 n'est pas encore sorti.",
                                            "The active reply: hit e4 while White's b1-knight isn't out yet.")},
                "d4", "Nxe4", "d5", "Ne7", "Nxe5", "Ng6", "Nxg6", "hxg6",
            ],
        },
        # 2) 3…d5
        {
            "chapter": {"id": "d5", "title": c("3…d5", "3…d5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "d5", "comment": c("La réponse centrale : on frappe e4 tout de suite pour désamorcer le plan d4.",
                                           "The central reply: hit e4 at once to defuse the d4 plan.")},
                "Qa4", "f6", "Bb5", "Ne7", "exd5", "Qxd5", "d4", "e4",
            ],
        },
    ],
}
