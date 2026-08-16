# -*- coding: utf-8 -*-
"""Partie viennoise (1.e4 e5 2.Cc3) + gambit viennois — répertoire BLANC.

Approfondie : gambit viennois, Frankenstein-Dracula (3.Fc4 Cxe4), 2…Cc6 3.f4.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "vienna-game",
    "name": "Vienna Game",
    "side": "white",
    "level": "club",
    "eco": ["C25", "C29"],
    "summary": c(
        "Une cousine agressive de l'italienne : 2.Cc3 prépare f4. Peu jouée, donc redoutable en club — et truffée de pièges, jusqu'au fou Frankenstein-Dracula.",
        "An aggressive cousin of the Italian: 2.Nc3 prepares f4. Rarely played, so dangerous at club level — and full of traps, right up to the Frankenstein-Dracula.",
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
                "fxe5", "Nxe4", "Nf3", "Be7", "d4", "O-O", "Bd3", "f5", "exf6", "Bxf6",
            ],
        },
        {
            "chapter": {"id": "frankenstein", "title": c("Frankenstein-Dracula — 3.Fc4 Cxe4", "Frankenstein-Dracula — 3.Bc4 Nxe4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6",
                {"san": "Bc4", "comment": c("Le développement tranquille… qui tend un piège si les Noirs sont gourmands.",
                                            "Quiet development… that lays a trap if Black gets greedy.")},
                {"san": "Nxe4", "role": "inaccuracy", "critical": True,
                 "comment": c("Prendre e4 lance la mêlée Frankenstein-Dracula : des complications monstrueuses attendent.",
                              "Grabbing e4 unleashes the Frankenstein-Dracula: monstrous complications await.")},
                {"san": "Qh5", "role": "refutation", "critical": True,
                 "comment": c("La dame attaque le cavalier e4 ET menace mat en f7.",
                              "The queen hits the e4 knight AND threatens mate on f7.")},
                "Nd6", "Bb3", "Nc6", "Nb5", "g6", "Qf3", "f5", "Qd5", "Qe7", "Nxc7+", "Kd8", "Nxa8", "b6",
            ],
        },
        {
            "chapter": {"id": "2nc6", "title": c("2…Cc6 3.f4", "2…Nc6 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nc6",
                {"san": "f4", "comment": c("Même idée : on attaque e5 et on ouvre la colonne f.",
                                           "Same idea: hit e5 and open the f-file.")},
                "exf4", "Nf3", "g5", "d4", "g4", "Bxf4", "gxf3", "Qxf3",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois — 3.f4", "Vienna Gambit — 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "f4",
                {"san": "exf4",
                 "comment": c("Accepter est le coup principal — près de quatre Noirs sur dix — et le chapitre partait de …d5.",
                              "Accepting is the main move — nearly four Black players in ten — and the chapter started from …d5."),
                 "critical": True},
                {"san": "e5",
                 "comment": c("Le coup qui donne son sens au gambit : le pion chasse le cavalier avant qu'il ne s'installe, et la colonne f s'ouvrira pour notre tour.",
                              "The move that justifies the gambit: the pawn kicks the knight before it settles, and the f-file will open for our rook."),
                 "critical": True},
                "Ng8", "Nf3", "d6", "d4", "dxe5", "Bb5+",
            ],
        },
        {
            "chapter": {"id": "vs-d6", "title": c("2…d6 — l'installation Philidor", "2…d6 — the Philidor setup")},
            "moves": [
                "e4", "e5", "Nc3",
                {"san": "d6",
                 "comment": c("Les Noirs bâtissent une Philidor. On peut immédiatement liquider au centre et gagner l'échange de dames dans de bonnes conditions.",
                              "Black builds a Philidor. We can liquidate in the centre at once and trade queens on favourable terms.")},
                "d4", "Nf6", "dxe5", "dxe5",
                {"san": "Qxd8+",
                 "comment": c("On échange volontairement les dames : le roi noir perd le roque, et une finale légèrement meilleure vaut mieux qu'une attaque imaginaire.",
                              "We deliberately trade queens: Black's king loses castling rights, and a slightly better endgame beats an imaginary attack."),
                 "critical": True},
                "Kxd8", "Nf3", "Bd6",
            ],
        },
    ],
}
