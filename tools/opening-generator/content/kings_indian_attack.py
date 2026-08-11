# -*- coding: utf-8 -*-
"""Attaque est-indienne / KIA (Cf3, g3, Fg2, 0-0, d3, e4) — répertoire BLANC.

Arbre : contre la Française (…e6/…d5), contre …d5, contre la Sicilienne (…c5).
Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-indian-attack",
    "name": "King's Indian Attack",
    "side": "white",
    "level": "club",
    "eco": ["A07", "A08"],
    "summary": c(
        "Un système à jouer contre tout ce qui commence par …e6 ou …d5 : Cf3, g3, Fg2, 0-0, d3, e4. On attaque à l'aile roi par e5, Cf1-h2-g4 et f4.",
        "A setup to play against anything starting …e6 or …d5: Nf3, g3, Bg2, 0-0, d3, e4. Attack on the kingside with e5, Nf1-h2-g4 and f4.",
    ),
    "lines": [
        {
            "chapter": {"id": "vs-french", "title": c("Contre la Française — …e6", "vs the French — …e6")},
            "moves": [
                "e4", "e6", "d3", "d5", "Nd2", "Nf6", "Ngf3", "c5", "g3", "Nc6", "Bg2", "Be7", "O-O", "O-O", "Re1",
                {"san": "b5", "comment": c("Chacun attaque sur son aile : les Noirs à gauche, les Blancs par e5 puis Cf1-h2-g4.",
                                           "Each side attacks on its wing: Black on the left, White with e5 then Nf1-h2-g4.")},
                "e5", "Nd7", "Nf1", "a5", "h4", "b4",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "Nf3", "d5", "g3", "Nf6", "Bg2", "e6", "O-O", "Be7", "d3", "O-O", "Nbd2", "c5", "e4", "Nc6", "Re1", "Qc7", "e5", "Nd7", "Nf1", "b5",
            ],
        },
        {
            "chapter": {"id": "vs-sicilian", "title": c("Contre la Sicilienne — …c5", "vs the Sicilian — …c5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d3", "g6", "g3", "Bg7", "Bg2", "e5", "O-O", "Nge7", "Nbd2", "O-O", "a3", "d6",
            ],
        },
    ],
}
