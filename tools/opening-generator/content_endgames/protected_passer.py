# -*- coding: utf-8 -*-
"""Le pion passé protégé — celui qu'on ne peut jamais toucher.

Un pion défendu par un autre pion : le roi adverse peut s'approcher tant
qu'il veut, il ne pourra jamais le prendre sans laisser l'AUTRE courir seul
jusqu'à la dame. Vérifié : toute tentative, capture ou simple approche,
perd de la même façon.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-protected-passer",
    "name": "The Protected Passed Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/8/1k1P4/2P5/8/4K3/8 b - - 0 1",
    "summary": c(
        "Deux pions valent mieux qu'un — surtout quand l'un défend l'autre. Un pion passé PROTÉGÉ n'est pas seulement un pion de plus : il est intouchable, et le camp faible peut s'épuiser à s'en approcher, le résultat ne changera pas.",
        "Two pawns beat one — especially when one guards the other. A PROTECTED passed pawn isn't just an extra pawn: it's untouchable, and the weaker side can wear itself out approaching it, the result won't change.",
    ),
    "lines": [
        {
            "chapter": {"id": "capture", "title": c("Le prendre ne fait qu'accélérer la fin", "Taking it only hastens the end")},
            "moves": [
                {"san": "Kxc4", "role": "trap",
                 "comment": c("Le réflexe : « je prends ce qui est pris » — sauf que le pion c4 n'était là que pour couvrir d5. Une fois disparu, d5 court tout seul, et le roi noir vient de s'éloigner pour de bon.",
                              "The reflex: “I take what's there for the taking” — except the c4 pawn was only there to guard d5. Once it's gone, d5 runs alone, and Black's king has just wandered off for good."),
                 "critical": True},
                "d6", "Kd4", "d7", "Kd5",
                {"san": "d8=Q+",
                 "comment": c("La dame surgit AVEC échec — le roi noir, occupé à digérer une capture qui ne changeait rien, n'a jamais eu la moindre chance de revenir.",
                              "The queen appears WITH check — Black's king, busy digesting a capture that changed nothing, never had the slightest chance to get back."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "approach", "title": c("Même sans la prendre : perdu pareil", "Even without taking it: lost all the same")},
            "moves": [
                {"san": "Kb4", "role": "trap",
                 "comment": c("Le roi noir se contente d'approcher, sans capturer tout de suite — la nuance ne change rien : dès que les Blancs poussent d6, le pion protecteur c4 n'a plus aucune raison d'être défendu, et la même course recommence.",
                              "Black's king merely approaches, without capturing right away — the nuance changes nothing: the moment White pushes d6, the c4 guard no longer needs protecting, and the same race starts over."),
                 "critical": True},
                "d6",
                {"san": "Kxc4",
                 "comment": c("Il finit par le prendre de toute façon — un temps plus tard, ce qui ne fait qu'aggraver son retard sur le pion d, déjà loin devant.",
                              "He takes it eventually anyway — one tempo later, which only worsens his lag behind the d-pawn, already well ahead.")},
                "d7", "Kd5",
                {"san": "d8=Q+",
                 "comment": c("Retenez l'image, pas la ligne : un pion passé protégé ne se bat pas AU CORPS À CORPS — on l'ignore, on avance ailleurs, et il fait le travail tout seul le moment venu.",
                              "Remember the picture, not the line: a protected passed pawn isn't fought HAND TO HAND — you ignore it, play elsewhere, and it does the job alone when the moment comes."),
                 "critical": True},
            ],
        },
    ],
}
