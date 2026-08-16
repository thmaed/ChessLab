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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-c4", "title": c("2.c4 — la ligne principale", "2.c4 — the main line")},
            "moves": [
                "d4", "f5",
                {"san": "c4",
                 "comment": c("Le deuxième coup le plus joué au monde contre la Hollandaise, et le cours ne le traitait pas. Sans réponse ici, le répertoire tombe une partie sur trois.",
                              "The most played second move against the Dutch, and the course didn't cover it. With no answer here, the repertoire fails in one game out of three."),
                 "critical": True},
                "Nf6", "g3", "e6", "Bg2",
                {"san": "d5",
                 "comment": c("On choisit la Hollandaise « pierre-de-taille » : structure fermée, plan clair, et le fou g2 mord sur du granit.",
                              "We choose the Stonewall: a closed structure, a clear plan, and the g2 bishop bites on granite."),
                 "critical": True},
                "Nf3", "Be7", "Nc3",
            ],
        },
        {
            "chapter": {"id": "vs-bf4", "title": c("2.Ff4 — la London contre la Hollandaise", "2.Bf4 — the London vs the Dutch")},
            "moves": [
                "d4", "f5",
                {"san": "Bf4",
                 "comment": c("Une partie sur cinq : les Blancs sortent le fou avant e3 pour éviter de l'enfermer.",
                              "One game in five: White develops the bishop before e3 to avoid shutting it in.")},
                "e6", "e3", "Nf6", "Nf3",
                {"san": "b6",
                 "comment": c("Le fianchetto de dame est la bonne méthode ici : il surveille e4 et prépare …Fe7 puis le roque, sans rien affaiblir.",
                              "The queenside fianchetto is the right method here: it watches e4 and prepares …Be7 and castling, weakening nothing.")},
                "Be2", "Bb7", "c4",
            ],
        },
    ],
}
