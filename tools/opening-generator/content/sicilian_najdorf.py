# -*- coding: utf-8 -*-
"""Sicilienne Najdorf (1.e4 c5 2.Cf3 d6 3.d4 cxd4 4.Cxd4 Cf6 5.Cc3 a6) — NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-najdorf",
    "name": "Sicilian Defense: Najdorf",
    "side": "black",
    "level": "advanced",
    "eco": ["B90", "B99"],
    "summary": c(
        "La sicilienne la plus prestigieuse : …a6 avant tout, pour préparer …e5 ou …e6 en gardant une flexibilité maximale. Théorie exigeante mais récompense énorme.",
        "The most prestigious Sicilian: …a6 first, to prepare …e5 or …e6 with maximum flexibility. Demanding theory, huge reward.",
    ),
    "lines": [
        {
            "chapter": {"id": "english-attack", "title": c("Attaque anglaise — 6.Fe3", "English Attack — 6.Be3")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "a6", "eco": "Sicilian Defense: Najdorf Variation",
                 "comment": c("Le coup Najdorf : discret mais capital, il contrôle b5 et prépare …e5/…e6.",
                              "The Najdorf move: quiet but crucial, it controls b5 and prepares …e5/…e6.")},
                {"san": "Be3", "comment": c("L'Attaque anglaise : les Blancs visent Dd2, 0-0-0 et une ruée de pions à l'aile roi.",
                                            "The English Attack: White aims for Qd2, 0-0-0 and a kingside pawn storm.")},
                {"san": "e5", "comment": c("On repousse le cavalier et on revendique le centre.",
                                           "Kick the knight and claim the centre.")},
                "Nb3", "Be6", "f3", "Be7",
            ],
        },
        {
            "chapter": {"id": "main-bg5", "title": c("Ligne principale — 6.Fg5", "Main Line — 6.Bg5")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "Bg5", "comment": c("La ligne principale historique : clouage sur f6, jeu très tranchant.",
                                            "The historical main line: pin on f6, extremely sharp play.")},
                {"san": "e6", "comment": c("On soutient f6 et on garde la structure souple.",
                                           "Support f6 and keep the structure flexible.")},
                "f4", "Be7", "Qf3", "Qc7",
            ],
        },
        {
            "chapter": {"id": "classical-be2", "title": c("Variante classique — 6.Fe2", "Classical — 6.Be2")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "Be2", "comment": c("Le développement calme : les Blancs roquent court et jouent positionnel.",
                                            "The quiet setup: White castles short and plays positionally.")},
                "e5", "Nb3", "Be7", "O-O", "O-O",
            ],
        },
    ],
}
