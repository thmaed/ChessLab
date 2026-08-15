# -*- coding: utf-8 -*-
"""Gambit Blackmar-Diemer (1.d4 d5 2.e4 dxe4 3.Cc3 Cf6 4.f3) — répertoire BLANC.

Arbre : Bogoljubow (4…exf3 5…g6), Teichmann (5…Ff5), gambit Ryder (5.Dxf3).
Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "blackmar-diemer",
    "name": "Blackmar-Diemer Gambit",
    "side": "white",
    "level": "club",
    "eco": ["D00"],
    "summary": c(
        "Un pion pour une attaque immédiate : colonne f ouverte, développement rapide et un roque adverse dans le viseur. L'arme du joueur d'attaque contre 1…d5.",
        "A pawn for instant attack: an open f-file, fast development and the enemy king in the crosshairs. The attacker's weapon against 1…d5.",
    ),
    "lines": [
        {
            "chapter": {"id": "bogoljubow", "title": c("Bogoljubow — 5…g6", "Bogoljubow — 5…g6")},
            "moves": [
                "d4", "d5", "e4",
                {"san": "dxe4", "eco": "Blackmar-Diemer Gambit",
                 "comment": c("Les Noirs acceptent ; les Blancs vont reprendre l'initiative par f3.",
                              "Black accepts; White will grab the initiative back with f3.")},
                "Nc3", "Nf6", "f3", "exf3", "Nxf3", "g6", "Bc4", "Bg7", "O-O", "O-O",
                {"san": "Qe1", "comment": c("La manœuvre-clé : la dame file en h4 pour attaquer le roque avec Fh6 et Ce5.",
                                            "The key manoeuvre: the queen swings to h4 to attack the king with Bh6 and Ne5.")},
                "Nc6", "Qh4", "Bg4", "Be3",
                {"san": "e6",
                 "comment": c("Les Noirs bouchent d5 et tiennent. À ce stade le pion ne revient pas : le gambit se joue pour l'initiative, pas pour l'égalité matérielle.",
                              "Black plugs d5 and holds. The pawn does not come back here: the gambit is played for the initiative, not to be materially level.")},
                "Ne5", "Bf5", "Nxc6", "bxc6",
            ],
        },
        {
            "chapter": {"id": "teichmann", "title": c("Teichmann — 5…Ff5", "Teichmann — 5…Bf5")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3", "Nxf3",
                {"san": "Bf5", "comment": c("Les Noirs développent le fou avant …e6. Les Blancs le chassent par Ce5 et g4.",
                                            "Black develops the bishop before …e6. White chases it with Ne5 and g4.")},
                "Ne5", "e6", "g4", "Bg6", "h4", "h6", "Nxg6", "fxg6",
            ],
        },
        {
            "chapter": {"id": "ryder", "title": c("Gambit Ryder — 5.Dxf3", "Ryder Gambit — 5.Qxf3")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3",
                {"san": "Qxf3", "comment": c("Le gambit Ryder : on offre un SECOND pion (d4) pour une attaque encore plus violente.",
                                             "The Ryder Gambit: offer a SECOND pawn (d4) for an even more violent attack.")},
                "Qxd4", "Be3", "Qg4", "Qf2", "e5", "h3", "Qb4",
            ],
        },
    ],
}
