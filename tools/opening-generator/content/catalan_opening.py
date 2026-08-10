# -*- coding: utf-8 -*-
"""Catalane (1.d4 Cf6 2.c4 e6 3.g3) — répertoire BLANC.

Arbre approfondi : Catalane fermée, Catalane ouverte (…dxc4 avec …a6), et la
reprise immédiate 5.Da4+. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "catalan-opening",
    "name": "Catalan Opening",
    "side": "white",
    "level": "advanced",
    "eco": ["E00", "E09"],
    "summary": c(
        "Le meilleur des deux mondes : la structure solide du gambit dame plus un fou en g2 qui rayonne sur la grande diagonale. Pression durable, sans risque.",
        "The best of both worlds: the solid Queen's Gambit structure plus a g2 bishop raking the long diagonal. Lasting pressure, minimal risk.",
    ),
    "lines": [
        # 1) Catalane fermée
        {
            "chapter": {"id": "closed", "title": c("Catalane fermée", "Closed Catalan")},
            "moves": [
                "d4", "Nf6", "c4", "e6",
                {"san": "g3", "eco": "Catalan Opening",
                 "comment": c("Le fianchetto catalan : le fou g2 vise b7 et met une pression permanente sur d5.",
                              "The Catalan fianchetto: the g2 bishop eyes b7 and presses permanently on d5.")},
                "d5", "Bg2", "Be7", "Nf3", "O-O", "O-O", "c6",
                {"san": "Qc2", "comment": c("On garde la tension : la dame soutient e4 et surveille c4.",
                                            "Keep the tension: the queen supports e4 and watches c4.")},
                "Nbd7", "Nbd2", "b6", "b3", "Bb7", "Bb2", "Rc8",
            ],
        },
        # 2) Catalane ouverte — …dxc4
        {
            "chapter": {"id": "open", "title": c("Catalane ouverte — …dxc4", "Open Catalan — …dxc4")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "g3", "d5", "Bg2",
                {"san": "dxc4", "eco": "Catalan Opening: Open Defense",
                 "comment": c("Les Noirs prennent le pion. Les Blancs le récupèrent souvent grâce à la pression du fou g2 (Ce5, Da4).",
                              "Black takes the pawn. White usually regains it thanks to the g2 bishop's pressure (Ne5, Qa4).")},
                "Nf3", "a6", "O-O", "Nc6", "e3", "Bd7", "Qe2", "Rb8", "Rd1", "b5", "b3",
            ],
        },
        # 3) Reprise immédiate — 5.Da4+
        {
            "chapter": {"id": "qa4", "title": c("Reprise immédiate — 5.Da4+", "Immediate regain — 5.Qa4+")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "g3", "d5", "Bg2", "dxc4",
                {"san": "Qa4+", "comment": c("La reprise sans détour : l'échec récupère c4 tout de suite.",
                                             "The no-nonsense recapture: the check wins c4 back at once.")},
                "Nbd7", "Qxc4", "a6", "Qc2", "c5", "Nf3", "b6", "O-O", "Bb7",
            ],
        },
    ],
}
