# -*- coding: utf-8 -*-
"""Fou contre deux pions séparés — une seule diagonale à la fois.

Même seuil de rang que pour le cavalier (5e tient, 6e perd), mais une
asymétrie propre au fou : il ne défend vraiment qu'UNE des deux diagonales
de fuite, jamais les deux ensemble.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bishop-vs-two-pawns",
    "name": "Bishop vs Two Separated Pawns",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "4k3/8/P6P/8/3b4/8/8/4K3 w - - 0 1",
    "summary": c(
        "Un fou couvre toute une diagonale d'un seul coup d'œil — de quoi croire qu'il surveille les deux ailes à la fois. Mais une diagonale ne va que dans UN sens : le pion qui s'échappe par l'autre n'a jamais été inquiété.",
        "A bishop sweeps an entire diagonal at a glance — tempting to think it watches both wings at once. But a diagonal only runs in ONE direction: the pawn escaping the other way was never in any danger.",
    ),
    "lines": [
        {
            "chapter": {"id": "sixth-rank", "title": c("Le bon côté à pousser", "The right side to push")},
            "moves": [
                {"san": "h7",
                 "comment": c("Le pion h fonce — le fou d4 tient bien la diagonale vers a7 (il peut s'y rendre en un coup), mais il n'a AUCUNE prise sur la route du pion h. Une diagonale, un sens : jamais les deux à la fois.",
                              "The h-pawn charges — the d4 bishop does control the diagonal to a7 (he can get there in one move), but he has NO grip whatsoever on the h-pawn's road. One diagonal, one direction: never both at once."),
                 "critical": True},
                {"san": "Kd7",
                 "comment": c("Le roi noir se précipite vers l'aile qui compte — trop tard, il ne peut être qu'à un endroit lui aussi.",
                              "Black's king rushes to the wing that matters — too late, he too can only be in one place.")},
                {"san": "a7",
                 "comment": c("Et le SECOND pion avance sans la moindre opposition — le fou, occupé à surveiller sa diagonale naturelle, ne l'a jamais vu venir.",
                              "And the SECOND pawn advances with no opposition at all — the bishop, busy watching his natural diagonal, never saw it coming.")},
                {"san": "Bxa7",
                 "comment": c("Le fou finit par le manger — bien trop tard : l'autre est déjà en 8e.",
                              "The bishop finally eats it — far too late: the other one is already on the 8th.")},
                {"san": "h8=Q",
                 "comment": c("Une dame surgit du côté que le fou n'a jamais pu couvrir. Retenez le principe, pas la ligne : sur la 5e rangée (un cran plus tôt), ce même fou tiendrait les DEUX pions — c'est l'avancement, pas la géométrie du fou, qui décide ici.",
                              "A queen appears from the side the bishop could never cover. Remember the principle, not the line: on the 5th rank (one notch earlier), this very bishop WOULD hold both pawns — it's how advanced they are, not the bishop's geometry, that decides here."),
                 "critical": True},
            ],
        },
    ],
}
