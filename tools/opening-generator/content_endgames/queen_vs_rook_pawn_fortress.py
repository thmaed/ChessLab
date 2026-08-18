# -*- coding: utf-8 -*-
"""Dame contre tour et pion — la forteresse du pion non-tour en 2e rangée.

Sourcé Müller & Lamprecht (« Fundamental Chess Endings »), via Wikipédia
(« Queen versus rook endgame ») : un pion ordinaire (pas un pion-tour) sur
la 2e rangée, juste à côté du roi et de la tour, referme une forteresse que
la dame seule ne perce jamais. Racine à 5 pièces, chaque coup blanc tranché
par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-rook-pawn-fortress",
    "name": "Queen vs Rook and Pawn — the Fortress",
    "side": "white",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "8/8/1q6/8/5k2/4R3/5PK1/8 w - - 0 1",
    "summary": c(
        "Dame contre tour, matériel généralement gagnant pour la dame — sauf ici : un pion ordinaire en 2e rangée, collé au roi et à la tour, ferme une forteresse que la dame ne perce jamais tant que la tour ne bouge pas de la 3e rangée.",
        "Queen versus rook, usually winning material for the queen — except here: an ordinary pawn on the 2nd rank, glued to the king and rook, closes a fortress the queen never breaks through as long as the rook stays on the 3rd rank.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-shuffle", "title": c("La navette qui ne bouge jamais", "The shuttle that never moves")},
            "moves": [
                {"san": "Rg3",
                 "comment": c("La tour reste sur la 3e rangée, devant son propre pion — la dame ne peut s'infiltrer ni par g3 ni par les cases voisines sans perdre l'échange par une fourchette de tour.",
                              "The rook stays on the 3rd rank, in front of its own pawn — the queen can't infiltrate via g3 or the neighbouring squares without losing the exchange to a rook fork."),
                 "critical": True},
                "Ke4",
                {"san": "Re3+",
                 "comment": c("Échec, et retour immédiat sur la même rangée protectrice.", "Check, and an immediate return to the same protecting rank."),
                 "critical": True},
                "Kf4",
                {"san": "Rg3",
                 "comment": c("La navette : g3, e3, g3… La tour ne quitte jamais la 3e rangée, et rien de ce que joue la dame ne change la donne.",
                              "The shuttle: g3, e3, g3… The rook never leaves the 3rd rank, and nothing the queen plays changes anything."),
                 "critical": True},
                "Qc6+",
                {"san": "Kg1",
                 "comment": c("Le roi blanc se met simplement à l'abri des échecs. Nulle vérifiée : aucune tentative noire testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "White's king simply tucks itself away from the checks. Verified draw: no Black try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "leave-the-rank", "title": c("Quitter la 3e rangée pour faire mieux ?", "Leaving the 3rd rank to do better?")},
            "moves": [
                {"san": "Re6", "role": "trap",
                 "comment": c("Tentant : activer la tour, aller chercher la dame. Mais quitter la 3e rangée abandonne toute protection — la tour se retrouve seule au milieu de l'échiquier.",
                              "Tempting: activate the rook, go hunt the queen. But leaving the 3rd rank abandons all protection — the rook ends up alone in the middle of the board."),
                 "critical": True},
                {"san": "Qxe6",
                 "comment": c("La dame croque la tour gratuitement. Sans la navette sur la 3e rangée, il ne restait plus rien pour la défendre.",
                              "The queen gobbles the rook for free. Without the shuttle on the 3rd rank, nothing was left to defend it."),
                 "critical": True},
            ],
        },
    ],
}
