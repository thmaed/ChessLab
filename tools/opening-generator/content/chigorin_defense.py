# -*- coding: utf-8 -*-
"""Défense Chigorin (1.d4 d5 2.c4 Cc6) — NOIR.

Combative et anti-positionnelle : …Cc6 met la pression sur d4 et prépare …e5,
au prix d'un jeu de pièces plutôt que de pions. Arbre : 3.Cc3, 3.cxd5, 3.Cf3.
Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "chigorin-defense",
    "name": "Chigorin Defense",
    "side": "black",
    "level": "club",
    "eco": ["D07"],
    "summary": c(
        "L'anti-Tarrasch : …Cc6 tout de suite, un jeu de PIÈCES contre le centre blanc, quitte à céder la paire de fous. Déséquilibre garanti, peu de théorie forcée.",
        "The anti-Tarrasch: …Nc6 at once, a game of PIECES against White's centre, even if it means giving up the bishop pair. Guaranteed imbalance, little forced theory.",
    ),
    "lines": [
        # 1) 3.Cc3 (principale)
        {
            "chapter": {"id": "nc3", "title": c("3.Cc3", "3.Nc3")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "Nc6", "eco": "Chigorin Defense",
                 "comment": c("Le coup Chigorin : le cavalier presse d4 avant tout, on jouera …e5 et …Fg4.",
                              "The Chigorin move: the knight pressures d4 first; …e5 and …Bg4 will follow.")},
                "Nc3",
                {"san": "dxc4", "comment": c("On prend en c4 pour ouvrir le jeu aux pièces et gagner du temps sur le centre.",
                                             "Take on c4 to open the game for the pieces and gain time on the centre.")},
                "Nf3", "Nf6", "e4", "Bg4", "Be3", "e5", "d5", "Nd4",
            ],
        },
        # 2) 3.cxd5 (échange)
        {
            "chapter": {"id": "exchange", "title": c("3.cxd5", "3.cxd5")},
            "moves": [
                "d4", "d5", "c4", "Nc6",
                {"san": "cxd5", "comment": c("L'échange : après …Dxd5, la dame est bien placée et …e5 arrive vite.",
                                             "The exchange: after …Qxd5 the queen is well placed and …e5 comes quickly.")},
                "Qxd5", "e3", "e5", "Nc3", "Bb4", "Bd2", "Bxc3", "bxc3", "exd4",
            ],
        },
        # 3) 3.Cf3
        {
            "chapter": {"id": "nf3", "title": c("3.Cf3", "3.Nf3")},
            "moves": [
                "d4", "d5", "c4", "Nc6", "Nf3",
                {"san": "Bg4", "comment": c("Le clouage : on échange le fou contre le cavalier f3 pour affaiblir le contrôle blanc de d4/e5.",
                                            "The pin: trade the bishop for the f3-knight to loosen White's grip on d4/e5.")},
                "cxd5", "Bxf3", "gxf3", "Qxd5", "e3", "e5", "Nc3", "Bb4",
            ],
        },
    ],
}
