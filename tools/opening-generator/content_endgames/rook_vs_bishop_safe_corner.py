# -*- coding: utf-8 -*-
"""Tour contre fou — même le bon coin résiste à tout, y compris la capture.

Sourcé Wikipédia (« Fortress (chess) ») : le roi défenseur dans le coin de
la couleur OPPOSÉE à celle du fou forme une forteresse imprenable — au
point que le camp fort ne peut même pas gagner le fou par la force.
Racine à 4 pièces, chaque tentative blanche tranchée par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-bishop-safe-corner",
    "name": "Rook vs Bishop — the Safe Corner",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "2R3bk/8/6K1/8/8/8/8/8 w - - 0 1",
    "summary": c(
        "Roi et fou coincés dans l'angle — mais c'est le BON coin, celui de la couleur opposée au fou. La tour a beau s'approcher, revenir, même croquer le fou : rien n'y fait, la position retombe toujours sur la même forteresse.",
        "King and bishop squeezed into the corner — but it's the RIGHT corner, the one opposite the bishop's colour. The rook can approach, come back, even gobble the bishop: nothing works, the position always lands back on the same fortress.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress-loop", "title": c("La forteresse qui boucle sur elle-même", "The fortress that loops back on itself")},
            "moves": [
                {"san": "Rc1",
                 "comment": c("La tour quitte la 8e rangée : y rester clouerait le fou contre son propre roi (Tc8-Rh8 sur la même rangée) et le priverait de tout coup — pat immédiat. Il faut donc laisser une soupape au fou pour continuer à espérer.",
                              "The rook leaves the 8th rank: staying there would pin the bishop against its own king (Rc8-Kh8 on the same rank) and leave it no move at all — instant stalemate. So a safety valve for the bishop has to stay open to keep hoping."),
                 "critical": True},
                {"san": "Be6", "comment": c("Le fou se dégourdit, sans jamais quitter la diagonale qui protège son roi.", "The bishop stretches its legs, without ever leaving the diagonal that shields its king.")},
                {"san": "Rc8+",
                 "comment": c("La tour revient à la charge — en vain : le roi noir n'a nulle part où aller (g7 et h7 sont tenus par le roi blanc, g8 par son propre fou), mais le fou peut toujours intercepter.",
                              "The rook comes back for another try — in vain: Black's king has nowhere to go (g7 and h7 are held by White's king, g8 by its own bishop), but the bishop can always step in."),
                 "critical": True},
                {"san": "Bg8",
                 "comment": c("Et l'on retombe EXACTEMENT sur la position de départ. La boucle est la preuve : quoi que tente le camp fort, rien ne progresse jamais d'un pouce.",
                              "And we land EXACTLY back on the starting position. The loop is the proof: whatever the strong side tries, nothing ever moves an inch."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "grab-the-bishop", "title": c("Prendre le fou tout de suite ?", "Grab the bishop right away?")},
            "moves": [
                {"san": "Rxg8+",
                 "comment": c("Tentant : le fou semble tomber tout cuit. Mais le roi blanc, sur g6, ne défend pas g8 — la tour s'y jette sans protection.",
                              "Tempting: the bishop looks ripe for the taking. But White's king, on g6, doesn't defend g8 — the rook walks in there with no protection."),
                 "critical": True},
                {"san": "Kxg8",
                 "comment": c("Le roi noir reprend, et il ne reste plus une seule pièce sur l'échiquier à part les deux rois. Nulle instantanée, matériel insuffisant des deux côtés — capturer le fou a capturé la tour avec.",
                              "Black's king recaptures, and not a single piece is left on the board besides the two kings. Instant draw, insufficient material on both sides — capturing the bishop cost the rook right back."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "direct-approach", "title": c("L'approche directe : pat immédiat", "The direct approach: instant stalemate")},
            "moves": [
                {"san": "Kh6",
                 "comment": c("Le roi blanc se rapproche encore — et se heurte tout de suite au mur : le roi noir n'a aucune case (g7 et h7 tenus, g8 occupé), et le fou, cloué sur la 8e rangée entre la tour et son propre roi, ne peut pas bouger non plus. Pat immédiat.",
                              "White's king edges closer still — and hits the wall at once: Black's king has no square (g7 and h7 are held, g8 is occupied), and the bishop, pinned on the 8th rank between the rook and its own king, cannot move either. Immediate stalemate."),
                 "critical": True},
            ],
        },
    ],
}
