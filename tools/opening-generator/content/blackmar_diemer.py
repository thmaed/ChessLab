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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "teichmann", "title": c("Défense Teichmann — 5…Fg4", "Teichmann Defence — 5…Bg4")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3", "Nxf3",
                {"san": "Bg4",
                 "comment": c("La défense la plus jouée contre le gambit — près d'une partie sur deux — et la seule que le cours ne traitait pas. Les Noirs clouent le cavalier qui garde d4.",
                              "The most played defence against the gambit — nearly one game in two — and the only one the course didn't cover. Black pins the knight guarding d4."),
                 "critical": True},
                {"san": "h3",
                 "comment": c("On pose la question tout de suite. Reculer en h5 laisse g4 gagner un temps de plus.",
                              "Ask the question immediately. Retreating to h5 lets g4 gain another tempo.")},
                "Bh5", "g4", "Bg6",
                {"san": "Ne5",
                 "comment": c("Le cavalier saute sur son avant-poste avec gain de temps : voilà la compensation du pion, en pièces actives et non en calculs.",
                              "The knight jumps to its outpost with tempo: there's the compensation for the pawn — active pieces, not calculations."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "ryder", "title": c("Gambit Ryder — 5.Dxf3", "Ryder Gambit — 5.Qxf3")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3",
                {"san": "Qxf3", "role": "trap",
                 "comment": c("Le gambit Ryder : on sacrifie un SECOND pion pour une attaque immédiate. Objectivement douteux, redoutable en pratique — et le cours n'en disait rien.",
                              "The Ryder Gambit: a SECOND pawn sacrificed for immediate attack. Objectively dubious, fearsome in practice — and the course said nothing about it."),
                 "critical": True},
                {"san": "e6",
                 "comment": c("La défense saine : les Noirs ferment la diagonale et rendent le matériel s'il le faut.",
                              "The sound defence: Black shuts the diagonal and gives material back if needed.")},
                "Bf4", "Nc6", "O-O-O",
                {"san": "Bd6",
                 "comment": c("À connaître des deux côtés : avec un jeu précis les Noirs tiennent, et notre attaque doit venir vite ou pas du tout.",
                              "Know it from both sides: with accurate play Black holds, and our attack must come fast or not at all.")},
            ],
        },
    ],
}
