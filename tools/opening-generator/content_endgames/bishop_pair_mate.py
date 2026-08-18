# -*- coding: utf-8 -*-
"""Le mat aux deux fous — la double barrière qui avance.

Ligne principale ENTIÈREMENT DTM-optimale (dérivée de la tablebase), comme
`rook_mate.py`. Root à 4 pièces : DTM exact, aucune approximation.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bishop-pair-mate",
    "name": "The Bishop Pair Mate",
    "side": "white",
    "kind": "endgame",
    "family": "mates",
    "level": "club",
    "rootFEN": "8/8/8/4k3/8/8/4K3/2B2B2 w - - 0 1",
    "summary": c(
        "Roi et deux fous de couleurs opposées contre roi seul : le troisième mat élémentaire, après la tour et la dame. Les deux fous avancent COLLÉS l'un à l'autre en diagonale — une barrière que le roi noir ne peut jamais franchir — pendant que le roi blanc vient donner le coup de grâce.",
        "King and two opposite-coloured bishops versus a lone king: the third elementary mate, after the rook and the queen. The two bishops advance GLUED to each other on adjacent diagonals — a barrier the black king can never cross — while White's king comes in for the kill.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La barrière diagonale, puis le roi qui conclut", "The diagonal barrier, then the king finishes it")},
            "moves": [
                {"san": "Kd3",
                 "comment": c("Les fous seuls ne peuvent RIEN forcer — comme la tour, ils ont besoin du roi pour porter le coup final. Il se met donc en marche dès le premier coup.",
                              "The bishops alone can force NOTHING — like the rook, they need the king to deliver the final blow. So it sets off from move one."),
                 "critical": True},
                "Kd5",
                {"san": "Bf4",
                 "comment": c("Les deux fous vont se poster sur deux diagonales VOISINES — une case d'écart entre elles. Ensemble, ils barrent une double rangée de cases que le roi noir ne peut plus traverser.",
                              "The two bishops are heading for two NEIGHBOURING diagonals — one square apart. Together they bar a double row of squares the black king can never cross again."),
                 "critical": True},
                "Kc5",
                {"san": "Bg2",
                 "comment": c("La barrière est en place : cases c5 et au-delà interdites côté nord-est. Comme la tour qui coupe une rangée, les fous coupent maintenant en diagonale — et eux non plus n'ont plus besoin de bouger pour la tenir.",
                              "The barrier is up: c5 and everything beyond it is off-limits to the northeast. Like the rook that cuts off a rank, the bishops now cut off on the diagonal — and just like the rook, they don't need to move again to hold it."),
                 "critical": True},
                "Kb4", "Be3", "Ka5",
                {"san": "Bc6",
                 "comment": c("La barrière avance d'un cran, exactement comme la tour rétrécissait sa boîte : dès que le roi noir s'écarte, un fou glisse d'une diagonale vers l'intérieur.",
                              "The barrier advances one notch, exactly like the rook shrinking its box: the moment the black king steps back, one bishop slides one diagonal further in."),
                 "critical": True},
                "Ka6", "Bc5", "Ka5", "Kc4", "Ka6", "Kd5", "Ka5", "Bd7", "Ka6", "Kc6", "Ka5",
                {"san": "Kc7",
                 "comment": c("Le roi blanc a rejoint le front : il ne reste plus qu'à pousser le roi noir sur la colonne a, puis à choisir la case exacte du mat — n'importe quelle case du bord ferait l'affaire, contrairement au mat au fou-et-cavalier qui exige LE bon coin.",
                              "White's king has joined the front: all that remains is to push Black's king onto the a-file, then pick the exact mating square — any edge square would do here, unlike the bishop-and-knight mate, which demands THE one correct corner."),
                 "critical": True},
                "Ka6", "Bb4", "Ka7", "Bc8", "Ka8",
                {"san": "Bb7+",
                 "comment": c("Plus une case : a8 et a6 sont couvertes par ce fou, b8 et b6 par le roi blanc. Le roi noir n'a plus que a7 — et c'est justement là qu'il est poussé.",
                              "No square left: a8 and a6 are covered by this bishop, b8 and b6 by White's king. Black's king has only a7 left — and that is exactly where it is being pushed."),
                 "critical": True},
                "Ka7",
                {"san": "Bc5#",
                 "comment": c("Le tableau final : les deux fous couvrent chacun leur diagonale, le roi blanc couvre les deux cases restantes — a7 est en échec et n'a nulle part où fuir. Retenez l'image : c'est elle qu'on vise depuis le tout premier coup.",
                              "The final picture: each bishop covers its own diagonal, White's king covers the two remaining squares — a7 is in check with nowhere to run. Remember this picture: it is the one you are aiming for from the very first move."),
                 "critical": True},
            ],
        },
    ],
}
