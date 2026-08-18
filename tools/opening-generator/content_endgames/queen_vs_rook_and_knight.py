# -*- coding: utf-8 -*-
"""Dame contre tour et cavalier — le triangle, encore plus difficile à percer.

Même principe que contre tour et fou : la dame l'emporte en général sur
tour+cavalier sans pion, sauf si les trois pièces noires restent groupées,
chacune protégée par une autre. Le cavalier défend des cases que le fou ne
peut pas voir — le triangle résiste ici à CHAQUE tentative testée par
l'oracle depuis la racine, sans une seule faille trouvée.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-rook-and-knight",
    "name": "Queen vs Rook and Knight",
    "side": "black",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "4n1r1/5k2/8/2Q5/4K3/8/8/8 w - - 0 1",
    "summary": c(
        "Le même triangle protecteur que contre tour et fou — mais encore plus solide. Le cavalier défend des cases où le fou ne peut jamais aller : depuis cette racine, chaque tentative blanche testée par l'oracle retombe sur la nulle, sans exception trouvée.",
        "The same protective triangle as against rook and bishop — but even sturdier. The knight defends squares a bishop could never reach: from this root, every White try the oracle tested lands back on a draw, with no exception found.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-triangle-holds", "title": c("Le triangle tient, même mieux qu'avec le fou", "The triangle holds, even better than with the bishop")},
            "moves": [
                {"san": "Qh5+", "comment": c("Le même échec à distance que contre tour et fou.", "The same long-distance check as against rook and bishop.")},
                {"san": "Kf8",
                 "comment": c("Le roi reste groupé avec sa tour et son cavalier. La différence avec le fou : ici, chaque coup noir testé depuis ce carrefour tient la nulle, pas seulement celui-ci — le cavalier couvre des cases que le fou, prisonnier d'une seule couleur, ne pourra jamais défendre.",
                              "The king stays bunched with its rook and knight. The difference from the bishop: here, every Black move tested from this crossroads holds the draw, not just this one — the knight covers squares that the bishop, trapped on one colour, could never defend."),
                 "critical": True},
            ],
        },
    ],
}
