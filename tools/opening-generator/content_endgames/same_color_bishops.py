# -*- coding: utf-8 -*-
"""Fou + pion contre fou (même couleur) — la nulle du roi bien placé.

Position construite et vérifiée depuis zéro (aucune position de manuel
recopiée) : roi défenseur devant le pion, fou de la même couleur que
l'attaquant, à bonne distance. Chaque tentative blanche vérifiée : nulle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-same-color-bishops",
    "name": "Same-Coloured Bishops: Fortress",
    "side": "black",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "6B1/3k4/8/3P4/8/7b/8/4K3 w - - 0 1",
    "summary": c(
        "Fous de MÊME couleur, contrairement aux fous de couleurs opposées, ne rendent pas la nulle automatique — le camp fort a de vraies chances. Mais un roi défenseur devant son pion, épaulé par le bon fou, tient une forteresse que rien n'entame.",
        "SAME-coloured bishops, unlike opposite-coloured ones, don't hand the draw automatically — the stronger side has real winning chances. But a defending king in front of his own pawn's path, backed by the right bishop, holds a fortress nothing can crack.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress", "title": c("Le roi devant, et rien ne passe", "The king in front, and nothing gets through")},
            "moves": [
                {"san": "Be6+",
                 "comment": c("Le fou blanc tente de déloger le roi noir de sa case de contrôle — un échec qui a l'air de gagner un temps.",
                              "White's bishop tries to evict the black king from his controlling square — a check that looks like it gains a tempo."),
                 "critical": True},
                {"san": "Kd6",
                 "comment": c("Le roi noir ne cède qu'une case, toujours devant le pion, toujours maître de la case de promotion.",
                              "Black's king yields only one square, still in front of the pawn, still master of the queening square.")},
                {"san": "Bg8",
                 "comment": c("Le fou blanc doit reculer — il n'a nulle part où aller qui menace quoi que ce soit de nouveau.",
                              "White's bishop must retreat — there is nowhere to go that threatens anything new.")},
                {"san": "Kd7",
                 "comment": c("Et nous voilà revenus EXACTEMENT à la position de départ. Retenez le duo qui tient cette forteresse : le roi devant le pion, le fou qui ne le lâche jamais des yeux.",
                              "And we are back EXACTLY where we started. Remember the pair that holds this fortress: the king in front of the pawn, the bishop that never loses sight of it."),
                 "critical": True},
            ],
        },
    ],
}
