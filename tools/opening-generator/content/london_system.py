# -*- coding: utf-8 -*-
"""Système Londres (1.d4 + Ff4) + Jobava Londres — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "london-system",
    "name": "London System",
    "side": "white",
    "level": "club",
    "eco": ["D02", "A48"],
    "summary": c(
        "Un système facile à jouer contre presque tout : Ff4, e3, Fd3, c3, Cbd2. Peu de théorie, des plans solides et une attaque à l'aile roi souvent au menu.",
        "An easy system against almost everything: Bf4, e3, Bd3, c3, Nbd2. Little theory, solid plans and a kingside attack often on the menu.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Londres contre …d5", "London vs …d5")},
            "moves": [
                "d4", "d5",
                {"san": "Bf4", "eco": "London System",
                 "comment": c("Le coup-signature : le fou sort AVANT e3, jamais enfermé.",
                              "The signature move: the bishop develops BEFORE e3, never shut in.")},
                "Nf6", "e3", "e6", "Nf3", "c5", "c3", "Nc6",
                {"san": "Nbd2", "comment": c("La formation type est complète ; suivra Fd3, puis Ce5 et une attaque.",
                                             "The standard formation is complete; Bd3 follows, then Ne5 and an attack.")},
                "Bd6", "Bg3",
            ],
        },
        {
            "chapter": {"id": "jobava", "title": c("Jobava Londres — 2.Cc3", "Jobava London — 2.Nc3")},
            "moves": [
                "d4", "Nf6",
                {"san": "Nc3", "comment": c("La version Jobava, plus mordante : le cavalier sort avant, prêt à jouer e4 ou Cb5.",
                                            "The sharper Jobava version: the knight develops first, ready for e4 or Nb5.")},
                "d5", "Bf4", "a6", "e3", "e6",
            ],
        },
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto — …g6", "vs the fianchetto — …g6")},
            "moves": [
                "d4", "Nf6", "Bf4", "g6",
                {"san": "Nc3", "comment": c("Contre …g6, la Londres tient très bien : e3, h4-h5 est même possible.",
                                            "Against …g6 the London holds up well: e3, and even h4-h5 is on.")},
                "d5", "e3", "Bg7", "h4",
            ],
        },
    ],
}
