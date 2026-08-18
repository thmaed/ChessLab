# -*- coding: utf-8 -*-
"""Tour et pion contre tour — l'exception à la règle de Tarrasch.

Sourcé Wikipédia (« Tarrasch rule ») : Short-Yusupov, 1984. La tour
« derrière son pion » n'est qu'une heuristique, pas une loi — ici, la
jouer tout de suite ne fait que la nulle. Il faut d'abord couper le roi
noir sur la 7e rangée ; la tour ne rejoint la bonne case qu'ensuite.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-cutoff-tempo",
    "name": "The Tarrasch Rule's Famous Exception",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "6r1/8/7K/8/4k2P/2P2R2/8/8 w - - 0 1",
    "summary": c(
        "« La tour se place derrière le pion passé » est la règle de Tarrasch — mais Short-Yusupov (1984) en est l'exception classique : jouer la tour derrière le pion TOUT DE SUITE ne fait que la nulle. Il faut d'abord couper le roi noir.",
        "\"The rook belongs behind the passed pawn\" is the Tarrasch rule — but Short-Yusupov (1984) is its classic exception: playing the rook behind the pawn RIGHT AWAY only draws. The king must be cut off first.",
    ),
    "lines": [
        {
            "chapter": {"id": "cutoff-first", "title": c("Couper le roi avant de ranger la tour", "Cut the king off before tucking the rook in")},
            "moves": [
                {"san": "Rf7",
                 "comment": c("Pas la case « derrière le pion » — mais la bonne quand même. La tour coupe le roi noir sur la 7e rangée avant de songer à escorter le pion h.",
                              "Not the \"behind the pawn\" square — but the right one anyway. The rook cuts Black's king off on the 7th rank before thinking about escorting the h-pawn."),
                 "critical": True},
                {"san": "Rh8+", "comment": c("Le seul moyen de créer des embêtements : harceler le roi blanc par échecs.", "The only way to cause trouble: harass White's king with checks.")},
                "Kg5",
                "Rg8+",
                "Kf6",
                {"san": "Rh8",
                 "comment": c("Les échecs sont épuisés — la tour noire n'a plus d'autre idée que revenir surveiller le pion h.",
                              "The checks are exhausted — Black's rook has no idea left but to come back and watch the h-pawn.")},
                {"san": "Rd7",
                 "comment": c("Le roi noir, livré à lui-même loin de son pion protecteur, est repoussé plus loin encore — la tour blanche gagne du terrain avant de se replier.",
                              "Left to itself far from its protecting pawn, Black's king is pushed back even further — White's rook gains ground before falling back."),
                 "critical": True},
                "Kf3",
                "Rd3+",
                "Ke4",
                {"san": "Rh3",
                 "comment": c("Seulement MAINTENANT la tour rejoint la case « derrière le pion » — après avoir gagné plusieurs tempos de plus en coupant le roi noir en chemin. La même case qu'au premier coup, mais la position autour a complètement changé.",
                              "Only NOW does the rook reach the \"behind the pawn\" square — after winning several extra tempi by cutting Black's king off along the way. The same square as move one, but the position around it has completely changed."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "rule-too-soon", "title": c("La règle appliquée trop tôt", "The rule applied too soon")},
            "moves": [
                {"san": "Rh3", "role": "trap",
                 "comment": c("La règle de Tarrasch dit : tour derrière le pion passé. Jouée immédiatement, sans avoir coupé le roi noir au préalable, elle ne fait pourtant que la nulle.",
                              "The Tarrasch rule says: rook behind the passed pawn. Played immediately, without cutting Black's king off first, it only draws."),
                 "critical": True},
                {"san": "Kf5",
                 "comment": c("Le roi noir, encore libre de circuler, rejoint directement la zone du pion et neutralise tout. La règle n'est qu'une heuristique — la position concrète décide.",
                              "Black's king, still free to roam, heads straight for the pawn's zone and neutralises everything. The rule is only a heuristic — the concrete position decides."),
                 "critical": True},
            ],
        },
    ],
}
