# -*- coding: utf-8 -*-
"""Partie viennoise (1.e4 e5 2.Cc3) + gambit viennois — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "vienna-game",
    "name": "Vienna Game",
    "side": "white",
    "level": "club",
    "eco": ["C25", "C29"],
    "summary": c(
        "Une cousine agressive de l'italienne : 2.Cc3 prépare f4. Peu jouée, donc redoutable en club — et truffée de pièges.",
        "An aggressive cousin of the Italian: 2.Nc3 prepares f4. Rarely played, so dangerous at club level — and full of traps.",
    ),
    "lines": [
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois", "Vienna Gambit")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6",
                {"san": "f4", "eco": "Vienna Game: Vienna Gambit",
                 "comment": c("Le gambit viennois : on ouvre la colonne f pour une attaque directe sur le roi.",
                              "The Vienna Gambit: opening the f-file for a direct attack on the king.")},
                {"san": "d5", "comment": c("La bonne réaction : contre-attaquer au centre plutôt que prendre en f4.",
                                           "The right reaction: counterattack in the centre rather than take on f4.")},
                "fxe5", "Nxe4", "Nf3", "Be7", "d4", "O-O",
            ],
        },
        {
            "chapter": {"id": "trap", "title": c("Le piège 3.Fc4", "The 3.Bc4 trap")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "Bc4",
                {"san": "Nxe4", "role": "inaccuracy", "critical": True,
                 "comment": c("Le coup naturel… et fautif : prendre e4 tombe dans un piège bien connu.",
                              "The natural move… and the wrong one: grabbing e4 walks into a well-known trap.")},
                {"san": "Qh5", "role": "refutation", "critical": True,
                 "comment": c("La réfutation : la dame attaque le cavalier e4 ET menace mat en f7. Les Noirs sont déjà en grande difficulté.",
                              "The refutation: the queen hits the e4 knight AND threatens mate on f7. Black is already in deep trouble.")},
                "Nd6", "Bb3", "Nc6", "Nb5",
            ],
        },
        {
            "chapter": {"id": "2nc6", "title": c("2…Cc6 3.f4", "2…Nc6 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nc6",
                {"san": "f4", "comment": c("Même idée : on attaque e5 et on ouvre la colonne f.",
                                           "Same idea: hit e5 and open the f-file.")},
                "exf4", "Nf3", "g5",
            ],
        },
    ],
}
