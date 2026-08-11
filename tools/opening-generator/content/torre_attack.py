# -*- coding: utf-8 -*-
"""Attaque Torre (1.d4 Cf6 2.Cf3 e6/g6 3.Fg5) — répertoire BLANC.

Un système facile et sain : Fg5, e3, Cbd2, c3, Fd3 — peu de théorie, un clouage
gênant sur f6. Arbre : contre …e6 (…c5), contre …g6, et la prise Fxf6. Vérifié.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "torre-attack",
    "name": "Torre Attack",
    "side": "white",
    "level": "club",
    "eco": ["A46", "D03"],
    "summary": c(
        "Un système d'attaque tranquille : Fg5 cloue f6, puis e3, Cbd2, c3, Fd3 et une attaque à l'aile roi. Peu de théorie, des plans clairs contre presque tout.",
        "A quiet attacking system: Bg5 pins f6, then e3, Nbd2, c3, Bd3 and a kingside attack. Little theory, clear plans against almost everything.",
    ),
    "lines": [
        # 1) Contre …e6 (…c5)
        {
            "chapter": {"id": "vs-e6", "title": c("Contre …e6", "vs …e6")},
            "moves": [
                "d4", "Nf6", "Nf3", "e6",
                {"san": "Bg5", "eco": "Torre Attack",
                 "comment": c("Le coup Torre : le fou cloue f6 avant e3, jamais enfermé (contrairement au Colle).",
                              "The Torre move: the bishop pins f6 before e3, never shut in (unlike the Colle).")},
                "c5", "e3", "cxd4", "exd4", "Be7", "Nbd2", "d6", "c3", "Nbd7", "Bd3", "b6", "O-O", "Bb7",
            ],
        },
        # 2) Contre …g6
        {
            "chapter": {"id": "vs-g6", "title": c("Contre …g6", "vs …g6")},
            "moves": [
                "d4", "Nf6", "Nf3", "g6",
                {"san": "Bg5", "comment": c("Contre le fianchetto aussi, Fg5 gêne …Cf6 et prépare Cbd2, e3, Fe2.",
                                            "Against the fianchetto too, Bg5 pesters …Nf6 and prepares Nbd2, e3, Be2.")},
                "Bg7", "Nbd2", "d6", "e3", "O-O", "Be2", "Nbd7", "O-O", "h6", "Bh4", "e5",
            ],
        },
        # 3) La prise Fxf6 (contre …h6)
        {
            "chapter": {"id": "bxf6", "title": c("La prise Fxf6", "The Bxf6 capture")},
            "moves": [
                "d4", "Nf6", "Nf3", "e6", "Bg5", "h6",
                {"san": "Bxf6", "comment": c("On échange en f6 : la paire de fous contre un léger affaiblissement de la structure noire et un centre e4 à venir.",
                                             "Trade on f6: the bishop pair versus a slight weakening of Black's structure and a coming e4 centre.")},
                "Qxf6", "e4", "d6", "Nc3", "g6", "Qd2", "Bg7", "O-O-O", "Nd7",
            ],
        },
    ],
}
