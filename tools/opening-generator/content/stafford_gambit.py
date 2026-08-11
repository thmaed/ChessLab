# -*- coding: utf-8 -*-
"""Gambit Stafford (1.e4 e5 2.Cf3 Cf6 3.Cxe5 Cc6) — répertoire NOIR.

Une arme de blitz : objectivement douteuse, mais bourrée de pièges. Ligne
principale d'attaque + le piège classique qui gagne la dame. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "stafford-gambit",
    "name": "Stafford Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C42"],
    "summary": c(
        "Un gambit surprise dans la Petrov : on rend un pion pour un développement fou et des pièges mortels sur f2 et e4. Douteux au fond, redoutable en blitz.",
        "A surprise gambit in the Petrov: give back a pawn for wild development and deadly traps on f2 and e4. Dubious at heart, lethal in blitz.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Attaque principale", "Main attack")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "Nxe5", "comment": c("Les Blancs prennent e5 ; la réponse Stafford est le surprenant …Cc6.",
                                             "White grabs e5; the Stafford reply is the surprising …Nc6.")},
                {"san": "Nc6", "eco": "Russian Game: Stafford Gambit",
                 "comment": c("Le coup Stafford : on offre un pion pour ramener le cavalier et développer à toute vitesse.",
                              "The Stafford move: offer a pawn to bring the knight back and develop at top speed.")},
                "Nxc6", "dxc6", "d3", "Bc5",
                {"san": "Nc3", "comment": c("La bonne défense : on protège e4 (sinon …Cxe4 déclenche la combinaison sur f2).",
                                            "The correct defence: guard e4 (otherwise …Nxe4 unleashes the f2 combination).")},
                "Ng4", "Be3", "Bxe3", "fxe3", "Qh4+", "g3", "Qf6", "Qe2", "Ne5",
            ],
        },
        {
            "chapter": {"id": "trap", "title": c("Piège — Fg5 ?", "Trap — Bg5?")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6", "Nxe5", "Nc6", "Nxc6", "dxc6", "d3", "Bc5",
                {"san": "Bg5", "role": "trap",
                 "comment": c("Le clouage naturel… mais fatal : il tombe sur une combinaison qui gagne la dame.",
                              "The natural pin… but fatal: it runs into a combination that wins the queen.")},
                "Nxe4", "dxe4", "Bxf2+", "Kxf2", "Qxd1",
            ],
        },
    ],
}
