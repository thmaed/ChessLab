# -*- coding: utf-8 -*-
"""Défense Bogo-indienne (1.d4 Cf6 2.c4 e6 3.Cf3 Fb4+) — NOIR.

Quand les Blancs jouent 3.Cf3 (pas de Cc3), l'échec …Fb4+ garde l'esprit
Nimzo. Arbre : 4.Fd2 De7 (principale), 4.Cbd2 b6, 4.Fd2 a5. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "bogo-indian",
    "name": "Bogo-Indian Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["E11"],
    "summary": c(
        "La sœur tranquille de la Nimzo-indienne : quand les Blancs évitent Cc3, …Fb4+ garde l'idée de contrôler e4 et d'échanger le fou contre un cavalier. Sûre et sans théorie lourde.",
        "The quiet sister of the Nimzo-Indian: when White avoids Nc3, …Bb4+ keeps the idea of controlling e4 and trading the bishop for a knight. Safe, with little heavy theory.",
    ),
    "lines": [
        # 1) 4.Fd2 De7 (principale)
        {
            "chapter": {"id": "bd2-qe7", "title": c("4.Fd2 De7", "4.Bd2 Qe7")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3",
                {"san": "Bb4+", "eco": "Bogo-Indian Defense",
                 "comment": c("L'échec Bogo : sans Cc3 pour bloquer, les Blancs interposent en d2 et les Noirs gardent l'esprit Nimzo.",
                              "The Bogo check: with no Nc3 to block, White interposes on d2 and Black keeps the Nimzo spirit.")},
                {"san": "Bd2", "comment": c("Le blocage naturel ; les Noirs le prendront au bon moment pour dégrader la coordination blanche.",
                                            "The natural block; Black will trade it at the right moment to disrupt White's coordination.")},
                {"san": "Qe7", "comment": c("On soutient le fou b4 et on prépare …Cc6 et la rupture …e5.",
                                            "Support the b4 bishop and prepare …Nc6 and the …e5 break.")},
                "g3", "Nc6", "Bg2", "Bxd2+", "Qxd2", "d6", "O-O", "O-O", "Nc3", "a5", "b3", "e5",
            ],
        },
        # 2) 4.Cbd2 b6
        {
            "chapter": {"id": "nbd2", "title": c("4.Cbd2 b6", "4.Nbd2 b6")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3", "Bb4+",
                {"san": "Nbd2", "comment": c("L'autre blocage : le cavalier va en d2, gardant la structure de pions intacte.",
                                             "The other block: the knight goes to d2, keeping the pawn structure intact.")},
                "b6", "a3", "Bxd2+", "Bxd2", "Bb7", "Bg5", "d6", "e3", "Nbd7", "Bd3", "O-O",
            ],
        },
        # 3) 4.Fd2 a5 (garder le fou)
        {
            "chapter": {"id": "bd2-a5", "title": c("4.Fd2 a5", "4.Bd2 a5")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3", "Bb4+", "Bd2",
                {"san": "a5", "comment": c("On soutient le fou en b4 (contre a3) pour le garder cloueur plus longtemps.",
                                           "Prop up the b4 bishop (against a3) to keep it pinning longer.")},
                "g3", "O-O", "Bg2", "d6", "O-O", "Nbd7", "Qc2", "e5",
            ],
        },
    ],
}
