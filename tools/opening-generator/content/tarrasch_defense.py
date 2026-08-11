# -*- coding: utf-8 -*-
"""Défense Tarrasch (1.d4 d5 2.c4 e6 3.Cc3 c5) — NOIR.

On accepte un pion dame isolé contre une activité de pièces maximale et un jeu
facile à comprendre. Arbre : fianchetto principal, gambit Schara-Hennig
(4…cxd4), et l'avance …c4. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "tarrasch-defense",
    "name": "Tarrasch Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["D32", "D34"],
    "summary": c(
        "La défense de l'activité : …c5 tout de suite, on assume un pion dame isolé en échange de pièces libres et d'un plan limpide. La réponse la plus dynamique au gambit dame.",
        "The defence of activity: …c5 at once, accepting an isolated queen's pawn in exchange for free pieces and a crystal-clear plan. The most dynamic answer to the Queen's Gambit.",
    ),
    "lines": [
        # 1) Fianchetto principal (Rubinstein)
        {
            "chapter": {"id": "fianchetto", "title": c("Fianchetto principal", "Main Fianchetto")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3",
                {"san": "c5", "eco": "Tarrasch Defense",
                 "comment": c("Le coup Tarrasch : …c5 défie d4 d'emblée, quitte à jouer avec un pion isolé.",
                              "The Tarrasch move: …c5 challenges d4 at once, even at the cost of an isolated pawn.")},
                "cxd5", "exd5", "Nf3", "Nc6",
                {"san": "g3", "comment": c("Le plan Rubinstein : Fg2 pour pilonner le pion isolé d5 sur la grande diagonale.",
                                           "The Rubinstein plan: Bg2 to pound the isolated d5 pawn along the long diagonal.")},
                "Nf6", "Bg2", "Be7", "O-O", "O-O", "Bg5", "cxd4", "Nxd4", "h6", "Be3", "Re8",
            ],
        },
        # 2) Gambit Schara-Hennig (4…cxd4)
        {
            "chapter": {"id": "schara-hennig", "title": c("Gambit Schara-Hennig", "Schara-Hennig Gambit")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "c5", "cxd5",
                {"san": "cxd4", "comment": c("Le gambit Schara-Hennig : au lieu de reprendre en d5, on offre un pion pour un développement fulgurant.",
                                             "The Schara-Hennig Gambit: instead of recapturing on d5, offer a pawn for rapid development.")},
                "Qxd4", "Nc6", "Qd1", "exd5", "Qxd5", "Bd7", "Nf3", "Nf6", "Qd1", "Bc5",
            ],
        },
        # 3) L'avance …c4
        {
            "chapter": {"id": "advance-c4", "title": c("L'avance …c4", "The …c4 advance")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "c5", "cxd5", "exd5", "Nf3", "Nc6", "g3",
                {"san": "c4", "comment": c("On pousse …c4 : on renonce à l'isolé pour gagner de l'espace à l'aile dame.",
                                           "Push …c4: give up the isolani for queenside space.")},
                "Bg2", "Bb4", "O-O", "Nge7", "Ne5", "Bxc3", "bxc3", "O-O",
            ],
        },
    ],
}
