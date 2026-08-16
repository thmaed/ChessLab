# -*- coding: utf-8 -*-
"""Gambit Budapest (1.d4 Cf6 2.c4 e5) — NOIR.

On offre e5 pour un développement rapide et des pièces actives ; le cavalier
récupère le pion depuis g4 ou e4. Arbre : Rubinstein 3.dxe5 Cg4 4.Cf3, la
critique 4.Ff4, et la Fajarowicz 3…Ce4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "budapest-gambit",
    "name": "Budapest Gambit",
    "side": "black",
    "level": "club",
    "eco": ["A51", "A52"],
    "summary": c(
        "Un gambit sain et joueur : on rend e5 tout de suite mais on obtient des pièces actives, des cavaliers baladeurs et des pièges tactiques bien réels. Idéal en club.",
        "A sound, fun gambit: give e5 back at once but get active pieces, hopping knights and very real tactical traps. Ideal at club level.",
    ),
    "lines": [
        # 1) Rubinstein — 3.dxe5 Cg4 4.Cf3
        {
            "chapter": {"id": "rubinstein", "title": c("Rubinstein — 3.dxe5 Cg4 4.Cf3", "Rubinstein — 3.dxe5 Ng4 4.Nf3")},
            "moves": [
                "d4", "Nf6", "c4",
                {"san": "e5", "eco": "Budapest Gambit",
                 "comment": c("Le gambit Budapest : on offre e5 pour un développement rapide et un jeu de pièces actif.",
                              "The Budapest Gambit: offer e5 for fast development and active piece play.")},
                "dxe5",
                {"san": "Ng4", "comment": c("Le cavalier file en g4 : il reprendra e5 et vise déjà f2/e3.",
                                            "The knight leaps to g4: it will regain e5 and already eyes f2/e3.")},
                "Nf3", "Bc5", "e3", "Nc6", "Be2", "Ngxe5", "Nxe5", "Nxe5", "O-O", "O-O",
            ],
        },
        # 2) 4.Ff4 (critique)
        {
            "chapter": {"id": "bf4", "title": c("4.Ff4 (critique)", "4.Bf4 (critical)")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5", "Ng4",
                {"san": "Bf4", "comment": c("Les Blancs défendent e5 par Ff4 ; les Noirs clouent par …Fb4+ et récupèrent le pion.",
                                            "White holds e5 with Bf4; Black pins with …Bb4+ and regains the pawn.")},
                "Nc6", "Nf3", "Bb4+", "Nbd2", "Qe7", "a3", "Ngxe5", "Nxe5", "Nxe5",
            ],
        },
        # 3) Fajarowicz — 3…Ce4
        {
            "chapter": {"id": "fajarowicz", "title": c("Fajarowicz — 3…Ce4", "Fajarowicz — 3…Ne4")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5",
                {"san": "Ne4", "comment": c("La Fajarowicz : le cavalier saute en e4 au lieu de g4, pour un jeu plus positionnel et piégeux.",
                                            "The Fajarowicz: the knight jumps to e4 instead of g4, for more positional, trap-laden play.")},
                "Nd2", "Nc5", "Ngf3", "Nc6", "g3", "Qe7", "Bg2", "g6",
            ],
        },

        # ── Quand le gambit n'est pas possible (16/08) ────────────────────────
        #
        # Le Budapest EST 1.d4 Cf6 2.c4 e5. Sans c4, il n'existe pas : le
        # signaler vaut mieux que laisser l'élève chercher un coup qui n'a plus
        # de sens.
        {
            "chapter": {"id": "no-c4", "title": c("Si les Blancs ne jouent pas c4", "If White doesn't play c4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Nf3",
                 "comment": c("Pas de c4, donc pas de Budapest : …e5 ne serait plus un gambit mais une faute. On développe normalement et l'on attend c4.",
                              "No c4, so no Budapest: …e5 would no longer be a gambit but a mistake. We develop normally and wait for c4."),
                 "critical": True},
                "e6", "c4",
                {"san": "d5",
                 "comment": c("c4 est arrivé trop tard pour le gambit — on est dans un Gambit Dame refusé, position saine et parfaitement jouable.",
                              "c4 came too late for the gambit — we're in a Queen's Gambit Declined, a sound and perfectly playable position.")},
                "Bg5", "dxc4", "Qa4+", "Nbd7",
            ],
        },
    ],
}
