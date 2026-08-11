# -*- coding: utf-8 -*-
"""Gambit Englund (1.d4 e5) — répertoire NOIR.

Objectivement douteux, mais un piège de blitz célèbre : la chasse à b2 avec
…Db4+/…Dxb2. À jouer en connaissant la limite : si les Blancs défendent bien,
les Noirs restent un peu moins bien. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "englund-gambit",
    "name": "Englund Gambit",
    "side": "black",
    "level": "club",
    "eco": ["A40"],
    "summary": c(
        "Un pion offert d'entrée pour un jeu de pièges à l'aile dame. Douteux si les Blancs défendent précisément, mais mortel contre un adversaire non prévenu.",
        "A pawn offered right away for queenside trickery. Dubious against precise defence, but lethal against an unwarned opponent.",
    ),
    "lines": [
        {
            "chapter": {"id": "trap", "title": c("Chasse à b2 — …Db4+/…Dxb2", "The b2 hunt — …Qb4+/…Qxb2")},
            "moves": [
                "d4",
                {"san": "e5", "eco": "Englund Gambit",
                 "comment": c("Le gambit Englund : on offre e5 pour tendre des pièges à l'aile dame.",
                              "The Englund Gambit: offer e5 to set queenside traps.")},
                "dxe5", "Nc6", "Nf3", "Qe7", "Bf4", "Qb4+", "Bd2",
                {"san": "Qxb2", "critical": True,
                 "comment": c("On dévore b2 : gare au piège si les Blancs jouent sans soin.",
                              "Gobble b2: beware the trap if White plays carelessly.")},
                "Bc3", "Bb4", "Qd2", "Bxc3", "Nxc3", "Qb4",
            ],
        },
        {
            "chapter": {"id": "solid", "title": c("Refus solide — 3.Cf3", "Solid decline — 3.Nf3")},
            "moves": [
                "d4", "e5", "dxe5", "Nc6", "Nf3",
                {"san": "Qe7", "comment": c("Si les Blancs défendent tranquillement e5, mieux vaut viser sa récupération sans excès.",
                                            "If White defends e5 calmly, aim to regain it without overreaching.")},
                "Bf4", "Qb4+", "Nc3", "Qxb2", "Bd2", "Bb4", "Rb1", "Qa3",
            ],
        },
    ],
}
