# -*- coding: utf-8 -*-
"""Le roi actif — une seule case décide toute une finale de tours.

Position construite et vérifiée depuis zéro (aucune étude recopiée) : même
matériel, mêmes pions, même tour des deux côtés — le SEUL écart entre les
deux chapitres est une case du roi blanc, e3 contre e2. Volontairement une
finale de PIÈCES (tour), pas une course de rois pure comme l'étude de
Grigoriev (déjà dans le catalogue) : ici le roi ne court pas après un pion,
il pèse sur la position simplement en s'approchant du jeu. Racine à 7
pièces : verdict tranché par l'oracle sur chaque coup blanc (le DTM exact
n'est pas fourni par le serveur à cette taille, mais la catégorie
gain/nulle, elle, est prouvée).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-theme-active-king",
    "name": "The Active King in a Rook Ending",
    "side": "white",
    "kind": "endgame",
    "family": "themes",
    "level": "advanced",
    "rootFEN": "7r/4k3/6p1/8/4P3/5KP1/8/3R4 w - - 0 1",
    "summary": c(
        "Même matériel, mêmes pions, même tour dans les deux chapitres — la SEULE différence est une case du roi blanc. Sur e3, il s'engage vers le jeu et la partie est gagnée. Sur e2, il reste à l'abri et la même partie n'est plus que nulle.",
        "Same material, same pawns, same rook in both chapters — the ONLY difference is one square of the white king. On e3 it commits to the game and the position is won. On e2 it stays sheltered and the very same game is only a draw.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-active-king-wins", "title": c("Un roi qui marche vers l'action", "A king marching toward the action")},
            "moves": [
                {"san": "Ke3",
                 "comment": c("Rien ne force encore ce coup — mais au lieu de se replier vers la sécurité, le roi blanc avance vers le théâtre des opérations, prêt à soutenir le pion e ET à menacer le pion g6. C'est cette activité, et rien d'autre, qui va décider toute la finale.",
                              "Nothing forces this move yet — but instead of retreating to safety, White's king advances toward the theatre of operations, ready to support the e-pawn AND to threaten the g6-pawn. This activity, and nothing else, is what will decide the whole ending."),
                 "critical": True},
                {"san": "Rh3",
                 "comment": c("La tour noire cherche l'activité à son tour, en visant le pion g3.",
                              "Black's rook looks for activity of its own, aiming at the g3-pawn.")},
                {"san": "Kf4",
                 "comment": c("Le roi continue sa marche : il défend g3 au passage, et se rapproche encore du pion g6, qui devient une cible bien réelle. Comparez avec l'autre chapitre — le même roi, resté sur la 2e rangée, ne pourrait jamais faire ça.",
                              "The king keeps marching: it defends g3 along the way, and edges even closer to the g6-pawn, which becomes a genuine target. Compare with the other chapter — the same king, left on the 2nd rank, could never do this."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "the-passive-king-only-draws", "title": c("Le même roi, une case en retrait : la nulle", "The same king, one square back: only a draw")},
            "moves": [
                {"san": "Ke2", "role": "trap",
                 "comment": c("Une seule case de moins, et pourtant tout bascule : le roi reste à l'abri sur la 2e rangée au lieu de s'engager. Aucun coup blanc, à partir d'ici, ne recrée la moindre chance de gain — la tablebase est formelle : ce roi-là, resté passif, ne fait plus que la nulle.",
                              "Just one square less, and yet everything flips: the king stays sheltered on the 2nd rank instead of committing. No White move from here ever recreates a winning chance again — the tablebase is categorical: this king, left passive, only draws now."),
                 "critical": True},
                {"san": "Kf6",
                 "comment": c("Le roi noir n'a même plus besoin de défendre activement : il recentralise tranquillement, certain que la passivité blanche ne posera plus jamais le moindre problème.",
                              "Black's king doesn't even need to defend actively any more: it calmly recentralises, certain that White's passivity will never cause trouble again."),
                 "critical": True},
            ],
        },
    ],
}
