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
                "Ne5", "e6", "g4", "Bg6", "h4",
                {"san": "Bb4",
                 "comment": c("Le vrai test, et il faut le dire franchement : ce clouage rend aux Noirs l'avantage (≈ +0,7). Le cours enseignait ici 8…h6, qui perd — apprendre une attaque contre la mauvaise défense, c'est apprendre à perdre contre la bonne.",
                              "The real test, and it must be said plainly: this pin gives Black the advantage back (≈ +0.7). The course used to teach 8…h6 here, which loses — learning an attack against the wrong defence means learning to lose against the right one."),
                 "critical": True},
                {"san": "Rh3",
                 "comment": c("La ressource : la tour se lève par la troisième rangée, défend c3 et rejoint l'attaque. C'est cela, jouer le Blackmar-Diemer contre une bonne défense — chercher les complications, pas l'égalité.",
                              "The resource: the rook lifts along the third rank, defends c3 and joins the attack. That is what playing the Blackmar-Diemer against a good defence means — seek complications, not equality."),
                 "critical": True},
                "Be4", "a3", "Bxc3+", "bxc3", "Nc6", "g5",
            ],
        },
        {
            "chapter": {"id": "teichmann-h6", "title": c("Teichmann — 8…h6, la faute naturelle",
                                                         "Teichmann — 8…h6, the natural mistake")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3", "Nxf3",
                "Bf5", "Ne5", "e6", "g4", "Bg6", "h4",
                {"san": "h6", "role": "trap",
                 "comment": c("Le coup que tout le monde joue — on protège le fou de g5 — et il coûte cher : le fou n'a plus de case et le pion f7 s'écroule.",
                              "The move everyone plays — guarding the bishop against g5 — and it costs dearly: the bishop has no square left and f7 collapses."),
                 "critical": True},
                {"san": "Bg2",
                 "comment": c("Et non Cxg6 tout de suite : le fou prend d'abord la grande diagonale, car sans le fou de cases blanches les Noirs n'ont plus rien pour garder b7.",
                              "Not Nxg6 at once: the bishop takes the long diagonal first, because without their light-squared bishop Black has nothing left to guard b7."),
                 "critical": True},
                "Bb4", "Nxg6", "fxg6",
                {"san": "Bxb7", "comment": c("La facture : la tour a8 tombe. C'est pour cela que 8…h6 perd, et pourquoi 8…Fb4 est le coup à connaître.",
                                             "The bill: the a8 rook falls. That is why 8…h6 loses, and why 8…Bb4 is the move to know.")},
                "Nbd7", "Bxa8", "Qxa8",
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

        # ── Trous comblés le 22/08 (coverage.py, dette 0,73). Répertoire BLANC.
        # Le gambit Blackmar-Diemer est objectivement douteux : plusieurs de ces
        # lignes finissent légèrement en faveur des Noirs. C'est le pari du
        # gambit, et le cours le dit. ────────────────────────────────────────
        {
            "chapter": {"id": "declined", "title": c("Gambit refusé — 2…e6", "Declined — 2…e6")},
            "moves": [
                "d4", "d5", "e4",
                {"san": "e6",
                 "comment": c("Le refus le plus fréquent — un joueur sur dix — et le cours ne prévoyait QUE la prise …dxe4. Ils transposent vers une Française, où notre gambit n'existe plus.",
                              "The most common decline — one player in ten — and the course only planned for the capture …dxe4. They steer into a French, where our gambit no longer exists."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("On joue la Française, et il faut l'accepter : proposer un gambit, c'est aussi accepter qu'on le refuse. Mieux vaut une bonne Française qu'un gambit forcé.",
                              "We play the French, and that has to be accepted: offering a gambit means accepting it can be declined. A good French beats a forced gambit."),
                 "critical": True},
                "Nf6", "Bg5", "h6", "Bxf6", "Qxf6", "a3", "Qd8", "Bd3", "g6",
            ],
        },
        {
            "chapter": {"id": "accepted-main", "title": c("Gambit accepté — ligne principale", "Accepted — main line")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3", "Nxf3",
                {"san": "e6",
                 "comment": c("Près de trois Noirs sur dix ferment la diagonale plutôt que de sortir un fou, et le cours ne prévoyait que …g6, …Ff5 et …Fg4. C'est la défense la plus solide contre le gambit.",
                              "Nearly three Black players in ten shut the diagonal rather than develop a bishop, and the course only planned for …g6, …Bf5 and …Bg4. It is the soundest defence to the gambit."),
                 "critical": True},
                {"san": "Bd3",
                 "comment": c("On développe vers le roque adverse. Le pion en moins ne se récupère pas : il achète du temps et des lignes ouvertes, il faut donc jouer vite et vers le roi.",
                              "We develop towards Black's king. The missing pawn does not come back: it buys time and open lines, so play must be fast and aimed at the king."),
                 "critical": True},
                "Be7", "Be3", "Nc6", "a3", "O-O", "h3", "a6", "O-O", "b5",
            ],
        },
        {
            "chapter": {"id": "vs-bf5", "title": c("Contre 3…Ff5", "vs 3…Bf5")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3",
                {"san": "Bf5",
                 "comment": c("Les Noirs sortent le fou avant de rendre le pion. Un joueur sur huit, et le cours ne voyait que …Cf6.",
                              "Black develops the bishop before returning the pawn. One player in eight, and the course only saw …Nf6."),
                 "critical": True},
                {"san": "g4",
                 "comment": c("Le coup brutal, et le bon : on chasse le fou avant qu'il ne s'installe, et le pion g4 participera à l'attaque plutôt que de rester en arrière.",
                              "The brutal move, and the right one: we evict the bishop before it settles, and the g4 pawn will join the attack rather than sit at home."),
                 "critical": True},
                "Bg6", "Nge2", "e5", "Be3", "Bb4", "a3", "Ba5", "Ng3", "Bxc3+",
            ],
        },
        {
            "chapter": {"id": "vs-f5", "title": c("Contre 3…f5 — le contre-gambit", "vs 3…f5 — the countergambit")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3",
                {"san": "f5",
                 "comment": c("Le contre-gambit : les Noirs bétonnent e4 avec un pion plutôt que de le rendre. Un joueur sur huit, absent du cours — et c'est la ligne où l'improvisation coûte le plus cher.",
                              "The countergambit: Black cements e4 with a pawn instead of returning it. One player in eight, missing from the course — and the line where improvising costs the most."),
                 "critical": True},
                {"san": "f3",
                 "comment": c("On frappe quand même. Après les échanges, leur pion e4 devient un pion f isolé et leur roque est définitivement affaibli : c'est le prix de …f5.",
                              "We strike anyway. After the exchanges their e4 pawn becomes an isolated f-pawn and their kingside is permanently loose: the price of …f5."),
                 "critical": True},
                "Nf6", "fxe4", "fxe4", "Nge2", "Bf5", "Bg5", "e6", "Ng3", "Be7",
            ],
        },
        {
            "chapter": {"id": "accepted-main", "title": c("Gambit accepté — ligne principale", "Accepted — main line")},
            "moves": [
                "d4", "d5", "e4", "dxe4", "Nc3", "Nf6", "f3", "exf3", "Nxf3", "Bg4", "h3",
                {"san": "Bxf3",
                 "comment": c("Près d'un Noir sur deux échange plutôt que de reculer en h5, et le cours ne prévoyait que …Fh5. Ils nous donnent la paire de fous pour retirer notre meilleur attaquant.",
                              "Nearly one Black player in two trades rather than retreat to h5, and the course only planned for …Bh5. They hand us the bishop pair to remove our best attacker."),
                 "critical": True},
                {"san": "Qxf3",
                 "comment": c("La dame arrive sur la colonne f, face à f7. L'échange leur a coûté leur meilleure pièce mineure ET nous a placé la dame là où elle voulait aller.",
                              "The queen lands on the f-file, facing f7. The trade cost them their best minor piece AND put our queen exactly where she wanted to be."),
                 "critical": True},
                "c6", "g4", "e6", "g5", "Nd5", "Bd3", "Be7", "h4", "Na6",
            ],
        },
    ],
}
