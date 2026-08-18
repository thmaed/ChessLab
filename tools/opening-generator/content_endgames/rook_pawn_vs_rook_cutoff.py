# -*- coding: utf-8 -*-
"""Tour et pion contre tour — couper avant de pousser (étude de Chéron).

Sourcé Chéron : la tour doit couper le roi adverse sur la 3e rangée AVANT
de songer à avancer le pion — le pousser tout de suite jette la victoire
par la fenêtre. Racine à 5 pièces, dtm 89 : la technique complète est
longue, mais la décision qui compte se joue dès le premier coup.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-pawn-vs-rook-cutoff",
    "name": "Cut Off Before You Push",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "2r5/5k2/8/8/8/2P5/2K5/4R3 w - - 0 1",
    "summary": c(
        "Un pion de plus, une tour active — et pourtant, presque tout ce que les blancs peuvent jouer ne fait que la nulle. Un seul principe sépare la victoire de la nulle ici : couper le roi noir avant même de songer à avancer le pion.",
        "An extra pawn, an active rook — and yet almost everything White can play only draws. One single principle separates the win from the draw here: cut Black's king off before even thinking about advancing the pawn.",
    ),
    "lines": [
        {
            "chapter": {"id": "cut-off-first", "title": c("Couper d'abord, avancer ensuite", "Cut off first, advance later")},
            "moves": [
                {"san": "Re3",
                 "comment": c("La tour s'installe sur la 3e rangée : le roi noir ne pourra plus jamais s'approcher du pion depuis le sud. C'est cette coupure, et non le pion lui-même, qui décide de tout.",
                              "The rook settles on the 3rd rank: Black's king can never approach the pawn from the south again. This cutoff, not the pawn itself, decides everything."),
                 "critical": True},
                {"san": "Rxc3+",
                 "comment": c("Les noirs croquent le pion avec échec — la seule tentative un peu concrète. Mais céder la tour contre le pion mène à un pur roi-et-tour contre roi, gagné pour n'importe qui connaît la technique élémentaire.",
                              "Black grabs the pawn with check — the only somewhat concrete try. But trading the rook for the pawn leads to a bare king-and-rook versus king, won by anyone who knows the elementary technique.")},
                {"san": "Kxc3",
                 "comment": c("Le roi reprend la tour. Ce qui reste — roi et tour blancs contre roi noir seul — n'est plus que la finale élémentaire déjà connue : gagnée, sans le moindre doute.",
                              "The king recaptures the rook. What's left — White king and rook against Black's lone king — is just the already-known elementary finale: won, without a shred of doubt."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "push-too-soon", "title": c("Pousser avant de couper", "Pushing before cutting off")},
            "moves": [
                {"san": "c4", "role": "trap",
                 "comment": c("Semble efficace — avancer le pion pendant qu'on y pense. Mais sans coupure, il reste sans défense.",
                              "Looks efficient — advance the pawn while you're at it. But without a cutoff, it stands undefended."),
                 "critical": True},
                {"san": "Rxc4+",
                 "comment": c("La tour noire le croque avec échec. Le pion est parti, et avec lui toute chance de gain — nulle, tour contre tour.",
                              "Black's rook grabs it with check. The pawn is gone, and with it every winning chance — a draw, rook against rook."),
                 "critical": True},
            ],
        },
    ],
}
