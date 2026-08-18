# -*- coding: utf-8 -*-
"""Défense frontale — la tour attend sur la rangée de promotion.

Sourcé Wikipédia (« Rook and pawn versus rook endgame »), technique de la
défense frontale : quand le roi défenseur est coupé du pion et ne peut
rejoindre la position de Philidor à temps, la tour se contente d'attendre
sur la rangée où le pion doit promouvoir — prête à le croquer dès qu'il y
arrive. Racine à 5 pièces, chaque choix noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-frontal-defence",
    "name": "Frontal Defence",
    "side": "black",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "1r6/4k3/8/8/6P1/6K1/5R2/8 w - - 0 1",
    "summary": c(
        "Le roi noir est coupé du pion — pas de position de Philidor possible. La tour se poste alors sur la rangée de promotion (peu importe la colonne) et n'a plus qu'à attendre : dès que le pion arrive, elle le croque.",
        "Black's king is cut off from the pawn — no Philidor position possible. The rook instead posts itself on the promotion rank (the file doesn't matter) and simply waits: the moment the pawn arrives, it's captured.",
    ),
    "lines": [
        {
            "chapter": {"id": "wait-on-the-rank", "title": c("Attendre sur la bonne rangée", "Waiting on the right rank")},
            "moves": [
                {"san": "g5", "comment": c("Le pion blanc avance, escorté par son roi.", "White's pawn advances, escorted by its king.")},
                {"san": "Rc8",
                 "comment": c("Peu importe sur quelle case de la 8e rangée — l'essentiel est d'y être, prêt à intercepter le pion quelle que soit sa colonne d'arrivée.",
                              "The exact square on the 8th rank doesn't matter — what counts is being there, ready to intercept the pawn whichever file it lands on."),
                 "critical": True},
                "g6",
                {"san": "Rc6",
                 "comment": c("La tour peut même harceler le pion par le flanc en chemin, tant qu'elle garde le temps de revenir sur la rangée de promotion.",
                              "The rook can even harass the pawn from the side along the way, as long as it keeps time to return to the promotion rank."),
                 "critical": True},
                "g7",
                {"san": "Rc8",
                 "comment": c("Retour juste à temps sur la 8e rangée. Le pion peut promouvoir — la tour, déjà postée sur cette rangée, le reprendra aussitôt. Nulle vérifiée : aucune tentative blanche testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Back just in time on the 8th rank. The pawn can promote — the rook, already stationed on that rank, will recapture it at once. Verified draw: no White try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "check-too-soon", "title": c("L'échec par-derrière, donné trop tôt", "The check from behind, given too soon")},
            "moves": [
                "g5",
                {"san": "Rb3+", "role": "trap",
                 "comment": c("L'échec par-derrière est souvent la ressource clé contre un pion soutenu par son roi — mais donné maintenant, bien trop tôt, il ne fait que rapprocher le roi blanc de son pion.",
                              "The check from behind is often the key resource against a king-supported pawn — but given now, far too early, it only helps White's king get closer to its pawn."),
                 "critical": True},
                {"san": "Kg4",
                 "comment": c("Le roi blanc avance sans crainte — la tour noire a gaspillé son échec, et le roi va maintenant escorter le pion jusqu'au bout.",
                              "White's king advances without fear — Black's rook wasted its check, and the king will now escort the pawn all the way home."),
                 "critical": True},
            ],
        },
    ],
}
