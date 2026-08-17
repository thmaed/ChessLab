# -*- coding: utf-8 -*-
"""Le pion-tour, l'exception qui pardonne — K+pion h contre K.

Racine tranchée (vérifiée tablebase) : deux coups tiennent, quatre perdent —
dont le très naturel Kd8, « je reste au centre ».
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-pawn",
    "name": "The Rook's Pawn Exception",
    "side": "black",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/3k4/8/4K3/7P/8/8/8 b - - 0 1",
    "summary": c(
        "Tout ce que « L'opposition » vous a appris a une exception : le pion-tour. Ici le coin est un abri imprenable — le camp faible vise h8 et il n'existe AUCUN moyen de l'en déloger. Encore faut-il y courir tout de suite.",
        "Everything “The Opposition” taught you has one exception: the rook's pawn. Here the corner is an unassailable shelter — the weak side heads for h8 and NOTHING can evict him. Provided he runs there at once.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Courir au coin", "Run to the corner")},
            "moves": [
                {"san": "Ke7",
                 "comment": c("Direction h8, sans détour (Ke8 tient aussi). Contre tout autre pion cette position serait perdante ; contre le pion-tour, le coin sauve — à condition d'y arriver.",
                              "Straight for h8, no detours (Ke8 also holds). Against any other pawn this would be lost; against the rook's pawn the corner saves you — provided you get there."),
                 "critical": True},
                "Kf5",
                {"san": "Kf7",
                 "comment": c("Épaule contre épaule : on ne laisse pas le roi blanc passer DEVANT son pion — c'est son seul espoir, et il ne mène nulle part de toute façon.",
                              "Shoulder to shoulder: don't let the white king get IN FRONT of his pawn — his only hope, and even that leads nowhere.")},
                "h5", "Kg7", "Kg5", "Kh7",
                {"san": "Kf6", "comment": c("Le roi blanc tente le grand tour par f6-g7 ? Voyez comme le coin suffit.",
                                            "The white king tries the grand tour via f6? Watch the corner suffice.")},
                {"san": "Kh8",
                 "comment": c("La forteresse d'une seule case. Retenez l'image : contre un pion-tour, le roi défenseur en h8 ne peut être NI chassé, NI zugzwangé — il oscillera entre h8 et g8 jusqu'à la fin des temps.",
                              "The one-square fortress. Fix the image: against a rook's pawn, the defending king on h8 can be NEITHER evicted NOR zugzwanged — he shuttles between h8 and g8 until the end of time."),
                 "critical": True},
                "Kg6", "Kg8", "h6",
                {"san": "Kh8",
                 "comment": c("Rien à faire : g8 et h8 se valent, et les Blancs n'ont aucun coup d'attente — le pion-tour n'en a pas de côté !",
                              "Nothing works: g8 and h8 are equivalent, and White has no waiting move — the rook's pawn has no spare file!")},
                {"san": "h7", "role": "trap",
                 "comment": c("Le coup qui « gagne »… et fait PAT. La faute est blanche cette fois : voilà pourquoi le camp fort lui-même doit connaître cette finale — pour ne pas la jouer.",
                              "The “winning” push… and it's STALEMATE. The mistake is White's this time: which is why the strong side must know this ending too — so as not to enter it.")},
            ],
        },
        {
            "chapter": {"id": "too-slow", "title": c("Le détour qui perd", "The detour that loses")},
            "moves": [
                {"san": "Kd8", "role": "trap",
                 "comment": c("« Je reste au centre, je verrai bien. » Un seul temps de flânerie et le roi blanc prend l'ÉPAULE : le chemin du coin est coupé pour toujours.",
                              "“I'll stay central and see.” One idling tempo and the white king takes the SHOULDER: the road to the corner is cut forever."),
                 "critical": True},
                {"san": "Kf6",
                 "comment": c("L'épaulée : le roi blanc ne pousse pas son pion, il barre d'abord la route. Comparez avec la ligne principale, où f7 lui était interdit.",
                              "The shoulder-charge: White doesn't push the pawn, he blocks the road first. Compare the main line, where f7 was denied to him.")},
                "Ke8", "Kg7",
                {"san": "Ke7",
                 "comment": c("Trop tard : g8 appartient aux Blancs, le pion n'a plus qu'à marcher.",
                              "Too late: g8 belongs to White, the pawn simply walks.")},
                "h5", "Ke6", "h6", "Kf5", "h7", "Kg5",
                {"san": "h8=Q",
                 "comment": c("Le même pion, la même course — mais un roi défenseur parti UN temps trop tard. Toute la finale tenait dans le premier coup.",
                              "Same pawn, same race — but a defending king that left ONE tempo late. The whole ending lived in the first move.")},
            ],
        },
    ],
}
