# -*- coding: utf-8 -*-
"""Pions liés en 6e contre tour — le seuil qui bat la pièce lourde.

Théorie classique : deux pions passés liés qui atteignent la 6e rangée
battent une tour seule si les rois sont trop loin pour peser sur les
événements — un rang plus tôt (5e), c'est l'inverse, la tour tient. Racine
à 4 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-connected-passers-sixth-rank",
    "name": "Connected Passers on the 6th Rank vs Rook",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "r6k/8/3PP3/8/8/8/8/1K6 w - - 0 1",
    "summary": c(
        "Deux pions passés liés sur la 6e rangée, rois trop loin pour participer : ils battent une tour ENTIÈRE. Un seul rang plus tôt (5e rangée), c'est l'inverse — la tour tient toujours. Le seuil exact tient en une case d'avance.",
        "Two connected passed pawns on the 6th rank, kings too far to take part: they beat an ENTIRE rook. One rank earlier (5th), it's the reverse — the rook always holds. The exact threshold comes down to one square of advance.",
    ),
    "lines": [
        {
            "chapter": {"id": "push-now", "title": c("Pousser tout de suite, sans hésiter", "Push right away, without hesitating")},
            "moves": [
                {"san": "d7",
                 "comment": c("Le premier pion fonce vers la dame — la tour ne peut en arrêter qu'un à la fois.", "The first pawn races toward promotion — the rook can only stop one at a time."),
                 "critical": True},
                "Rb8+",
                "Kc2",
                "Ra8",
                {"san": "e7",
                 "comment": c("Le second pion suit — désormais les deux menacent de promouvoir la même rangée plus tard, et la tour ne suffit plus à couvrir les deux cases.",
                              "The second pawn follows — now both threaten to promote, and the rook can no longer cover both squares."),
                 "critical": True},
                "Ra2+",
                "Kb3",
                {"san": "Rd2",
                 "comment": c("La tour ne peut plus qu'assister, impuissante, à la promotion inévitable de l'un des deux pions. Depuis la racine, chaque tentative noire testée par l'oracle a échoué de la même façon : la tour seule ne couvre jamais deux cases de promotion à la fois.",
                              "The rook can only watch, powerless, as one of the two pawns inevitably promotes. From the root, every Black try the oracle tested failed the same way: a lone rook never covers two promotion squares at once."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "hesitate-and-lose-it", "title": c("Hésiter, et tout perdre", "Hesitate, and lose it all")},
            "moves": [
                {"san": "Kc1", "role": "trap",
                 "comment": c("Un coup de roi qui semble anodin — mettre le roi à l'abri avant de pousser. Mais chaque tempo compte : le roi noir en profite pour se rapprocher.",
                              "A king move that looks harmless — tuck the king away before pushing. But every tempo counts: Black's king uses it to get closer."),
                 "critical": True},
                {"san": "Kg7",
                 "comment": c("Le roi noir accourt vers les pions. Le seuil de la 6e rangée ne suffit plus dès que le roi défenseur a le temps de rejoindre la bataille — le tempo perdu a inversé tout le verdict.",
                              "Black's king rushes toward the pawns. The 6th-rank threshold no longer suffices once the defending king has time to join the fight — the lost tempo flipped the entire verdict."),
                 "critical": True},
            ],
        },
    ],
}
