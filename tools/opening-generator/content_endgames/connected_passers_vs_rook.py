# -*- coding: utf-8 -*-
"""Deux pions liés contre tour — une tour ne peut arrêter qu'un pion à la fois.

Même paire de pions, un seul rang de différence (5e contre 6e), vérifiée à
la tablebase : gagné dans un cas, nulle dans l'autre. Le rang compte
littéralement plus que tout le reste.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-connected-passers-vs-rook",
    "name": "Connected Passers vs Rook",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "8/8/1PP5/8/8/8/8/r3K1k1 w - - 0 1",
    "summary": c(
        "Une tour vaut plus que deux pions — sur le papier. Mais une tour n'a qu'une seule case à la fois, et deux pions liés bien avancés lui en proposent deux d'un coup. Sur la 6e rangée, c'est déjà trop tard pour elle.",
        "A rook is worth more than two pawns — on paper. But a rook can only be on one square at a time, and two well-advanced connected pawns offer it two at once. On the 6th rank, it's already too late for the rook.",
    ),
    "lines": [
        {
            "chapter": {"id": "sixth-rank", "title": c("La 6e rangée : déjà perdu pour la tour", "The 6th rank: already lost for the rook")},
            "moves": [
                {"san": "Kd2",
                 "comment": c("Le roi blanc vient border ses pions — eux n'ont même plus besoin de lui pour l'essentiel, mais il empêche toute incursion du roi noir.",
                              "The white king comes to shepherd his pawns — they barely need him for the essential part, but he keeps Black's king from any incursion."),
                 "critical": True},
                {"san": "Ra5",
                 "comment": c("La tour cherche un angle d'attaque — mais elle ne peut viser qu'UN pion par coup, et il en reste toujours un pour avancer.",
                              "The rook looks for an angle — but she can only aim at ONE pawn per move, and there's always another one free to advance.")},
                "c7",
                {"san": "Rc5",
                 "comment": c("La tour change de cible : elle vient de perdre un temps que le second pion encaisse avec plaisir.",
                              "The rook switches targets: she just lost a tempo the second pawn happily banks.")},
                "b7",
                {"san": "Rxc7",
                 "comment": c("Elle finit par en manger un — c'était couru d'avance, et ça ne suffit pas : l'autre est déjà en 7e.",
                              "She finally eats one — inevitable from the start, and it isn't enough: the other is already on the 7th.")},
                {"san": "b8=Q",
                 "comment": c("Une dame surgit, la tour n'a jamais eu les moyens d'empêcher les DEUX pions. Deux pions liés sur la 6e ne se contrent pas avec une seule pièce.",
                              "A queen appears — the rook was never equipped to stop BOTH pawns. Two connected pawns on the 6th cannot be held by a single piece."),
                 "critical": True},
            ],
        },
    ],
}
