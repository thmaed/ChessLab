# -*- coding: utf-8 -*-
"""La règle du carré — attraper (ou non) un pion qui court.

Racine choisie pour son verdict tranché : DEUX portes d'entrée dans le carré
(e4 et e5), tout le reste perd. Vérifié à la tablebase, comme chaque ligne.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-square-rule",
    "name": "The Rule of the Square",
    "side": "black",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/8/8/P4k2/8/8/7K b - - 0 1",
    "summary": c(
        "Un pion court, votre roi est loin : faut-il courir, ou abandonner la course ? La règle du carré répond d'un COUP D'ŒIL, sans calculer — et montre que la diagonale du roi va aussi vite que la ligne droite.",
        "A pawn is running and your king is far away: chase it, or give up the race? The rule of the square answers AT A GLANCE, no counting — and shows that the king's diagonal is as fast as the straight line.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Entrer dans le carré", "Stepping into the square")},
            "moves": [
                {"san": "Ke4",
                 "comment": c("Tracez le carré : du pion a4 jusqu'à la rangée de promotion, soit a4-a8-e8-e4. Le roi ENTRE dans le carré, donc il attrape le pion — c'est tout le théorème, et il s'applique d'un regard, sans compter les temps.",
                              "Draw the square: from the a4-pawn to the promotion rank, a4-a8-e8-e4. The king STEPS INTO the square, therefore he catches the pawn — that is the whole theorem, applied at a glance, no tempo-counting."),
                 "critical": True},
                "a5",
                {"san": "Kd5",
                 "comment": c("À chaque poussée, le carré rétrécit — et le roi y reste. Remarquez la trajectoire : il vise le pion ET la case de promotion à la fois.",
                              "With every push the square shrinks — and the king stays inside it. Note the path: he aims at the pawn AND the promotion square at once.")},
                "a6", "Kc6", "a7",
                {"san": "Kb7",
                 "comment": c("Arrivé. Le pion est cloué à une case du but, le roi blanc n'a jamais existé dans cette histoire.",
                              "Made it. The pawn is pinned one square from glory; the white king never existed in this story.")},
                "a8=Q+",
                {"san": "Kxa8",
                 "comment": c("Même la promotion ne sauve rien : la dame naît prise. Roi contre roi, nulle.",
                              "Even promoting saves nothing: the queen is born captured. King versus king, draw.")},
            ],
        },
        {
            "chapter": {"id": "diagonal", "title": c("La diagonale va aussi vite", "The diagonal is just as fast")},
            "moves": [
                {"san": "Ke5",
                 "comment": c("L'autre porte. Aux échecs, la diagonale ne coûte PAS plus cher que la ligne droite : e5-d6-c7-b7, quatre temps, comme par e4. C'est la géométrie du roi — celle qui rend possible l'étude de Réti.",
                              "The other door. On the chessboard the diagonal costs NO more than the straight line: e5-d6-c7-b7, four tempi, same as via e4. That is king geometry — the very fact that makes the Réti study possible."),
                 "critical": True},
                "a5", "Kd6", "a6", "Kc7",
                {"san": "a7"},
                {"san": "Kb7",
                 "comment": c("Le pion est arrêté net ; il tombera au prochain coup. La course était perdue pour lui dès l'entrée du roi dans le carré.",
                              "The pawn is stopped dead and falls next move. The race was lost for it the moment the king entered the square.")},
            ],
        },
        {
            "chapter": {"id": "outside", "title": c("Un pas dehors, et tout est perdu", "One step outside, and all is lost")},
            "moves": [
                {"san": "Kg4", "role": "trap",
                 "comment": c("Un seul pas du mauvais côté — vers le pion mais HORS du carré — et la course est mathématiquement perdue. Le réflexe « je fonce » ne remplace pas le coup d'œil.",
                              "One step the wrong way — towards the pawn but OUTSIDE the square — and the race is mathematically lost. The “just run” reflex is no substitute for the glance."),
                 "critical": True},
                "a5", "Kf5", "a6", "Ke6", "a7", "Kd7",
                {"san": "a8=Q",
                 "comment": c("Le roi meurt à une case du but : il a toujours eu exactement UN temps de retard — celui du premier coup.",
                              "The king dies one square short: he was always exactly ONE tempo late — the tempo of that first move.")},
            ],
        },
    ],
}
