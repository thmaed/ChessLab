# -*- coding: utf-8 -*-
"""Tour et pion contre cavalier — le cavalier ne peut pas tout bloquer seul.

Contrairement à tour+pièce mineure CONTRE tour seule (où l'extra ne suffit
souvent pas), ici c'est l'inverse : un pion supplémentaire suffit très
généralement à la tour pour l'emporter contre un cavalier seul — le
cavalier n'a pas l'allonge pour à la fois freiner le pion et échapper à
la domination de la tour. Vérifié depuis une position neutre.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-and-pawn-vs-knight",
    "name": "Rook and Pawn vs Knight",
    "side": "white",
    "kind": "endgame",
    "family": "imbalances",
    "level": "club",
    "rootFEN": "8/8/2n3k1/8/3PK3/8/8/4R3 w - - 0 1",
    "summary": c(
        "Un pion de plus suffit très généralement à la tour pour l'emporter contre un cavalier seul. Le cavalier n'a pas l'allonge pour freiner le pion tout en évitant d'être dominé par la tour et le roi ensemble.",
        "One extra pawn is usually enough for the rook to beat a lone knight. The knight lacks the reach to both hold back the pawn and stay out of the rook and king's combined domination.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-pawn-marches", "title": c("Le pion avance, le cavalier ne suit pas", "The pawn marches, the knight can't keep up")},
            "moves": [
                {"san": "d5",
                 "comment": c("Le pion se met en route, escorté par son roi.", "The pawn sets off, escorted by its king."),
                 "critical": True},
                "Nb8",
                "Ke5",
                "Na6",
                {"san": "d6",
                 "comment": c("Le pion continue d'avancer — le cavalier, trop loin, ne peut plus revenir à temps pour le bloquer.", "The pawn keeps advancing — the knight, too far away, can no longer get back in time to block it."),
                 "critical": True},
                "Nc5",
                "Kd4",
                "Nd7",
                {"san": "Re7",
                 "comment": c("La tour attaque directement le cavalier, resté sans aucune défense — le roi noir est bien trop loin pour le secourir. La combinaison tour + roi + pion déborde toujours un cavalier isolé qui doit tout faire seul.",
                              "The rook attacks the knight directly, left with no defence at all — Black's king is far too distant to help. The rook + king + pawn combination always overwhelms a lone knight that has to do everything by itself."),
                 "critical": True},
            ],
        },
    ],
}
