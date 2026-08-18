# -*- coding: utf-8 -*-
"""La règle de Bahr, et sa faille — sourcé Francesco Santelli / ARVES.

Sourcé ARVES (« The flaw in Bahr's rule ») : la règle classique de Bahr
prétendait que cette position aux trois conditions réunies (pion-tour pas
encore à mi-chemin, roi attaquant collé à son pion, roi défenseur devant)
était gagnante pour les blancs. Santelli a montré que non : nulle. Racine
à 5 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bahr-rule-flaw",
    "name": "The Flaw in Bahr's Rule",
    "side": "black",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "8/8/8/8/p3k3/P7/4KP2/8 w - - 0 1",
    "summary": c(
        "Pions-tours bloqués sur l'aile dame, pion supplémentaire à l'aile roi : la règle de Bahr prétend que les trois conditions réunies ici suffisent à gagner pour les blancs. Santelli a montré la faille — c'est nulle. Fait remarquable : si les NOIRS avaient le trait dans cette même position, les blancs gagneraient.",
        "Blocked rook pawns on the queenside, a spare pawn on the kingside: Bahr's rule claims the three conditions met here are enough for White to win. Santelli found the flaw — it's a draw. Remarkably: if BLACK had the move in this exact same position, White would win.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-flaw", "title": c("Le pion supplémentaire ne suffit pas", "The spare pawn isn't enough")},
            "moves": [
                {"san": "f3+",
                 "comment": c("Le pion supplémentaire avance, escorté vers l'échange plutôt que gardé en réserve — la règle de Bahr voudrait que ce pion décide la partie tout seul.", "The spare pawn advances, escorted toward a trade rather than kept in reserve — Bahr's rule would have this pawn decide the game on its own."),
                 "critical": True},
                "Kd4",
                "f4",
                "Ke4",
                {"san": "f5",
                 "comment": c("Le pion continue sa route jusqu'à l'échange.", "The pawn keeps going all the way to the trade.")},
                {"san": "Kxf5",
                 "comment": c("Le roi noir le croque, et il ne reste que la course symétrique des pions-tours — une simple nulle d'opposition, comme si le pion supplémentaire n'avait jamais existé. La faille de Bahr, prouvée : les trois conditions réunies ne suffisaient pas.",
                              "Black's king takes it, and all that's left is the symmetric rook-pawn race — a simple opposition draw, as if the spare pawn had never existed. Bahr's flaw, proven: the three conditions together weren't enough."),
                 "critical": True},
            ],
        },
    ],
}
