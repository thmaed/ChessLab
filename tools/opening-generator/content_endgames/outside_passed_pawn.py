# -*- coding: utf-8 -*-
"""Pion passé éloigné — le leurre qui ouvre l'autre aile.

La technique classique des finales de pions sur les deux ailes : un pion
passé loin du reste des pions force le roi adverse à s'en occuper seul,
pendant que le roi attaquant traverse l'échiquier pour croquer tout le
reste. Racine à 7 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-outside-passed-pawn",
    "name": "The Outside Passed Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/4k1pp/8/P3K3/8/8/6PP/8 w - - 0 1",
    "summary": c(
        "Un pion passé isolé à l'opposé du reste des pions ne sert pas qu'à promouvoir : il sert de LEURRE. Le roi noir doit s'en occuper seul, et pendant ce temps le roi blanc traverse tout l'échiquier pour croquer le reste.",
        "A passed pawn isolated on the opposite side from the rest doesn't just aim to promote: it works as a DECOY. Black's king has to deal with it alone, and meanwhile White's king crosses the whole board to gobble everything else.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-decoy", "title": c("Le leurre fait son travail pendant que le roi traverse", "The decoy does its job while the king crosses over")},
            "moves": [
                {"san": "a6",
                 "comment": c("Le pion passé s'élance seul, à l'opposé de tout le reste — le roi noir n'a pas d'autre choix que de courir l'arrêter.", "The passed pawn sets off alone, on the opposite side from everything else — Black's king has no choice but to run and stop it."),
                 "critical": True},
                "Kd7",
                {"san": "a7",
                 "comment": c("Toujours plus loin — et le roi noir toujours plus loin, lui aussi, de ses propres pions.", "Further still — and Black's king further still from its own pawns, too."),
                 "critical": True},
                "Kc7",
                {"san": "Ke6",
                 "comment": c("Pendant que le roi noir garde son a-pion, le roi blanc traverse tranquillement vers l'aile roi, où plus rien ne peut plus l'arrêter. Le leurre a fait tout le travail.",
                              "While Black's king watches its a-pawn, White's king strolls over to the kingside, where nothing can stop it any more. The decoy did all the work."),
                 "critical": True},
            ],
        },
    ],
}
