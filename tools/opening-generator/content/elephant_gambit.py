# -*- coding: utf-8 -*-
"""Gambit de l'éléphant (1.e4 e5 2.Cf3 d5) — NOIR.

Un gambit rare et provocant : …d5 d'entrée pour ouvrir le jeu. Douteux au fond
mais désarçonnant. Arbre : 3.exd5 Fd6 et 3.exd5 e4. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "elephant-gambit",
    "name": "Elephant Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C40"],
    "summary": c(
        "Un contre-gambit rare et piégeur : au lieu de défendre e5, on frappe par …d5. Objectivement douteux, mais peu d'adversaires connaissent la bonne réfutation.",
        "A rare, tricky countergambit: instead of defending e5, strike with …d5. Objectively dubious, but few opponents know the correct refutation.",
    ),
    "lines": [
        # 1) 3.exd5 Fd6
        {
            "chapter": {"id": "bd6", "title": c("3.exd5 Fd6", "3.exd5 Bd6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d5", "eco": "Elephant Gambit",
                 "comment": c("Le gambit de l'éléphant : on offre le centre pour un développement rapide et des complications.",
                              "The Elephant Gambit: offer the centre for fast development and complications.")},
                "exd5",
                {"san": "Bd6", "comment": c("On garde e5 fort et on développe agressivement, prêt à …e4 pour chasser le cavalier.",
                                            "Keep e5 strong and develop aggressively, ready for …e4 to chase the knight.")},
                "d4", "e4", "Ne5", "Nf6", "Bc4", "O-O", "Nc3", "Nbd7",
            ],
        },
        # 2) 3.exd5 e4
        {
            "chapter": {"id": "e4", "title": c("3.exd5 e4", "3.exd5 e4")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5",
                {"san": "e4", "comment": c("On chasse le cavalier f3 tout de suite ; il faudra récupérer d5 précisément.",
                                           "Kick the f3-knight at once; d5 must then be regained accurately.")},
                "Qe2", "Nf6", "Nc3", "Be7", "Nxe4", "Nxe4", "Qxe4", "O-O",
            ],
        },
    ],
}
