# -*- coding: utf-8 -*-
"""Tour et deux pions liés contre tour — la tour ne peut viser qu'un pion.

Deux pions passés et liés, déjà avancés, contre une tour seule : la tour
adverse ne peut jamais bloquer les deux à la fois sans s'exposer à un
échec qui la chasse. Vérifié depuis une position neutre — presque toute
tentative blanche testée par l'oracle gagne, la technique est robuste.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-two-connected-pawns",
    "name": "Rook and Two Connected Pawns vs Rook",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "4r1k1/8/2P5/3P4/8/8/8/3R2K1 w - - 0 1",
    "summary": c(
        "Deux pions passés et liés, déjà bien avancés, contre une tour seule : elle ne peut jamais surveiller les deux cases de promotion à la fois, et le moindre échec de flanc la chasse sans rien arrêter. Vérifié depuis une position neutre — la technique est robuste, presque tout gagne.",
        "Two connected passed pawns, already well advanced, against a lone rook: it can never watch both queening squares at once, and any flank check just chases it away without stopping anything. Verified from a neutral position — the technique is robust, almost everything wins.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-pawns-outrun-the-rook", "title": c("Les pions dépassent la tour", "The pawns outrun the rook")},
            "moves": [
                {"san": "d6",
                 "comment": c("Le premier pion avance — la tour noire ne peut le bloquer sans laisser le second filer.", "The first pawn advances — Black's rook can't blockade it without letting the second one run."),
                 "critical": True},
                "Re6",
                {"san": "d7",
                 "comment": c("Le pion continue, presque à dame. La tour ne fait plus que le suivre, impuissante.", "The pawn keeps going, almost queening. The rook can only follow it, powerless."),
                 "critical": True},
                "Rg6+",
                {"san": "Kf2",
                 "comment": c("Le roi blanc s'écarte de l'échec sans se presser — le pion sur la 7e rangée n'a plus besoin d'aide immédiate, et le second pion reste en réserve. Vérifié : la position reste gagnante quelle que soit la suite testée par l'oracle.",
                              "White's king sidesteps the check without hurrying — the pawn on the 7th rank needs no immediate help, and the second pawn stays in reserve. Verified: the position stays winning whatever continuation the oracle tests."),
                 "critical": True},
            ],
        },
    ],
}
