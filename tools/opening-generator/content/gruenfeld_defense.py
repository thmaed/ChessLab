# -*- coding: utf-8 -*-
"""Défense Grünfeld (1.d4 Cf6 2.c4 g6 3.Cc3 d5) — répertoire NOIR.

Arbre approfondi : variante de l'échange (grand centre → cible), Système russe
4.Cf3+Db3, Fianchetto (5.g3), et le système 4.Ff4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "gruenfeld-defense",
    "name": "Grünfeld Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["D80", "D99"],
    "summary": c(
        "Hypermoderne et tranchante : les Noirs laissent les Blancs prendre un grand centre… pour le prendre à revers par …Fg7, …c5 et la pression sur d4.",
        "Hypermodern and sharp: Black lets White build a big centre… then attacks it from behind with …Bg7, …c5 and pressure on d4.",
    ),
    "lines": [
        # 1) Variante de l'échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3",
                {"san": "d5", "eco": "Grünfeld Defense",
                 "comment": c("Le coup Grünfeld : on frappe le centre au lieu de le fianchetter comme dans l'est-indienne.",
                              "The Grünfeld move: strike the centre instead of just fianchettoing as in the King's Indian.")},
                "cxd5", "Nxd5", "e4", "Nxc3", "bxc3",
                {"san": "Bg7", "comment": c("Le centre blanc est massif mais deviendra une cible : …c5 arrive.",
                                            "White's centre is huge but will become a target: …c5 is coming.")},
                "Bc4", "c5", "Ne2", "Nc6", "Be3", "O-O", "O-O", "Bg4", "f3", "Na5", "Bd3", "cxd4", "cxd4", "Be6",
            ],
        },
        # 2) Système russe — 4.Cf3 & Db3
        {
            "chapter": {"id": "russian", "title": c("Système russe — 4.Cf3 & Db3", "Russian System — 4.Nf3 & Qb3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "d5", "Nf3", "Bg7",
                {"san": "Qb3", "eco": "Grünfeld Defense: Russian Variation",
                 "comment": c("Le Système russe : la dame frappe d5 et b7. Les Noirs prennent en c4 avec du contre-jeu.",
                              "The Russian System: the queen hits d5 and b7. Black takes on c4 with counterplay.")},
                "dxc4", "Qxc4", "O-O", "e4", "a6", "Be2", "b5", "Qb3", "c5", "dxc5", "Qc7",
            ],
        },
        # 3) Fianchetto — 5.g3
        {
            "chapter": {"id": "fianchetto", "title": c("Fianchetto — 5.g3", "Fianchetto — 5.g3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "d5", "cxd5", "Nxd5",
                {"san": "g3", "comment": c("Le fianchetto : les Blancs renoncent au grand centre pour un jeu positionnel autour de d5.",
                                           "The fianchetto: White forgoes the big centre for positional play around d5.")},
                "Bg7", "Bg2", "Nxc3", "bxc3", "c5", "e3", "O-O", "Ne2", "Nc6",
            ],
        },
        # 4) Système 4.Ff4
        {
            "chapter": {"id": "bf4", "title": c("Système 4.Ff4", "4.Bf4 System")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "d5",
                {"san": "Bf4", "comment": c("Un développement tranquille : le fou sort avant e3. Les Noirs frappent quand même par …c5.",
                                            "A quiet development: the bishop comes out before e3. Black still hits with …c5.")},
                "Bg7", "e3", "c5", "dxc5", "Qa5", "Rc1", "dxc4", "Bxc4", "O-O", "Nf3", "Qxc5",
            ],
        },
    ],
}
