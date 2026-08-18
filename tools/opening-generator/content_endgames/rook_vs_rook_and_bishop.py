# -*- coding: utf-8 -*-
"""Tour et fou contre tour — la position de Szén, l'exception qui tient.

Sourcé Wikipédia (« Rook and bishop versus rook endgame »), position de
Szén : contrairement à la tour et le pion, la tour et le fou ne gagnent
PAS toujours contre une tour seule. Roi défenseur et tour bien placés
suffisent — la position a résisté quatre fois de suite à Pintér contre
Razuvayev, 1982. Racine à 5 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-rook-and-bishop",
    "name": "Rook vs Rook and Bishop — the Szén Position",
    "side": "white",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "8/2R5/8/1r6/4b3/4k3/8/3K4 b - - 0 1",
    "summary": c(
        "Tour et fou contre tour seule : matériel gagnant en général, mais pas ici. La position de Szén — roi et tour défenseurs bien placés — a résisté quatre fois de suite dans une vraie partie (Pintér-Razuvayev, 1982) avant la nulle.",
        "Rook and bishop versus a lone rook: usually winning material, but not here. The Szén position — defending king and rook well placed — held four times over in a real game (Pintér-Razuvayev, 1982) before the draw.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-fortress-holds", "title": c("La forteresse tient, coup après coup", "The fortress holds, move after move")},
            "moves": [
                {"san": "Bd3",
                 "comment": c("Les noirs centralisent le fou — la manœuvre la plus naturelle pour chercher une faille.", "Black centralises the bishop — the most natural try to look for a crack.")},
                {"san": "Re7+",
                 "comment": c("La tour blanche reste active plutôt que passive : l'échec gagne un temps précieux pour repositionner le roi.", "White's rook stays active rather than passive: the check wins a precious tempo to reposition the king."),
                 "critical": True},
                "Kf3",
                {"san": "Re1",
                 "comment": c("La tour trouve une case sûre depuis laquelle rien ne la dérange. Nulle vérifiée : aucune tentative noire testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "The rook finds a safe square where nothing bothers it. Verified draw: no Black try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "wrong-square-mates", "title": c("La mauvaise case se fait mater", "The wrong square gets mated")},
            "moves": [
                "Bd3",
                {"san": "Ra7", "role": "trap",
                 "comment": c("Une case qui semble tout aussi raisonnable que e7 — la tour reste active sur la 7e rangée. Mais elle abandonne la colonne b à son sort.",
                              "A square that looks just as reasonable as e7 — the rook stays active on the 7th rank. But it abandons the b-file to its fate."),
                 "critical": True},
                {"san": "Rb1#",
                 "comment": c("Mat immédiat : le roi blanc, coincé sur d1 entre son propre camp et l'absence de case de fuite, ne peut plus rien faire. La différence entre nulle et mat en un coup tenait à UNE case de tour.",
                              "Immediate mate: White's king, stuck on d1 with no flight square, can do nothing more. The difference between a draw and mate in one came down to ONE rook square."),
                 "critical": True},
            ],
        },
    ],
}
