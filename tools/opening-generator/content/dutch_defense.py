# -*- coding: utf-8 -*-
"""Défense hollandaise (1.d4 f5) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "dutch-defense",
    "name": "Dutch Defense",
    "side": "black",
    "level": "club",
    "eco": ["A80", "A99"],
    "summary": c(
        "Dès 1…f5, les Noirs jouent pour l'attaque : contrôle de e4 et assaut à l'aile roi. Trois systèmes au choix : Leningrad, Stonewall, classique.",
        "With 1…f5 Black plays for the attack: control of e4 and a kingside assault. Three systems to choose from: Leningrad, Stonewall, Classical.",
    ),
    "lines": [
        {
            "chapter": {"id": "leningrad", "title": c("Système Leningrad", "Leningrad System")},
            "moves": [
                "d4",
                {"san": "f5", "eco": "Dutch Defense",
                 "comment": c("La Hollandaise : on prend le contrôle de e4 dès le 1er coup.",
                              "The Dutch: grabbing control of e4 from move one.")},
                "g3", "Nf6", "Bg2",
                {"san": "g6", "comment": c("Le set-up Leningrad : fou en g7, structure à la est-indienne, jeu dynamique.",
                                           "The Leningrad setup: bishop to g7, a King's-Indian structure, dynamic play.")},
                "Nf3", "Bg7", "O-O", "O-O", "c4", "d6",
            ],
        },
        {
            "chapter": {"id": "stonewall", "title": c("Stonewall", "Stonewall")},
            "moves": [
                "d4", "f5", "g3", "Nf6", "Bg2", "e6", "Nf3",
                {"san": "d5", "eco": "Dutch Defense: Stonewall Variation",
                 "comment": c("Le Stonewall : pions d5-e6-f5, un mur qui verrouille e4 et prépare une attaque sur h/g.",
                              "The Stonewall: d5-e6-f5 pawns, a wall that locks e4 and prepares a kingside attack.")},
                "O-O", "Bd6", "c4", "c6",
            ],
        },
        {
            "chapter": {"id": "classical", "title": c("Classique — …e6 …Fe7", "Classical — …e6 …Be7")},
            "moves": [
                "d4", "f5", "g3", "Nf6", "Bg2", "e6", "Nf3", "Be7", "O-O", "O-O", "c4", "d6",
            ],
        },
        {
            "chapter": {"id": "anti-dutch", "title": c("Anti-hollandaise — 2.Fg5", "Anti-Dutch — 2.Bg5")},
            "moves": [
                "d4", "f5",
                {"san": "Bg5", "comment": c("Une tentative de déranger : le fou cloue et gêne …Cf6. …g6 ou …h6 gardent la maison.",
                                            "A try to annoy: the bishop pins and hinders …Nf6. …g6 or …h6 keep things in order.")},
                "g6", "Nc3", "Bg7",
            ],
        },
    ],
}
