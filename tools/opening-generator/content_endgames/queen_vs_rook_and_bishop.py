# -*- coding: utf-8 -*-
"""Dame contre tour et fou — le triangle qui protège, le roi qui s'égare.

Sans pion : la dame l'emporte en général sur tour+fou en les divisant par
des échecs à distance et le zugzwang, SAUF si les trois pièces noires
restent groupées au centre, chacune protégée par une autre. Racine à
5 pièces, chaque choix noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-rook-and-bishop",
    "name": "Queen vs Rook and Bishop",
    "side": "black",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "4b1r1/5k2/8/2Q5/4K3/8/8/8 w - - 0 1",
    "summary": c(
        "Sans pion, la dame gagne en général contre tour et fou — en les séparant par des échecs à distance jusqu'au zugzwang. La parade : garder les trois pièces noires groupées, chacune protégée par une autre, un triangle que la dame ne peut jamais fissurer seule.",
        "Without pawns, the queen usually wins against rook and bishop — by splitting them apart with long-distance checks until zugzwang. The defence: keep all three Black pieces bunched together, each protecting another — a triangle the queen alone can never crack.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-triangle-holds", "title": c("Le triangle tient", "The triangle holds")},
            "moves": [
                {"san": "Qh5+", "comment": c("Échec à distance — la méthode habituelle pour chercher à séparer les pièces noires.", "A long-distance check — the usual method for trying to split Black's pieces apart.")},
                {"san": "Kf8",
                 "comment": c("Le roi noir reste collé à sa tour et à son fou — le triangle roi-tour-fou ne se brise pas. Nulle vérifiée : aucune tentative blanche testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Black's king stays glued to its rook and bishop — the king-rook-bishop triangle doesn't break. Verified draw: no White try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "the-king-wanders", "title": c("Le roi s'éloigne, le triangle se brise", "The king wanders off, the triangle breaks")},
            "moves": [
                "Qh5+",
                {"san": "Ke6", "role": "trap",
                 "comment": c("Une case qui semble tout aussi défendable — le roi avance au lieu de reculer. Mais il abandonne la protection de sa tour au passage.",
                              "A square that looks just as defensible — the king advances instead of retreating. But it abandons the protection of its rook along the way."),
                 "critical": True},
                {"san": "Qd5+",
                 "comment": c("Nouvel échec, qui pousse le roi encore plus loin de ses pièces.", "Another check, pushing the king even further from its pieces."),
                 "critical": True},
                "Kf6",
                {"san": "Qxg8",
                 "comment": c("La dame croque la tour, désormais hors de portée de toute protection. Le triangle rompu, il ne restait plus rien pour l'arrêter.",
                              "The queen grabs the rook, now beyond any protection. With the triangle broken, nothing was left to stop it."),
                 "critical": True},
            ],
        },
    ],
}
