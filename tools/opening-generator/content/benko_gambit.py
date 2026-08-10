# -*- coding: utf-8 -*-
"""Gambit Benko / Volga (1.d4 Cf6 2.c4 c5 3.d5 b5) — répertoire NOIR."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "benko-gambit",
    "name": "Benko Gambit",
    "side": "black",
    "level": "advanced",
    "eco": ["A57", "A59"],
    "summary": c(
        "Un pion sacrifié pour une pression permanente à l'aile dame : colonnes a et b ouvertes, fou en g7 sur la grande diagonale. La compensation dure jusqu'en finale.",
        "A pawn sacrificed for permanent queenside pressure: open a- and b-files, the g7 bishop on the long diagonal. The compensation lasts into the endgame.",
    ),
    "lines": [
        {
            "chapter": {"id": "accepted", "title": c("Gambit accepté", "Fully Accepted")},
            "moves": [
                "d4", "Nf6", "c4", "c5",
                {"san": "d5", "comment": c("Les Blancs avancent ; les Noirs vont miner la base c4/d5 par …b5.",
                                           "White pushes; Black will undermine the c4/d5 base with …b5.")},
                {"san": "b5", "eco": "Benko Gambit", "critical": True,
                 "comment": c("Le gambit Benko : on offre b5 pour ouvrir les colonnes a et b.",
                              "The Benko Gambit: offering b5 to open the a- and b-files.")},
                "cxb5", "a6", "bxa6", "Bxa6",
                {"san": "Nc3", "comment": c("Le fou a6 gêne le développement du fou f1 : c'est tout le sel du gambit.",
                                            "The a6 bishop hampers White's f1 bishop: that's the essence of the gambit.")},
                "d6", "Nf3", "g6", "g3", "Bg7", "Bg2", "O-O", "O-O", "Nbd7",
            ],
        },
        {
            "chapter": {"id": "declined-nf3", "title": c("Refusé — 4.Cf3", "Declined — 4.Nf3")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "b5",
                {"san": "Nf3", "comment": c("Refuser en développant : les Noirs prennent en c4 et gardent un jeu confortable.",
                                            "Declining by developing: Black takes on c4 and keeps a comfortable game.")},
                "bxc4", "Nc3", "d6", "e4", "g6",
            ],
        },
        {
            "chapter": {"id": "declined-a4", "title": c("Refusé — 4.a4 (Sosonko)", "Declined — 4.a4 (Sosonko)")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "b5",
                {"san": "a4", "comment": c("Les Blancs cherchent à figer l'aile dame. …b4 garde l'espace et un bon jeu.",
                                           "White tries to freeze the queenside. …b4 keeps space and good play.")},
                "b4", "Nbd2", "d6", "e4", "g6",
            ],
        },
    ],
}
