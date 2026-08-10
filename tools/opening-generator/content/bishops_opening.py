# -*- coding: utf-8 -*-
"""Ouverture du fou (1.e4 e5 2.Fc4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "bishops-opening",
    "name": "Bishop's Opening",
    "side": "white",
    "level": "club",
    "eco": ["C23", "C24"],
    "summary": c(
        "Le fou file en c4 dès le 2e coup, en évitant la défense russe. Souple : on transpose souvent vers une italienne ou une viennoise avec des idées d'attaque.",
        "The bishop hits c4 on move two, sidestepping the Petrov. Flexible: it often transposes to an Italian or Vienna with attacking ideas.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("2…Cf6 3.d3", "2…Nf6 3.d3")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4", "eco": "Bishop's Opening",
                 "comment": c("On développe le fou avant le cavalier — et on évite la Petroff.",
                              "Develop the bishop before the knight — and dodge the Petrov.")},
                "Nf6",
                {"san": "d3", "comment": c("Le set-up moderne : d3, Cf3, c3 et une attaque lente à la mode italienne.",
                                           "The modern setup: d3, Nf3, c3 and a slow Italian-style attack.")},
                "c6", "Nf3", "d5", "Bb3", "Bd6",
            ],
        },
        {
            "chapter": {"id": "bc5", "title": c("2…Fc5 3.c3", "2…Bc5 3.c3")},
            "moves": [
                "e4", "e5", "Bc4", "Bc5",
                {"san": "c3", "comment": c("On prépare d4 pour bâtir un centre : idées jumelles de l'italienne.",
                                           "Prepare d4 to build a centre: twin ideas to the Italian.")},
                "Nf6", "d4", "exd4", "cxd4", "Bb4+",
            ],
        },
    ],
}
