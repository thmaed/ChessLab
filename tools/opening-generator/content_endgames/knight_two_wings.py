# -*- coding: utf-8 -*-
"""Pions sur les deux ailes contre cavalier — il ne peut pas être partout.

Deux pions passés, un de chaque côté de l'échiquier, contre un cavalier
seul : la portée limitée du cavalier — quelques coups pour traverser tout
le plateau — l'empêche de courir surveiller les deux à la fois. Vérifié
depuis une position neutre à 5 pièces, chaque coup blanc tranché par
l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-knight-two-wings",
    "name": "Knight vs Pawns on Both Wings",
    "side": "white",
    "kind": "endgame",
    "family": "knights",
    "level": "club",
    "rootFEN": "8/8/4k3/P6P/2n5/8/4K3/8 w - - 0 1",
    "summary": c(
        "Un pion à chaque aile, déjà bien avancés, contre un cavalier seul : sa portée limitée — plusieurs coups pour traverser le plateau — l'empêche de courir défendre les deux cases de promotion à la fois. Il faut pousser maintenant : perdre un seul tempo laisse au cavalier le temps de choisir sa cible.",
        "One pawn on each wing, both well advanced, against a lone knight: its limited range — several moves to cross the board — keeps it from covering both queening squares at once. Push now: waste a single tempo and the knight has time to pick its target.",
    ),
    "lines": [
        {
            "chapter": {"id": "push-now", "title": c("Pousser tout de suite, sans hésiter", "Push right away, without hesitating")},
            "moves": [
                {"san": "a6",
                 "comment": c("Le pion a fonce vers la dame — le cavalier ne peut s'en occuper sans abandonner l'autre aile.", "The a-pawn races toward promotion — the knight can't deal with it without abandoning the other wing."),
                 "critical": True},
                "Nb6",
                {"san": "a7",
                 "comment": c("Presque à dame. Le cavalier, occupé ici, n'a plus le temps de traverser tout le plateau pour l'autre pion.", "Almost queening. The knight, busy here, no longer has time to cross the whole board for the other pawn."),
                 "critical": True},
                "Kf5",
                {"san": "Kd3",
                 "comment": c("Le roi blanc vient prêter main-forte pendant que le second pion, sur h5, attend son tour en réserve. Gagné : vérifié depuis la racine, seuls les deux coups de pion tenaient la victoire — chaque coup de roi ne faisait que la nulle.",
                              "White's king comes to help while the second pawn, on h5, waits its turn in reserve. Won: verified from the root, only the two pawn pushes held the win — every king move only drew."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "hesitate-and-lose-it", "title": c("Hésiter, et tout perdre", "Hesitate, and lose it all")},
            "moves": [
                {"san": "Kd1", "role": "trap",
                 "comment": c("Un coup de roi qui semble anodin — se mettre en sécurité avant de pousser. Mais le cavalier en profite aussitôt.",
                              "A king move that looks harmless — get to safety before pushing. But the knight takes advantage at once."),
                 "critical": True},
                {"san": "Nxa5",
                 "comment": c("Le cavalier croque le pion a gratuitement — le tempo perdu lui a donné exactement le temps qu'il lui fallait. Il ne reste que le pion h, et un cavalier seul peut s'en occuper : nulle.",
                              "The knight grabs the a-pawn for free — the lost tempo gave it exactly the time it needed. Only the h-pawn is left, and a lone knight can handle that: a draw."),
                 "critical": True},
            ],
        },
    ],
}
