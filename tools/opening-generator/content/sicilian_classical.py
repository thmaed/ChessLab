# -*- coding: utf-8 -*-
"""Sicilienne classique (1.e4 c5 2.Cf3 Cc6 3.d4 cxd4 4.Cxd4 Cf6 5.Cc3 d6) — NOIR.

Les deux cavaliers sortent naturellement (…Cc6, …Cf6) sans le pion …a6 (Najdorf)
ni …g6 (Dragon). Arbre : attaque Richter-Rauzer 6.Fg5 (principale), Boleslavsky
6.Fe2 e5, attaque Velimirovic 6.Fc4, attaque anglaise 6.Fe3 Cg4. Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-classical",
    "name": "Sicilian Defense: Classical",
    "side": "black",
    "level": "advanced",
    "eco": ["B56", "B69"],
    "summary": c(
        "La sicilienne classique : les deux cavaliers sortent naturellement (…Cc6, …Cf6) sans s'engager comme dans la Najdorf (…a6) ou le Dragon (…g6). La grande ligne est l'attaque Richter-Rauzer (6.Fg5).",
        "The Classical Sicilian: both knights develop naturally (…Nc6, …Nf6) without the Najdorf (…a6) or Dragon (…g6) commitment. The main line is the Richter-Rauzer Attack (6.Bg5).",
    ),
    "lines": [
        # 1) Attaque Richter-Rauzer — 6.Fg5 (ligne principale)
        {
            "chapter": {"id": "rauzer", "title": c("Richter-Rauzer — 6.Fg5", "Richter-Rauzer — 6.Bg5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "d6", "eco": "Sicilian Defense: Classical Variation",
                 "comment": c("Le coup classique : …d6 avec les deux cavaliers déjà sortis, sans …a6 ni …g6.",
                              "The classical move: …d6 with both knights already out, no …a6 or …g6.")},
                {"san": "Bg5", "comment": c("L'attaque Richter-Rauzer : le clouage sur f6 mène à un jeu très concret, roques opposés.",
                                            "The Richter-Rauzer Attack: the pin on f6 leads to very concrete, opposite-castled play.")},
                {"san": "e6", "comment": c("On soutient f6 et on ouvre la voie au fou f8.",
                                           "Support f6 and open the way for the f8 bishop.")},
                {"san": "Qd2", "comment": c("Les Blancs relient les tours et visent le grand roque suivi de f4 et l'assaut de pions.",
                                            "White connects the rooks, heading for 0-0-0, f4 and a pawn storm.")},
                "a6", "O-O-O", "Bd7", "f4", "Be7",
                {"san": "Nf3", "comment": c("Manœuvre typique du Rauzer : le cavalier quitte d4 (évite les échanges) pour soutenir e5/g5.",
                                            "A typical Rauzer manoeuvre: the knight leaves d4 (dodging trades) to support e5/g5.")},
                "b5", "Bxf6", "gxf6", "Kb1", "Qb6", "f5",
            ],
        },
        # 2) Boleslavsky — 6.Fe2 e5
        {
            "chapter": {"id": "boleslavsky", "title": c("Boleslavsky — 6.Fe2 e5", "Boleslavsky — 6.Be2 e5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "d6",
                {"san": "Be2", "comment": c("Le développement calme ; les Noirs prennent le centre par le coup Boleslavsky …e5.",
                                            "The quiet development; Black grabs the centre with the Boleslavsky …e5.")},
                {"san": "e5", "comment": c("…e5 gagne de l'espace au prix du trou en d5 — le pari stratégique de Boleslavsky.",
                                           "…e5 grabs space at the cost of the d5 hole — Boleslavsky's strategic bet.")},
                "Nb3", "Be7", "O-O", "O-O", "Be3", "Be6", "Nd5", "Bxd5", "exd5", "Nb8", "c4", "Nbd7",
            ],
        },
        # 3) Attaque Velimirovic — 6.Fc4
        {
            "chapter": {"id": "velimirovic", "title": c("Velimirovic — 6.Fc4", "Velimirovic — 6.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "d6",
                {"san": "Bc4", "comment": c("Le fou vise f7/e6 (Sozin). Avec Fe3+De2+0-0-0, c'est l'attaque Velimirovic, très tranchante.",
                                            "The bishop eyes f7/e6 (Sozin). With Be3+Qe2+0-0-0 it's the razor-sharp Velimirovic Attack.")},
                "e6", "Be3", "Be7", "Qe2", "a6", "O-O-O", "Qc7", "Bb3", "Na5", "g4", "b5",
            ],
        },
        # 4) Attaque anglaise — 6.Fe3 Cg4
        {
            "chapter": {"id": "english-attack", "title": c("Attaque anglaise — 6.Fe3 Cg4", "English Attack — 6.Be3 Ng4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "d6",
                {"san": "Be3", "comment": c("L'attaque anglaise (Dd2, 0-0-0, g4). Ici …Cg4 harcèle le fou tout de suite.",
                                            "The English Attack (Qd2, 0-0-0, g4). Here …Ng4 harasses the bishop at once.")},
                {"san": "Ng4", "comment": c("On chasse le fou e3 et on prépare …g5/…Fg7 : jeu hypermoderne et pointu.",
                                            "Kick the e3 bishop and prepare …g5/…Bg7: sharp, hypermodern play.")},
                "Bg5", "h6", "Bh4", "g5", "Bg3", "Bg7", "h3", "Nge5",
            ],
        },
    ],
}
