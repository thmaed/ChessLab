# -*- coding: utf-8 -*-
"""Gambit Stafford (1.e4 e5 2.Cf3 Cf6 3.Cxe5 Cc6) — répertoire NOIR (piège)."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "stafford-gambit",
    "name": "Stafford Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C42"],
    "summary": c(
        "Douteux mais redoutable en partie rapide : un pion pour un développement fou et une nuée de pièges à f2/e4. À jouer en connaissant les combinaisons.",
        "Objectively dubious but deadly in blitz: a pawn for wild development and a swarm of f2/e4 traps. Play it knowing the combinations.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Idée principale", "Main idea")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "Nxe5", "comment": c("Les Blancs prennent le pion offert…",
                                             "White grabs the offered pawn…")},
                {"san": "Nc6", "eco": "Russian Game: Stafford Gambit", "critical": True,
                 "comment": c("Le gambit Stafford ! On sacrifie e5 pour un développement explosif et des menaces sur f2 et e4.",
                              "The Stafford Gambit! Sacrificing e5 for explosive development and threats on f2 and e4.")},
                "Nxc6", "dxc6",
                {"san": "d3", "comment": c("Le développement le plus sain pour les Blancs — mais il reste des pièges partout.",
                                           "White's soundest setup — yet traps lurk everywhere.")},
                {"san": "Bc5", "comment": c("Le fou vise f2 ; suivront …Cg4, …Dd4 ou …Fg4 avec une attaque directe.",
                                            "The bishop eyes f2; …Ng4, …Qd4 or …Bg4 follow with a direct attack.")},
            ],
        },
        {
            "chapter": {"id": "trap", "title": c("Le piège …Cxe4 / …Fxf2+", "The …Nxe4 / …Bxf2+ trap")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6", "Nxe5", "Nc6", "Nxc6", "dxc6", "d3", "Bc5",
                {"san": "Bg5", "role": "inaccuracy", "critical": True,
                 "comment": c("Un développement naturel… et fatal : il autorise la combinaison type du Stafford.",
                              "A natural developing move… and a fatal one: it allows the Stafford's signature combination.")},
                {"san": "Nxe4", "role": "trap", "critical": True,
                 "comment": c("Le coup à connaître ! Le cavalier se sacrifie pour ouvrir la voie à …Fxf2+.",
                              "The move to know! The knight sacrifices itself to open the way for …Bxf2+.")},
                "dxe4",
                {"san": "Bxf2+", "comment": c("L'estocade : après Rxf2, …Dxd1 gagne la dame.",
                                              "The finishing blow: after Kxf2, …Qxd1 wins the queen.")},
                "Kxf2", "Qxd1",
            ],
        },
    ],
}
