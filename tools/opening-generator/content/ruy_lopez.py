# -*- coding: utf-8 -*-
"""Partie espagnole / Ruy Lopez (1.e4 e5 2.Cf3 Cc6 3.Fb5) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "ruy-lopez",
    "name": "Ruy Lopez",
    "side": "white",
    "level": "advanced",
    "eco": ["C60", "C99"],
    "summary": c(
        "L'ouverture la plus profonde du répertoire 1.e4 : le fou b5 met une pression durable sur c6 et e5. Pression positionnelle patiente, riche en plans.",
        "The deepest opening in the 1.e4 repertoire: the b5 bishop puts lasting pressure on c6 and e5. Patient positional pressure, rich in plans.",
    ),
    "lines": [
        # Principale fermée (défense Morphy)
        {
            "chapter": {"id": "closed", "title": c("Espagnole fermée", "Closed Ruy Lopez")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "Bb5", "comment": c("Le coup espagnol : on cloue indirectement c6, défenseur de e5.",
                                            "The Spanish move: indirectly pinning c6, the defender of e5.")},
                {"san": "a6", "eco": "Ruy Lopez: Morphy Defense",
                 "comment": c("La défense Morphy : les Noirs posent la question au fou.",
                              "The Morphy Defence: Black puts the question to the bishop.")},
                {"san": "Ba4", "comment": c("On garde le fou et la pression : reculer sans lâcher la diagonale.",
                                            "Keep the bishop and the pressure: retreat without giving up the diagonal.")},
                "Nf6", "O-O", "Be7", "Re1",
                {"san": "b5", "comment": c("Les Noirs chassent enfin le fou avant …d6.",
                                           "Black finally kicks the bishop before …d6.")},
                "Bb3", "d6",
                {"san": "c3", "comment": c("La clé de voûte : c3 prépare d4 et donne une case de repli au fou en c2.",
                                           "The keystone: c3 prepares d4 and gives the bishop a retreat to c2.")},
                "O-O",
            ],
        },
        # Variante d'échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
                {"san": "Bxc6", "eco": "Ruy Lopez: Exchange Variation",
                 "comment": c("On échange en c6 : les Noirs récupèrent la paire de fous mais héritent de pions doublés. But blanc : la finale.",
                              "Trading on c6: Black gets the bishop pair but inherits doubled pawns. White's aim: the endgame.")},
                "dxc6",
                {"san": "O-O", "comment": c("Le plan est simple et sain : d4/exd5 puis pression sur la structure noire.",
                                            "The plan is simple and sound: d4, then pressure on Black's structure.")},
            ],
        },
        # Défense berlinoise
        {
            "chapter": {"id": "berlin", "title": c("Défense berlinoise", "Berlin Defense")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5",
                {"san": "Nf6", "eco": "Ruy Lopez: Berlin Defense",
                 "comment": c("La Berlinoise, réputation de forteresse : les Noirs visent une finale sûre.",
                              "The Berlin, famed as a fortress: Black heads for a safe endgame.")},
                "O-O", "Nxe4", "d4", "Nd6", "Bxc6", "dxc6", "dxe5", "Nf5", "Qxd8+", "Kxd8",
                {"san": "Nc3", "comment": c("La fameuse finale berlinoise : sans dames, les Blancs jouent la structure et l'espace.",
                                            "The famous Berlin endgame: queens off, White plays structure and space.")},
            ],
        },
    ],
}
