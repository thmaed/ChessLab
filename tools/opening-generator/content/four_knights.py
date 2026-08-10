# -*- coding: utf-8 -*-
"""Partie des Quatre Cavaliers (1.e4 e5 2.Cf3 Cc6 3.Cc3 Cf6) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "four-knights",
    "name": "Four Knights Game",
    "side": "white",
    "level": "club",
    "eco": ["C46", "C49"],
    "summary": c(
        "Développement symétrique, réputé tranquille mais loin d'être inoffensif : la variante espagnole et l'écossaise des Quatre Cavaliers gardent du mordant.",
        "Symmetrical development, reputedly quiet but far from harmless: the Spanish and Scotch Four Knights keep real bite.",
    ),
    "lines": [
        {
            "chapter": {"id": "spanish", "title": c("Variante espagnole — 4.Fb5", "Spanish — 4.Bb5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "Bb5", "eco": "Four Knights Game: Spanish Variation",
                 "comment": c("Le clouage à la mode espagnole : jeu sain, on presse c6 et e5.",
                              "The Spanish-style pin: sound play, pressing c6 and e5.")},
                "Bb4", "O-O", "O-O", "d3", "d6", "Bg5",
            ],
        },
        {
            "chapter": {"id": "scotch", "title": c("Écossaise des Quatre Cavaliers — 4.d4", "Scotch Four Knights — 4.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "d4", "comment": c("On ouvre le centre : jeu plus dynamique que la variante espagnole.",
                                           "Open the centre: more dynamic than the Spanish line.")},
                "exd4", "Nxd4", "Bb4", "Nxc6", "bxc6", "Bd3", "d5",
            ],
        },
    ],
}
