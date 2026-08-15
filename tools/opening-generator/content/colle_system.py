# -*- coding: utf-8 -*-
"""Système Colle (1.d4 + e3 + Fd3) — répertoire BLANC.

Arbre : Colle-Koltanowski (c3 + rupture e4), Colle-Zukertort (b3 + Fb2 + Ce5),
et le Colle contre le fianchetto …g6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "colle-system",
    "name": "Colle System",
    "side": "white",
    "level": "club",
    "eco": ["D04", "D05"],
    "summary": c(
        "Un système d'installation quasi automatique : d4, Cf3, e3, Fd3, c3, 0-0, puis la rupture e4. Peu de théorie, un plan d'attaque clair au petit roque.",
        "An almost automatic setup: d4, Nf3, e3, Bd3, c3, 0-0, then the e4 break. Little theory, a clear kingside attacking plan.",
    ),
    "lines": [
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5", "c3", "Nc6", "Nbd2", "Bd6", "O-O", "O-O",
                {"san": "dxc5", "comment": c("On libère la rupture e4 : après …Fxc5, e4 brise le centre et ouvre l'attaque.",
                                             "Freeing the e4 break: after …Bxc5, e4 cracks the centre and opens the attack.")},
                "Bxc5", "e4", "Qc7", "e5", "Nd7",
                {"san": "Bxh7+", "critical": True,
                 "comment": c("Le sacrifice grec, raison d'être du Colle : le fou d3 et le cavalier f3 attendaient ce moment depuis le premier coup.",
                              "The Greek gift, the whole point of the Colle: the d3 bishop and f3 knight have been waiting for this since move one.")},
                "Kxh7", "Ng5+", "Kg6", "Qc2+", "f5",
                {"san": "exf6+",
                 "comment": c("La prise en passant rouvre les lignes. Les Blancs ont au minimum l'échec perpétuel — c'est le contrat du système.",
                              "The en-passant capture reopens the lines. White has at least perpetual check — that is the system's contract.")},
                "Kxf6",
            ],
        },
        {
            "chapter": {"id": "zukertort", "title": c("Colle-Zukertort — b3", "Colle-Zukertort — b3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5", "b3", "Nc6", "Bb2", "Bd6", "O-O", "O-O",
                {"san": "Ne5", "comment": c("La version Zukertort : le fou b2 rayonne sur la grande diagonale et Ce5 lance l'attaque.",
                                            "The Zukertort version: the b2 bishop rakes the long diagonal and Ne5 launches the attack.")},
                {"san": "Qc7"},
                {"san": "f4", "critical": True,
                 "comment": c("f4 AVANT Cd2 : l'inverse laisse …Cxe5 ! fxe5 Fxe5, et le pion d4 tombe pour rien.",
                              "f4 BEFORE Nd2: the other order allows …Nxe5! fxe5 Bxe5, and the d4 pawn drops for nothing.")},
                "cxd4", "exd4", "Nb4", "Ba3",
            ],
        },
        {
            "chapter": {"id": "vs-g6", "title": c("Contre …g6", "vs …g6")},
            "moves": [
                "d4", "Nf6", "Nf3", "g6", "e3", "Bg7", "Bd3", "O-O", "O-O", "d6", "c3", "Nbd7", "Nbd2", "e5",
            ],
        },
    ],
}
