# -*- coding: utf-8 -*-
"""Défense hollandaise (1.d4 f5) — répertoire NOIR.

Arbre approfondi : Leningrad, Stonewall (moderne), Classique (Ilyin-Zhenevsky),
anti-hollandaise 2.Fg5, gambit Staunton 2.e4. Lignes passées à l'audit moteur (`audit.py`).
"""


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
        # 1) Système Leningrad
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
                "Nf3", "Bg7", "O-O", "O-O", "c4", "d6", "Nc3",
                {"san": "Qe8", "comment": c("La manœuvre-clé : la dame va en h5/g6 pour soutenir …e5 et l'attaque.",
                                            "The key manoeuvre: the queen heads to h5/g6 to back …e5 and the attack.")},
                "d5", "Na6", "Rb1", "Bd7",
            ],
        },
        # 2) Stonewall (moderne)
        {
            "chapter": {"id": "stonewall", "title": c("Stonewall", "Stonewall")},
            "moves": [
                "d4", "f5", "g3", "Nf6", "Bg2", "e6", "Nf3",
                {"san": "d5", "eco": "Dutch Defense: Stonewall Variation",
                 "comment": c("Le Stonewall : pions d5-e6-f5, un mur qui verrouille e4 et prépare une attaque sur h/g.",
                              "The Stonewall: d5-e6-f5 pawns, a wall that locks e4 and prepares a kingside attack.")},
                "O-O", "Bd6", "c4", "c6", "b3", "Qe7", "Bb2", "b6", "Ne5", "Bb7",
            ],
        },
        # 3) Classique — Ilyin-Zhenevsky
        {
            "chapter": {"id": "classical", "title": c("Classique — …e6 …Fe7", "Classical — …e6 …Be7")},
            "moves": [
                "d4", "f5", "g3", "Nf6", "Bg2", "e6", "Nf3", "Be7", "O-O", "O-O", "c4", "d6", "Nc3",
                {"san": "Qe8", "comment": c("Le plan Ilyin-Zhenevsky : …De8-g6/h5 et …e5 pour lancer l'attaque à l'aile roi.",
                                            "The Ilyin-Zhenevsky plan: …Qe8-g6/h5 and …e5 to launch the kingside attack.")},
                "Re1", "Qg6", "e4", "fxe4", "Nxe4", "Nxe4", "Rxe4", "Nc6",
            ],
        },
        # 4) Anti-hollandaise — 2.Fg5
        {
            "chapter": {"id": "anti-dutch", "title": c("Anti-hollandaise — 2.Fg5", "Anti-Dutch — 2.Bg5")},
            "moves": [
                "d4", "f5",
                {"san": "Bg5", "comment": c("Une tentative de déranger : le fou cloue et gêne …Cf6. …g6 garde la maison.",
                                            "A try to annoy: the bishop pins and hinders …Nf6. …g6 keeps things in order.")},
                "g6", "Nc3", "Bg7", "e4", "fxe4", "Nxe4", "d5", "Ng3", "Nf6",
            ],
        },
        # 5) Gambit Staunton — 2.e4
        {
            "chapter": {"id": "staunton", "title": c("Gambit Staunton — 2.e4", "Staunton Gambit — 2.e4")},
            "moves": [
                "d4", "f5",
                {"san": "e4", "comment": c("Le gambit Staunton : un pion pour un développement rapide. Rendre le pion et se développer neutralise tout.",
                                           "The Staunton Gambit: a pawn for fast development. Give the pawn back and develop to neutralise it.")},
                "fxe4", "Nc3", "Nf6", "Bg5", "g6", "f3", "exf3", "Nxf3", "Bg7", "Bd3", "d6",
            ],
        },
    ],
}
