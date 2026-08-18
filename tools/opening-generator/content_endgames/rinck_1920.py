# -*- coding: utf-8 -*-
"""La domination de Rinck (Henri Rinck, 1920) — quatorze cases, quatorze pertes.

Position sourcée Wikipédia (article « Domination », étude parue dans
La Stratégie, 1920) et confirmée par l'oracle jusque dans ses variantes
publiées : 1.Cd2 est l'UNIQUE gain, et TOUTES les réponses de la tour
perdent — fourchettes en d5/e6 comprises. La tablebase transforme ici la
« domination » d'intuition d'artiste en théorème.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rinck-1920",
    "name": "Rinck's Domination (1920)",
    "side": "white",
    "kind": "endgame",
    "family": "practical",
    "level": "advanced",
    "rootFEN": "8/2N5/8/8/4rk2/8/5K2/1N1B4 w - - 0 1",
    "summary": c(
        "Henri Rinck, 1920 : trois petites pièces contre une tour en plein centre, libre comme l'air. Un seul coup de cavalier — et l'air se change en filet : où que la tour aille, une fourchette l'attend. Le rêve noir (troquer la tour contre le FOU, car deux cavaliers ne matent pas) ne se réalisera sur aucune des quatorze cases.",
        "Henri Rinck, 1920: three minor pieces against a rook in mid-board, free as the wind. One knight move — and the wind becomes a net: wherever the rook goes, a fork is waiting. Black's dream (trading rook for BISHOP, since two knights cannot mate) will come true on none of the fourteen squares.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le filet se referme", "The net closes")},
            "moves": [
                {"san": "Nd2",
                 "comment": c("L'unique gain : le cavalier dormant de b1 entre en jeu EN ATTAQUANT la tour. La tablebase a compté pour nous : quatorze réponses légales, quatorze positions perdues. Et le seul vrai espoir noir — donner la tour contre le fou pour laisser deux cavaliers incapables de mater — n'y figure nulle part.",
                              "The only win: the sleeping b1-knight enters the game ATTACKING the rook. The tablebase did the counting for us: fourteen legal replies, fourteen lost positions. And Black's one real hope — giving the rook for the bishop, leaving two mateless knights — is nowhere on the list."),
                 "critical": True},
                {"san": "Re5",
                 "comment": c("La plus tenace : l'air du centre. Notez que « attaquer » le fou par …Te1 pendrait la tour au roi (Rxe1 !).",
                              "The most stubborn: mid-board air. Note that “attacking” the bishop with …Re1 simply hangs the rook to the king (Kxe1!).")},
                {"san": "Nc4",
                 "comment": c("Deuxième coup de fouet — le même cavalier, une case plus loin.",
                              "The second lash — the same knight, one square on.")},
                {"san": "Re4"},
                {"san": "Nd6",
                 "comment": c("Troisième. La tour vit maintenant au rythme des sabots.",
                              "Third. The rook now lives to the rhythm of hooves.")},
                {"san": "Re5"},
                {"san": "Bf3",
                 "comment": c("Le coup calme au milieu de la chasse : le fou ôte à la tour les cases centrales de la grande diagonale. Il ne lui reste que l'aile —",
                              "The quiet move in mid-chase: the bishop strips the rook of the long diagonal's central squares. Only the wing is left —"),
                 "critical": True},
                {"san": "Ra5"},
                {"san": "Ne6+",
                 "comment": c("— et l'aile a un prix : le cavalier de c7, resté immobile depuis le début, donne l'échec qui prépare la fourchette.",
                              "— and the wing has a price: the c7-knight, motionless until now, gives the check that sets up the fork."),
                 "critical": True},
                {"san": "Ke5"},
                {"san": "Nc4+",
                 "comment": c("Fourchette : roi e5, tour a5. Douze coups de deux cavaliers qui n'ont jamais quitté leur moitié de l'échiquier.",
                              "Fork: king on e5, rook on a5. Twelve moves from two knights that never left their half of the board."),
                 "critical": True},
                {"san": "Kxe6",
                 "comment": c("Autant croquer un cavalier au passage.",
                              "Might as well snap up a knight on the way.")},
                {"san": "Nxa5",
                 "comment": c("La tour est tombée SANS avoir touché le fou : il reste fou et cavalier — et ce duo-là mate (voir « Le mat du fou et du cavalier »). Toute la domination tenait à cela : perdre la tour, oui, mais jamais contre la bonne pièce.",
                              "The rook has fallen WITHOUT ever touching the bishop: bishop and knight remain — and that duo mates (see “The Bishop and Knight Mate”). The whole domination came down to this: the rook was always going to fall, just never for the right piece."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "re3", "title": c("La tour sous le roi", "The rook under the king")},
            "moves": [
                "Nd2",
                {"san": "Re3",
                 "comment": c("Collée à son roi, protégée par lui — la tour se croit intouchable :",
                              "Snuggled against her king, protected by him — the rook thinks herself untouchable:")},
                {"san": "Nd5+",
                 "comment": c("…mais c'est un échec À FOURCHETTE : d5 touche f4 et e3 à la fois.",
                              "…but the check is a FORK: d5 touches f4 and e3 at once."),
                 "critical": True},
                {"san": "Kg5"},
                {"san": "Nxe3",
                 "comment": c("Trois pièces contre roi nu — et le fou est toujours vivant, donc le mat est une formalité. Première illustration : près du roi n'est pas à l'abri.",
                              "Three pieces against a bare king — the bishop still alive, so mate is a formality. First illustration: near the king is not the same as safe.")},
            ],
        },
        {
            "chapter": {"id": "rd4", "title": c("La tour en d4", "The rook on d4")},
            "moves": [
                "Nd2",
                {"san": "Rd4",
                 "comment": c("Au centre, loin des deux cavaliers visibles… mais dans la fourchette du troisième acteur :",
                              "Central, away from both visible knights… but inside the third actor's fork:")},
                {"san": "Ne6+",
                 "comment": c("Le cavalier de c7 : e6 touche f4 ET d4.",
                              "The c7-knight: e6 hits f4 AND d4."),
                 "critical": True},
                {"san": "Ke5"},
                {"san": "Nxd4"},
                {"san": "Kxd4",
                 "comment": c("Le roi récupère un cavalier — trop tard : fou et cavalier suffisent (voir le cours du mat). Remarquez la constante : les Noirs ne rattrapent jamais QUE le cavalier, jamais le fou.",
                              "The king wins a knight back — too late: bishop and knight suffice (see the mating course). Note the constant: Black only ever catches THE KNIGHT back, never the bishop.")},
            ],
        },
        {
            "chapter": {"id": "re7", "title": c("La tour en e7", "The rook on e7")},
            "moves": [
                "Nd2",
                {"san": "Re7",
                 "comment": c("Loin de tout, avec un œil sur c7 — la tour propose l'échange de SON choix :",
                              "Far from everything, one eye on c7 — the rook offers a trade of HER choosing:")},
                {"san": "Nd5+",
                 "comment": c("Refusé : la même case d5 fourche dans l'autre direction — f4 et e7.",
                              "Declined: the same d5-square forks the other way — f4 and e7."),
                 "critical": True},
                {"san": "Ke5"},
                {"san": "Nxe7",
                 "comment": c("Où que la tour soit allée — e3, d4, e7, e5… — une géométrie de cavalier l'attendait. C'est cela, une domination : pas une combinaison, un état de l'échiquier.",
                              "Wherever the rook went — e3, d4, e7, e5… — some knight geometry was waiting. That is what domination means: not a combination, a state of the board.")},
            ],
        },
    ],
}
