# -*- coding: utf-8 -*-
"""Défense Tarrasch (1.d4 d5 2.c4 e6 3.Cc3 c5) — NOIR.

On accepte un pion dame isolé contre une activité de pièces maximale et un jeu
facile à comprendre. Arbre : fianchetto principal, gambit Schara-Hennig
(4…cxd4), et l'avance …c4. Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Quand les Blancs ne jouent pas c4 (16/08) ─────────────────────────
        #
        # La Tarrasch est l'une des rares défenses dont l'IDÉE survit sans c4 :
        # …c5 frappe le centre quel que soit le système adverse.
        {
            "chapter": {"id": "vs-london", "title": c("Contre la London — 2.Ff4", "vs the London — 2.Bf4")},
            "moves": [
                "d4", "d5",
                {"san": "Bf4",
                 "comment": c("Une partie sur cinq, et le cours partait de 2.c4. Bonne nouvelle : notre coup ne change pas.",
                              "One game in five, and the course started from 2.c4. Good news: our move doesn't change."),
                 "critical": True},
                {"san": "c5", "critical": True,
                 "comment": c("Le coup de la Tarrasch, et il vaut ici aussi : on frappe d4 tout de suite, et le fou parti en f4 ne défend plus b2.",
                              "The Tarrasch move, and it works here too: we hit d4 at once, and the bishop — gone to f4 — no longer defends b2.")},
                "e3", "Nc6", "Nf3", "Nf6",
                {"san": "Bb5",
                 "comment": c("Les Blancs clouent le défenseur de c5. On échange au centre et l'on obtient le pion isolé actif qui est l'âme de la Tarrasch.",
                              "White pins the defender of c5. We trade in the centre and get the active isolated pawn that is the soul of the Tarrasch.")},
                "cxd4", "exd4",
            ],
        },
        {
            "chapter": {"id": "vs-nf3", "title": c("Contre 2.Cf3", "vs 2.Nf3")},
            "moves": [
                "d4", "d5", "Nf3", "e6", "Bf4",
                {"san": "Bd6",
                 "comment": c("On propose l'échange du bon fou blanc : s'il l'accepte, notre structure s'améliore ; s'il recule en g3, il aura perdu un temps.",
                              "We offer to trade White's good bishop: accept and our structure improves, retreat to g3 and a tempo is gone.")},
                "Bg3", "Nf6", "e3", "c5",
            ],
        },
    ],
}
