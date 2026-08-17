# -*- coding: utf-8 -*-
"""L'opposition (roi et pion contre roi) — la finale la plus importante du jeu.

Toutes les lignes dérivées SOUS l'oracle tablebase (`verify_line.py`), jamais
de mémoire : la racine « évidente » écrite au premier jet (rois d6/d4,
opposition directe, trait aux Blancs) s'est révélée NULLE — c'est précisément
la leçon du cours, et l'outil a évité de l'enseigner à l'envers.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-opposition",
    "name": "The Opposition",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/4k3/8/3K4/4P3/8/8 w - - 0 1",
    "summary": c(
        "Roi et pion contre roi : la finale que TOUTES les autres finissent par devenir. Une seule case gagne ici — celle qui prend l'opposition. Qui la comprend convertit ses fins de partie ; qui la devine les partage.",
        "King and pawn versus king: the endgame every other endgame eventually becomes. Exactly one square wins here — the one that takes the opposition. Understand it and you convert your endings; guess and you split the point.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La seule case qui gagne", "The only winning square")},
            "moves": [
                {"san": "Ke4",
                 "comment": c("La SEULE case qui gagne — tout le reste annule, y compris pousser le pion. Rois face à face, une case entre eux, l'adversaire au trait : c'est l'OPPOSITION, et celui qui ne l'a pas doit céder le passage.",
                              "The ONLY square that wins — everything else draws, including pushing the pawn. Kings face to face, one square apart, opponent to move: that is the OPPOSITION, and whoever doesn't hold it must give way."),
                 "critical": True},
                {"san": "Kd6",
                 "comment": c("Les Noirs cèdent un côté (Kf6 est le miroir exact). Le roi blanc passe par la porte qu'on vient d'ouvrir.",
                              "Black yields one side (Kf6 mirrors exactly). The white king walks through the door just opened.")},
                {"san": "Kf5",
                 "comment": c("Le DÉBORDEMENT : on avance en diagonale du côté abandonné, gagnant du terrain à chaque pas. Le pion attendra — le roi d'abord, toujours.",
                              "The OUTFLANKING: advance diagonally on the abandoned side, gaining ground with every step. The pawn can wait — king first, always."),
                 "critical": True},
                "Kd5",
                {"san": "e4+",
                 "comment": c("Maintenant seulement : le pion avance AVEC échec, donc sans perdre l'opposition. Comparez avec le chapitre « Le pion pressé » où le même coup, un temps trop tôt, annule.",
                              "Only now: the pawn advances WITH check, so without losing the opposition. Compare the “hasty pawn” chapter, where the same push one tempo too early draws.")},
                "Kd6",
                {"san": "Kf6",
                 "comment": c("L'opposition reprise, une rangée plus haut. Le mécanisme se répète : opposition, débordement, pion.",
                              "The opposition regained, one rank higher. The mechanism repeats: opposition, outflank, pawn.")},
                "Kd7",
                {"san": "e5", "comment": c("Le pion suit son roi — jamais l'inverse.",
                                           "The pawn follows its king — never the other way round.")},
                "Ke8",
                {"san": "Ke6",
                 "comment": c("Opposition à nouveau, décisive : le roi noir n'a plus d'espace derrière lui.",
                              "Opposition again, decisive this time: the black king has no space left behind him."),
                 "critical": True},
                "Kf8",
                {"san": "Kd7",
                 "comment": c("Le roi contrôle e8 : le couloir de promotion est acheté. Le reste est de l'escorte.",
                              "The king seizes e8: the promotion corridor is bought and paid for. The rest is an escort.")},
                "Kf7", "e6+", "Kf8", "e7+", "Kf7",
                {"san": "e8=Q+",
                 "comment": c("Le pion couronne AVEC échec. Le mat à la dame est un autre cours — celui-ci vous a appris à en arriver là.",
                              "The pawn queens WITH check. Mating with the queen is another course — this one taught you how to get here.")},
            ],
        },
        {
            "chapter": {"id": "mirror", "title": c("Le miroir : céder de l'autre côté", "The mirror: yielding the other way")},
            "moves": [
                "Ke4",
                {"san": "Kf6", "comment": c("Céder côté roi ne change rien : le débordement passe alors par d5, symétrique parfait de Kf5.",
                                            "Yielding on the kingside changes nothing: the outflank then goes through d5, a perfect mirror of Kf5.")},
                {"san": "Kd5", "critical": True},
                "Ke7",
                {"san": "Ke5",
                 "comment": c("Opposition reprise. À partir d'ici, rejouez le chapitre principal dans un miroir.",
                              "Opposition regained. From here, replay the main chapter in a mirror.")},
            ],
        },
        {
            "chapter": {"id": "hasty-pawn", "title": c("Le pion parti trop tôt", "The pawn that left too early")},
            "moves": [
                {"san": "e4", "role": "trap",
                 "comment": c("LA faute universelle : pousser parce qu'un pion, ça pousse. Le gain vient de s'évaporer — les Noirs reprennent l'opposition et la garderont jusqu'au pat.",
                              "THE universal mistake: pushing because pawns push. The win just evaporated — Black regains the opposition and will keep it all the way to stalemate."),
                 "critical": True},
                {"san": "Kd6",
                 "comment": c("La seule défense, et elle suffit : le roi noir se place pour prendre l'opposition dès que le roi blanc avance.",
                              "The only defence, and it suffices: the black king stands ready to take the opposition the moment the white king steps up.")},
                {"san": "e5+", "comment": c("Pousser encore ne menace rien : le roi noir se plante DEVANT le pion.",
                                            "Pushing again threatens nothing: the black king plants himself IN FRONT of the pawn.")},
                {"san": "Ke6",
                 "comment": c("Le blocus. Le roi blanc arrive, prend l'opposition… et découvre qu'elle ne sert à rien : le pion en e5 lui vole la case e5 dont le débordement aurait eu besoin.",
                              "The blockade. The white king arrives, takes the opposition… and finds it useless: the pawn on e5 has stolen the very square the outflank would have needed.")},
            ],
        },
        {
            "chapter": {"id": "hasty-pawn-2", "title": c("Le roi mange même le pion", "The king even eats the pawn")},
            "moves": [
                {"san": "e4", "role": "trap"},
                "Kd6",
                {"san": "Kc4", "comment": c("Tenter le tour par l'aile ne vaut pas mieux.",
                                            "Trying to go round the wing is no better.")},
                {"san": "Ke5",
                 "comment": c("Le roi noir attaque le pion abandonné : les Blancs devront le défendre à perpétuité — quand ils ne le perdront pas tout court.",
                              "The black king attacks the abandoned pawn: White will defend it forever — when he doesn't simply lose it.")},
            ],
        },
        {
            "chapter": {"id": "hasty-middle", "title": c("Le pion pressé en chemin", "The hasty pawn, later on")},
            "moves": [
                "Ke4", "Kd6", "Kf5", "Kd5",
                {"san": "e4+"},
                "Kd6",
                {"san": "e5+", "role": "trap",
                 "comment": c("Même en pleine manœuvre gagnante, UNE poussée hâtive suffit : ce coup chasse le roi noir vers e7… d'où il reprendra l'opposition.",
                              "Even mid-winning-manoeuvre, ONE hasty push is enough: this move drives the black king to e7… from where he regains the opposition."),
                 "critical": True},
                {"san": "Ke7",
                 "comment": c("La seule défense — et elle tient. Devant le pion, à distance d'opposition.",
                              "The only defence — and it holds. In front of the pawn, at opposition distance.")},
                "Kg6",
                {"san": "Ke6",
                 "comment": c("Collé au pion : le roi blanc ne peut plus ni le défendre en avançant, ni déborder. Nulle de manuel.",
                              "Glued to the pawn: the white king can no longer advance to shepherd it, nor outflank. Textbook draw.")},
            ],
        },
    ],
}
