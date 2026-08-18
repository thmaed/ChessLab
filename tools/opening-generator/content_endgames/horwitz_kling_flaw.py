# -*- coding: utf-8 -*-
"""Deux fous contre cavalier — la forteresse de Horwitz-Kling n'existe pas.

Sourcé Horwitz & Kling (1851), corrigé par tablebase : les deux maîtres
pensaient qu'une forteresse défensive existait pour le camp du cavalier.
Elle n'existe pas — c'est un gain général, prouvé jusqu'à 78 coups. La
technique complète est réputée l'une des plus longues et les moins
intuitives de tout l'échiquier ; ce cours montre seulement la décision de
départ qui la lance. Racine à 5 pièces, chaque coup blanc tranché par
l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-horwitz-kling-flaw",
    "name": "The Horwitz-Kling Fortress That Isn't",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "8/8/4k3/8/3n4/8/3K4/2BB4 w - - 0 1",
    "summary": c(
        "Horwitz et Kling pensaient, en 1851, qu'une forteresse existait ici pour le cavalier. Il n'y en a pas — c'est un gain général, confirmé jusqu'à 78 coups par les tables de finales. La technique complète est réputée l'une des plus longues et les moins intuitives qui soient ; ce cours montre seulement le tout premier choix qui la lance.",
        "Horwitz and Kling believed, in 1851, that a fortress existed here for the knight's side. There isn't one — it's a general win, confirmed up to 78 moves by tablebases. The full technique is reputed to be one of the longest and least intuitive in all of chess; this course shows only the very first choice that launches it.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-first-step", "title": c("Le tout premier pas d'une technique de 63 coups", "The very first step of a 63-move technique")},
            "moves": [
                {"san": "Kd3",
                 "comment": c("Le roi blanc s'approche du cavalier — le point de départ d'une technique si longue qu'elle n'a jamais pu être trouvée sans machine avant l'ère des tables de finales. Ce que ce cours retient, c'est seulement ceci : contrairement à ce que croyaient Horwitz et Kling, il N'Y A PAS de case où le camp du cavalier puisse simplement s'installer et tenir.",
                              "White's king approaches the knight — the starting point of a technique so long it could never be found without a machine before the tablebase era. What this course keeps is only this: contrary to what Horwitz and Kling believed, there is NO square where the knight's side can simply settle in and hold."),
                 "critical": True},
                "Kf5",
            ],
        },
        {
            "chapter": {"id": "looks-safe-isnt", "title": c("Une case qui semble sûre ne l'est pas", "A square that looks safe isn't")},
            "moves": [
                {"san": "Bc2", "role": "trap",
                 "comment": c("Un repli de fou qui semble anodin, gardant la maîtrise des cases noires. Et pourtant : la nulle, là où presque tout le reste gagne.",
                              "A bishop retreat that looks harmless, keeping control of the dark squares. And yet: a draw, where almost everything else wins."),
                 "critical": True},
            ],
        },
    ],
}
