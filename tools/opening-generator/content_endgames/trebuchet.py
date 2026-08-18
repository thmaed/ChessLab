# -*- coding: utf-8 -*-
"""Le trébuchet — la zugzwang mutuelle la plus pure du jeu.

Racine trouvée par recherche systématique (aucune position de manuel n'était
vérifiable telle quelle) : rois à distance de cavalier, chacun devant son
pion. Vérifié : LA MÊME position perd pour le camp au trait, quel qu'il
soit — la définition même du trébuchet.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-trebuchet",
    "name": "The Trebuchet",
    "side": "black",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "8/8/8/3Kp3/4Pk2/8/8/8 w - - 0 1",
    "summary": c(
        "Une position parfaitement symétrique, et pourtant personne ne veut jouer : ici, avoir le trait est une malédiction — la MÊME position, trait inversé, ferait perdre l'autre camp. Le trébuchet est la forme la plus pure du zugzwang.",
        "A perfectly symmetric position, and yet nobody wants to move: having the move is a curse — the SAME position with the other side to move would sink the other camp instead. The trebuchet is zugzwang in its purest form.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Qui bouge perd", "Whoever moves loses")},
            "moves": [
                {"san": "Kc6",
                 "comment": c("Les Blancs ont le trait — et c'est déjà perdu. Le pion e4 ne peut pas avancer (bloqué), la seule chose à jouer est le roi, et TOUT coup de roi abandonne soit la garde du pion, soit la surveillance du pion noir. Kc6 lâche le pion e4.",
                              "White has the move — and that alone is lost. The e4 pawn cannot advance (blocked), the only thing to play is the king, and EVERY king move gives up either the guard on his own pawn or the watch on Black's. Kc6 lets go of e4."),
                 "critical": True},
                {"san": "Kxe4",
                 "comment": c("Le pion tombe, et le pion noir n'a plus personne devant lui. La partie est jouée : un pion libre, un roi qui l'escorte, l'autre roi trop loin pour revenir.",
                              "The pawn falls, and Black's pawn has nobody left in front of it. The game is decided: a free pawn, a king escorting it, the other king too far to get back."),
                 "critical": True},
                "Kb5",
                {"san": "Kd3", "comment": c("Le roi blanc tente de revenir — trop tard, il lui manque des temps qu'il n'a plus.",
                                            "The white king tries to come back — too late, he is short of tempi he no longer has.")},
                "Ka4", "e4", "Ka3", "e3", "Ka4", "e2", "Kb5",
                {"san": "e1=Q",
                 "comment": c("Une dame surgit à l'autre bout de l'échiquier, sans jamais avoir été inquiétée. C'est le sort scellé au tout premier coup, celui qui n'avait pourtant rien de mauvais — sauf d'exister.",
                              "A queen appears at the far end of the board, never once threatened. Sealed on the very first move — a move that was not even bad, except for existing.")},
            ],
        },
        {
            "chapter": {"id": "other-side", "title": c("L'autre défense, même verdict", "The other defence, same verdict")},
            "moves": [
                {"san": "Ke6",
                 "comment": c("L'autre façon de céder : le roi blanc s'écarte par l'autre aile. Le résultat est identique — il n'existe AUCUNE case qui garde tout à la fois.",
                              "The other way to yield: the white king steps aside on the other wing. The result is identical — NO square keeps everything at once."),
                 "critical": True},
                {"san": "Kxe4"},
                "Kd6", "Kd4", "Kc6", "e4", "Kd6", "e3", "Ke6",
                {"san": "e2",
                 "comment": c("Même chemin, même issue. Le trébuchet ne connaît qu'une variable — qui doit jouer — et elle seule décide de tout.",
                              "Same road, same ending. The trebuchet has exactly one variable — whose move it is — and it alone decides everything.")},
            ],
        },
    ],
}
