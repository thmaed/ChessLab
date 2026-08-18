# -*- coding: utf-8 -*-
"""La défense de la 2e rangée — la tour reste sur son terrain.

Contre tour et fou, deuxième grande méthode défensive connue à côté du
clouage Cochrane : la tour défenseur reste sur sa propre 2e rangée
(7e pour les noirs), hors de portée du roi adverse, et n'a jamais besoin
d'aller vérifier ce qui se passe ailleurs. Racine à 5 pièces, chaque choix
noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-second-rank-defence",
    "name": "The Second-Rank Defence",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "6k1/1r6/8/3K4/3B4/8/8/4R3 w - - 0 1",
    "summary": c(
        "Deuxième grande méthode contre tour et fou, à côté du clouage Cochrane : la tour défenseur reste sur sa propre 7e rangée, hors de portée du roi blanc, et se contente d'y naviguer d'un bout à l'autre.",
        "The second major method against rook and bishop, alongside the Cochrane pin: the defending rook stays on its own 7th rank, out of the attacking king's reach, and simply shuttles along it.",
    ),
    "lines": [
        {
            "chapter": {"id": "stay-on-the-rank", "title": c("Rester sur sa rangée, loin du roi", "Stay on your own rank, away from the king")},
            "moves": [
                {"san": "Kc6", "comment": c("Le roi blanc s'approche pour préparer une infiltration.", "White's king approaches to prepare an infiltration.")},
                {"san": "Rh7",
                 "comment": c("La tour noire glisse vers l'aile opposée sans jamais quitter la 7e rangée — le roi blanc, si près pourtant, ne peut toujours pas l'atteindre. Nulle vérifiée : aucune tentative blanche testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Black's rook slides to the far side without ever leaving the 7th rank — White's king, so close, still can't reach it. Verified draw: no White try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "leave-the-rank", "title": c("Quitter sa rangée, perdre la tour", "Leaving your rank loses the rook")},
            "moves": [
                "Kc6",
                {"san": "Rd7", "role": "trap",
                 "comment": c("Semble actif — venir gêner le roi blanc de près. Mais quitter la 7e rangée amène la tour à portée immédiate du roi adverse.",
                              "Looks active — come bother White's king up close. But leaving the 7th rank brings the rook within the enemy king's immediate reach."),
                 "critical": True},
                {"san": "Kxd7",
                 "comment": c("Le roi blanc la croque tout simplement. Le principe de la 2e rangée existe précisément pour éviter ce genre d'accident : rester à distance, toujours.",
                              "White's king simply grabs it. The second-rank principle exists precisely to avoid this kind of accident: always keep your distance."),
                 "critical": True},
            ],
        },
    ],
}
