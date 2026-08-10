# -*- coding: utf-8 -*-
"""Gambit du Roi (1.e4 e5 2.f4) — répertoire BLANC.

Approfondi : moderne 3…d5, Kieseritzky, gambit Muzio, gambit du fou 3.Fc4,
Falkbeer, refusé.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-gambit",
    "name": "King's Gambit",
    "side": "white",
    "level": "advanced",
    "eco": ["C30", "C39"],
    "summary": c(
        "Le gambit romantique par excellence : un pion pour un centre fort, une colonne f ouverte et une attaque immédiate. Du Kieseritzky au sacrifice Muzio, du feu pur.",
        "The romantic gambit par excellence: a pawn for a strong centre, an open f-file and an immediate attack. From the Kieseritzky to the Muzio sacrifice, pure fire.",
    ),
    "lines": [
        {
            "chapter": {"id": "modern", "title": c("Défense moderne — 3…d5", "Modern Defence — 3…d5")},
            "moves": [
                "e4", "e5",
                {"san": "f4", "eco": "King's Gambit",
                 "comment": c("On offre le pion f pour ouvrir la colonne et dominer le centre.",
                              "Offering the f-pawn to open the file and dominate the centre.")},
                "exf4",
                {"san": "Nf3", "comment": c("On empêche …Dh4+ et on développe : le Gambit du Cavalier-Roi.",
                                            "Stopping …Qh4+ and developing: the King's Knight Gambit.")},
                {"san": "d5", "comment": c("La défense moderne, la plus saine : les Noirs rendent le pion pour un jeu clair.",
                                           "The modern, soundest defence: Black gives the pawn back for clear play.")},
                "exd5", "Nf6", "Bc4", "Nxd5", "O-O", "Be7", "d4", "O-O",
            ],
        },
        {
            "chapter": {"id": "kieseritzky", "title": c("Gambit Kieseritzky — 3…g5", "Kieseritzky Gambit — 3…g5")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3",
                {"san": "g5", "comment": c("Les Noirs s'accrochent au pion f4 — la ligne la plus tranchante.",
                                           "Black clings to the f4 pawn — the sharpest line.")},
                {"san": "h4", "comment": c("On frappe la chaîne de pions tout de suite.",
                                           "Striking the pawn chain at once.")},
                "g4",
                {"san": "Ne5", "eco": "King's Gambit Accepted: Kieseritzky Gambit",
                 "comment": c("Le Gambit Kieseritzky : le cavalier plonge en e5, prêt à sacrifier davantage.",
                              "The Kieseritzky Gambit: the knight leaps to e5, ready to sacrifice more.")},
                "Nf6", "d4", "d6", "Nd3", "Nxe4", "Bxf4", "Qe7",
            ],
        },
        {
            "chapter": {"id": "muzio", "title": c("Gambit Muzio — 5.O-O", "Muzio Gambit — 5.O-O")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3", "g5",
                {"san": "Bc4", "comment": c("On développe et on vise f7 avant de sacrifier.",
                                            "Develop and target f7 before sacrificing.")},
                "g4",
                {"san": "O-O", "role": "trap", "critical": True,
                 "eco": "King's Gambit Accepted: Muzio Gambit",
                 "comment": c("Le Gambit Muzio : on abandonne carrément le cavalier f3 pour une attaque dévastatrice sur f7 et le roi.",
                              "The Muzio Gambit: flatly giving up the f3 knight for a devastating attack on f7 and the king.")},
                "gxf3", "Qxf3", "Qf6", "e5", "Qxe5", "d3", "Bh6", "Nc3", "Ne7",
            ],
        },
        {
            "chapter": {"id": "bishops-gambit", "title": c("Gambit du fou — 3.Fc4", "Bishop's Gambit — 3.Bc4")},
            "moves": [
                "e4", "e5", "f4", "exf4",
                {"san": "Bc4", "eco": "King's Gambit Accepted: Bishop's Gambit",
                 "comment": c("Le Gambit du fou : on développe le fou avant le cavalier et on autorise …Dh4+ (pas grave, on joue Rf1).",
                              "The Bishop's Gambit: develop the bishop before the knight and allow …Qh4+ (fine — we play Kf1).")},
                "Qh4+", "Kf1", "d5", "Bxd5", "g5", "Nf3", "Qh5",
            ],
        },
        {
            "chapter": {"id": "falkbeer", "title": c("Contre-gambit Falkbeer — 2…d5", "Falkbeer Counter-gambit — 2…d5")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "d5", "eco": "King's Gambit Declined: Falkbeer Counter-gambit",
                 "comment": c("Le contre-gambit Falkbeer : au lieu de prendre, les Noirs rendent coup pour coup.",
                              "The Falkbeer: instead of taking, Black strikes back blow for blow.")},
                "exd5", "e4",
                {"san": "d3", "comment": c("On mine le pion e4 avancé plutôt que de le laisser gêner le développement.",
                                           "Undermine the advanced e4 pawn rather than let it cramp development.")},
                "Nf6", "dxe4", "Nxe4",
            ],
        },
        {
            "chapter": {"id": "declined", "title": c("Gambit du Roi refusé — 2…Fc5", "King's Gambit Declined — 2…Bc5")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "Bc5", "comment": c("Le refus le plus sûr : le fou en c5 empêche le roque et vise f2.",
                                            "The safest declination: the c5 bishop stops castling and eyes f2.")},
                "Nf3", "d6", "Nc3", "Nf6", "Bc4", "Nc6",
            ],
        },
    ],
}
