# -*- coding: utf-8 -*-
"""Le mat à la tour — la boîte qui rétrécit.

Ligne principale ENTIÈREMENT DTM-optimale (dérivée de la tablebase) : chaque
coup blanc est le plus court chemin vers le mat, et il se trouve qu'il
raconte exactement la méthode de la boîte.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-mate",
    "name": "The Rook Mate",
    "side": "white",
    "kind": "endgame",
    "family": "mates",
    "level": "club",
    "rootFEN": "8/8/8/4k3/8/8/8/4K2R w - - 0 1",
    "summary": c(
        "Roi et tour contre roi : le mat que tout joueur DOIT savoir forcer, sans pendule qui tourne ni règle des 50 coups qui menace. Une méthode en trois verbes : couper, approcher, rétrécir.",
        "King and rook versus king: the mate every player MUST be able to force, no clock burning, no 50-move rule looming. A method in three verbs: cut, approach, shrink.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Couper, approcher, rétrécir", "Cut, approach, shrink")},
            "moves": [
                {"san": "Rh5+",
                 "comment": c("COUPER : la tour trace une frontière que le roi noir ne franchira plus jamais. Il vit désormais dans une boîte de quatre rangées — elle ne fera que rétrécir.",
                              "CUT: the rook draws a border the black king will never cross again. He now lives in a four-rank box — and it will only ever shrink."),
                 "critical": True},
                "Kd4",
                {"san": "Kd1",
                 "comment": c("APPROCHER : la tour ne peut pas mater seule, et elle n'a pas besoin d'aide pour tenir sa rangée. C'est donc TOUJOURS le roi qui travaille.",
                              "APPROACH: the rook cannot mate alone, and needs no help holding its rank. So it is ALWAYS the king who does the work.")},
                "Kc4",
                {"san": "Ke2", "comment": c("Le roi monte tranquillement — la frontière tient toute seule.",
                                            "The king strolls up — the border holds by itself.")},
                "Kd4", "Kf3", "Kc3",
                {"san": "Rh4",
                 "comment": c("RÉTRÉCIR : dès que le roi noir s'éloigne, la tour avance d'une rangée. La boîte perd un étage — il ne les récupérera jamais.",
                              "SHRINK: the moment the black king steps away, the rook advances one rank. The box loses a floor — he will never get it back."),
                 "critical": True},
                "Kd2",
                {"san": "Rd4+",
                 "comment": c("L'échec qui REPOUSSE : quand les rois se font face, l'échec de tour force le roi noir vers le bord. Roi face à roi d'abord, échec ensuite — dans cet ordre.",
                              "The check that DRIVES: when the kings stand face to face, the rook check forces the black king towards the edge. Kings face to face first, check second — in that order."),
                 "critical": True},
                "Kc2", "Ke2", "Kc3", "Re4",
                {"san": "Kb2", "comment": c("Le roi noir tourne autour de la boîte ; le roi blanc l'escorte, case par case.",
                                            "The black king circles inside his box; the white king shadows him, square by square.")},
                "Kd2", "Kb3", "Rd4", "Kb2", "Rd3",
                {"san": "Ka1",
                 "comment": c("Plus qu'UNE rangée et demie. Regardez bien la fin : elle demande une précision — et une seule.",
                              "One and a half ranks left. Watch the finish closely: it demands one precision — exactly one.")},
                {"san": "Rb3",
                 "comment": c("Le coup d'attente qui évite le pat et confine en colonne a. Le roi noir n'a plus que deux cases : a1 et a2.",
                              "The waiting move that avoids stalemate and confines to the a-file. The black king has two squares left: a1 and a2.")},
                "Ka2", "Kc2", "Ka1",
                {"san": "Ra3#",
                 "comment": c("Rois face à face, échec sur la rangée du bord : le schéma final du mat à la tour, à connaître comme sa poche — c'est lui qu'on vise dès le premier coup.",
                              "Kings face to face, check along the edge rank: the rook mate's final picture, to know like your own pocket — it is what you aim at from move one."),
                 "critical": True},
            ],
        },
    ],
}
