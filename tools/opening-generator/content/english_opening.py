# -*- coding: utf-8 -*-
"""Anglaise (1.c4) — répertoire BLANC.

Arbre approfondi : Sicilienne inversée 1…e5 (dragon inversé), Symétrique 1…c5
(avec la rupture d4), et l'attaque Mikenas 2.Cc3 e6 3.e4. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "english-opening",
    "name": "English Opening",
    "side": "white",
    "level": "club",
    "eco": ["A10", "A39"],
    "summary": c(
        "Une ouverture de flanc hypermoderne : on contrôle d5 à distance et on garde une flexibilité totale. Souvent une sicilienne avec un temps de plus.",
        "A hypermodern flank opening: control d5 from afar and keep total flexibility. Often a Sicilian with an extra tempo.",
    ),
    "lines": [
        # 1) Sicilienne inversée — 1…e5
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                {"san": "c4", "eco": "English Opening",
                 "comment": c("On revendique d5 sans engager les pions centraux : jeu souple.",
                              "Claiming d5 without committing the central pawns: flexible play.")},
                {"san": "e5", "comment": c("Les Noirs prennent le centre : c'est une sicilienne à camps inversés, un temps en plus pour les Blancs.",
                                           "Black grabs the centre: it's a Sicilian with colours reversed, White a tempo up.")},
                "Nc3", "Nf6", "Nf3", "Nc6", "g3", "d5", "cxd5", "Nxd5", "Bg2",
                {"san": "Nb6", "comment": c("Le dragon inversé : les Blancs jouent la structure sicilienne avec un temps de plus.",
                                            "The reversed Dragon: White plays the Sicilian structure a tempo up.")},
                "O-O", "Be7", "d3", "O-O", "a3", "a5", "Be3", "Re8",
            ],
        },
        # 2) Variante symétrique — 1…c5
        {
            "chapter": {"id": "symmetrical", "title": c("Variante symétrique — 1…c5", "Symmetrical — 1…c5")},
            "moves": [
                "c4",
                {"san": "c5", "eco": "English Opening: Symmetrical Variation",
                 "comment": c("La symétrique : chacun campe sur ses positions. Les Blancs cherchent à rompre la symétrie au bon moment.",
                              "The Symmetrical: both sides mirror. White looks to break the symmetry at the right moment.")},
                "Nc3", "Nc6", "g3", "g6", "Bg2", "Bg7", "Nf3", "Nf6", "O-O", "O-O",
                {"san": "d4", "comment": c("Le bon moment pour rompre : d4 casse la symétrie et ouvre le fou g2.",
                                           "The right moment to break: d4 shatters the symmetry and opens the g2 bishop.")},
                "cxd4", "Nxd4", "Nxd4", "Qxd4", "d6", "Qd3", "a6",
            ],
        },
        # 3) Attaque Mikenas — 2.Cc3 e6 3.e4
        {
            "chapter": {"id": "mikenas", "title": c("Attaque Mikenas — 3.e4", "Mikenas Attack — 3.e4")},
            "moves": [
                "c4", "Nf6", "Nc3", "e6",
                {"san": "e4", "comment": c("L'attaque Mikenas : les Blancs prennent tout le centre. Le jeu devient concret d'emblée.",
                                           "The Mikenas Attack: White seizes the whole centre. Play turns concrete at once.")},
                {"san": "d5", "comment": c("La réponse la plus critique : on frappe e4 tout de suite.",
                                           "The most critical reply: hit e4 immediately.")},
                "e5", "d4", "exf6", "dxc3", "fxg7", "cxd2+", "Bxd2", "Bxg7",
            ],
        },
    ],
}
