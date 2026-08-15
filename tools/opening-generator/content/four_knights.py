# -*- coding: utf-8 -*-
"""Partie des Quatre Cavaliers (1.e4 e5 2.Cf3 Cc6 3.Cc3 Cf6) — répertoire BLANC.

Arbre : espagnole des Quatre Cavaliers (4.Fb5, dégommage Metger), écossaise
des Quatre Cavaliers (4.d4), gambit Halloween (4.Cxe5). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "four-knights",
    "name": "Four Knights Game",
    "side": "white",
    "level": "club",
    "eco": ["C46", "C49"],
    "summary": c(
        "Développement symétrique et sain : les quatre cavaliers sortent, puis on choisit entre le calme espagnol (Fb5), l'ouverture du centre (écossaise) ou le chaos (Halloween).",
        "Sound symmetrical development: all four knights come out, then choose between the quiet Spanish (Bb5), opening the centre (Scotch) or chaos (Halloween).",
    ),
    "lines": [
        {
            "chapter": {"id": "spanish", "title": c("Espagnole — 4.Fb5", "Spanish — 4.Bb5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "Bb5", "eco": "Four Knights Game: Spanish Variation",
                 "comment": c("La version espagnole : symétrie parfaite. Les Blancs jouent la structure et le dégommage Metger.",
                              "The Spanish version: perfect symmetry. White plays the structure and the Metger unpin.")},
                "Bb4", "O-O", "O-O", "d3", "d6", "Bg5", "Bxc3", "bxc3", "Qe7", "Re1", "Nd8", "d4", "Ne6",
            ],
        },
        {
            "chapter": {"id": "scotch", "title": c("Écossaise — 4.d4", "Scotch — 4.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "d4", "comment": c("On ouvre le centre : jeu ouvert et actif où les Blancs gardent une petite initiative.",
                                           "Opening the centre: open, active play where White keeps a slight initiative.")},
                "exd4", "Nxd4", "Bb4", "Nxc6", "bxc6", "Bd3", "d5", "exd5", "cxd5", "O-O", "O-O", "Bg5", "c6",
            ],
        },
        {
            "chapter": {"id": "halloween", "title": c("Gambit Halloween — 4.Cxe5", "Halloween Gambit — 4.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "Nxe5", "comment": c("Le gambit Halloween : on sacrifie un cavalier pour chasser les pièces noires et prendre un centre monstrueux.",
                                             "The Halloween Gambit: sacrifice a knight to chase Black's pieces and grab a monster centre.")},
                "Nxe5", "d4", "Nc6", "d5", "Ne5", "f4", "Ng6", "e5", "Ng8", "d6",
            ],
        },
    ],
}
