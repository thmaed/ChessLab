# -*- coding: utf-8 -*-
"""La défense du petit côté — où mettre son roi quand Philidor est trop tard.

Position d'après Tarrasch (1906), recoupée sur Wikipédia. Deux ingrédients
vérifiés séparément à la tablebase : le roi défenseur du BON côté, ET la
tour à distance de contrôle suffisante (confirmé : 4 colonnes tiennent,
3 perdent déjà).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-short-side-defence",
    "name": "Short-Side Defence",
    "side": "black",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "4K3/4P1k1/8/8/8/8/r7/5R2 b - - 0 1",
    "summary": c(
        "Le pion est déjà en 7e rangée, la position de Philidor n'a jamais été prise : tout n'est pas perdu. Le roi défenseur file du PETIT côté, la tour tient sa distance — et les échecs, cette fois, ne servent pas à empêcher la promotion mais à croquer le pion.",
        "The pawn already stands on the 7th, Philidor's position was never taken: not all is lost. The defending king runs to the SHORT side, the rook keeps its distance — and this time the checks aren't there to stop promotion, they're there to eat the pawn.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le petit côté, et la tour au loin", "The short side, and the far rook")},
            "moves": [
                {"san": "Ra8+",
                 "comment": c("Le roi noir est déjà où il faut — côté g, le petit côté — et la tour est déjà où il faut : quatre colonnes de recul (a, loin du pion e). Sur a6 (le GRAND côté), la même recette perd : le roi blanc y trouve la place de s'abriter des échecs et d'escorter son pion. Il ne reste qu'à pousser, encore et encore.",
                              "The black king is already where it belongs — the g-side, the short side — and the rook is already where it belongs: four files back (a, far from the e-pawn). On a6 (the LONG side), the same recipe loses: the white king finds room to shelter from checks and escort his pawn. All that's left is to push, again and again."),
                 "critical": True},
                {"san": "Kd7", "comment": c("Fuir vers le pion ne le protège pas davantage — au contraire, il s'en écarte.",
                                             "Fleeing toward the pawn doesn't shield it further — if anything, the king drifts from it.")},
                {"san": "Ra7+",
                 "comment": c("Toujours la même distance, toujours le même harcèlement.",
                              "Always the same distance, always the same harassment.")},
                "Kc6",
                {"san": "Rxe7",
                 "comment": c("Le roi vient de lâcher son pion pour de bon — plus personne ne le défend. La tour n'attendait que ça : elle le CROQUE, elle ne le contourne pas.",
                              "The king has finally let go of his pawn — nobody defends it anymore. The rook was waiting for exactly this: it EATS the pawn, it doesn't tiptoe around it."),
                 "critical": True},
                {"san": "Kb5",
                 "comment": c("Tour et roi contre roi : la nulle la plus sèche qui soit, obtenue par un festin plutôt qu'une forteresse.",
                              "Rook and king versus king: the driest draw there is, won by a feast rather than a fortress.")},
            ],
        },
    ],
}
