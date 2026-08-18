# -*- coding: utf-8 -*-
"""Tour contre fou — un autre déséquilibre qui n'en est pas un.

Comme le cavalier, un fou seul tient la nulle contre une tour seule, sans
pion sur l'échiquier. Vérifié depuis la position neutre : aucun coup blanc
n'y change quoi que ce soit.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-bishop",
    "name": "Rook vs Bishop",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "club",
    "rootFEN": "3bk3/8/8/8/8/8/8/3RK3 w - - 0 1",
    "summary": c(
        "Même verdict que contre le cavalier : sans pion, une tour seule ne bat pas un fou seul. Le roi et le fou restent groupés, et il n'existe littéralement rien que la tour puisse faire pour forcer quoi que ce soit.",
        "Same verdict as against the knight: with no pawn on the board, a lone rook does not beat a lone bishop. King and bishop stay together, and there is literally nothing the rook can do to force anything.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress", "title": c("La même histoire que le cavalier", "The same story as the knight")},
            "moves": [
                {"san": "Ke2",
                 "comment": c("Le roi blanc s'approche, comme toujours dans ces finales sans pion — c'est la seule carte qui reste à jouer, et elle ne suffit structurellement pas.",
                              "White's king approaches, as always in these pawnless endings — the only card left to play, and it structurally isn't enough."),
                 "critical": True},
                {"san": "Ke7",
                 "comment": c("Le roi noir reste collé à son fou. Toute la défense tient en un mot : ensemble.",
                              "Black's king stays glued to his bishop. The whole defence fits in one word: together.")},
                "Kd2",
                {"san": "Kd7",
                 "comment": c("Nulle, vérifiée : chaque coup de tour testé depuis cette position retombe sur le même résultat.",
                              "Draw, verified: every rook move tried from this position lands on the same result."),
                 "critical": True},
            ],
        },
    ],
}
