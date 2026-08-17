# -*- coding: utf-8 -*-
"""Le mat à la dame — la distance de cavalier, et LE piège de pat.

Ligne principale DTM-optimale (tablebase) ; le piège de pat est vérifié
« pat réel » par l'oracle — c'est la faute n°1 du joueur de club pressé.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-mate",
    "name": "The Queen Mate",
    "side": "white",
    "kind": "endgame",
    "family": "mates",
    "level": "club",
    "rootFEN": "8/8/8/3k4/8/8/8/2Q1K3 w - - 0 1",
    "summary": c(
        "Le mat le plus fréquent du jeu — et le plus raté : une dame trop zélée fait pat, et des heures de jeu s'évaporent. La méthode tient en une image : la dame se poste à DISTANCE DE CAVALIER du roi adverse, et ne donne presque jamais d'échec.",
        "The most common mate in chess — and the most botched: one over-eager queen move is stalemate, and hours of play evaporate. The method fits in one image: the queen sits a KNIGHT'S MOVE from the enemy king, and almost never checks.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La distance de cavalier", "The knight's-move distance")},
            "moves": [
                {"san": "Qc7",
                 "comment": c("Pas d'échec ! La dame prend le roi dans un L de cavalier et lui vole la moitié de l'échiquier : rangée 7, colonne c, et les deux diagonales. Chaque fuite du roi sera suivie du même L.",
                              "No check! The queen takes the king in a knight's L and steals half the board from him: the 7th rank, the c-file, both diagonals. Every royal flight will be answered by the same L."),
                 "critical": True},
                "Ke4",
                {"san": "Qc5",
                 "comment": c("Le roi a bougé, la dame reprend son L (e4-c5 : un saut de cavalier). Il n'a pas fui — il a déménagé dans une boîte plus petite.",
                              "The king moved, the queen re-takes her L (e4-c5: one knight's jump). He hasn't escaped — he has moved into a smaller box."),
                 "critical": True},
                "Kd3",
                {"san": "Qb4", "comment": c("Toujours le L. La dame ne poursuit pas le roi : elle rétrécit son monde.",
                                            "The L again. The queen isn't chasing the king: she is shrinking his world.")},
                "Ke3",
                {"san": "Kf1",
                 "comment": c("La dame confine à elle seule — c'est donc au ROI de venir. Un mat à la dame est toujours un travail d'équipe : elle enferme, il achève.",
                              "The queen confines all by herself — so it is the KING's turn to come. A queen mate is always teamwork: she cages, he finishes."),
                 "critical": True},
                "Kd3", "Kf2", "Kc2", "Ke2", "Kc1",
                {"san": "Kd3",
                 "comment": c("Le roi blanc prend la case-clé. Attention : c'est ICI que la dame trop zélée fait pat — voyez l'autre chapitre.",
                              "The white king takes the key square. Careful: HERE is where the over-eager queen stalemates — see the other chapter.")},
                "Kd1",
                {"san": "Qb1#",
                 "comment": c("Échec ET mat — le premier échec de toute la finale, et c'est le dernier coup. Retenez cette proportion : cent pour cent des échecs utiles.",
                              "Check AND mate — the first check of the entire ending, and it is the last move. Remember that ratio: one hundred percent of the checks were useful."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "stalemate", "title": c("Le pat du zèle", "The stalemate of zeal")},
            "moves": [
                "Qc7", "Ke4", "Qc5", "Kd3", "Qb4", "Ke3", "Kf1", "Kd3", "Kf2", "Kc2", "Ke2", "Kc1",
                {"san": "Qb3", "role": "trap",
                 "comment": c("« Encore un petit resserrement… » — PAT. Comptez avec l'adversaire AVANT de resserrer : b1, b2, c2, d1 pris par la dame, d2 par le roi. Zéro case. Des heures de jeu, un demi-point. La règle d'or : dès que le roi adverse touche le bord, cherchez le MAT, plus le confinement.",
                              "“One more little squeeze…” — STALEMATE. Count the opponent's squares BEFORE squeezing: b1, b2, c2, d1 taken by the queen, d2 by the king. Zero squares. Hours of play, half a point. The golden rule: once the enemy king touches the edge, look for MATE, not more confinement."),
                 "critical": True},
            ],
        },
    ],
}
