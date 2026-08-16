# -*- coding: utf-8 -*-
"""Catalane (1.d4 Cf6 2.c4 e6 3.g3) — répertoire BLANC.

Arbre approfondi : Catalane fermée, Catalane ouverte (…dxc4 avec …a6), et la
reprise immédiate 5.Da4+. Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-g6", "title": c("2…g6 — le fianchetto", "2…g6 — the fianchetto")},
            "moves": [
                "d4", "Nf6", "c4",
                {"san": "g6",
                 "comment": c("Près d'un tiers des parties, et le cours partait de …e6. Sans …e6, la Catalane n'existe pas : les Noirs vont vers une Grünfeld ou une Est-Indienne.",
                              "Nearly a third of games, and the course started from …e6. Without …e6 there is no Catalan: Black is heading for a Grünfeld or King's Indian."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("On sort du plan catalan et l'on occupe le centre : le fianchetto g3 n'aurait plus de cible sur la grande diagonale.",
                              "We leave the Catalan plan and take the centre: the g3 fianchetto would have no target left on the long diagonal.")},
                "d5",
                {"san": "Qb3", "critical": True,
                 "comment": c("La pression sur d5 avant le roque adverse — l'idée qui donne le ton, et qui rappelle celle de la Catalane sans en avoir la structure.",
                              "Pressure on d5 before Black castles — the idea that sets the tone, echoing the Catalan without sharing its structure.")},
                "dxc4", "Qxc4", "c6", "Nf3",
            ],
        },
        {
            "chapter": {"id": "bogo-check", "title": c("4…Fb4+ — l'échec intercalé", "4…Bb4+ — the interposed check")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "g3",
                {"san": "Bb4+",
                 "comment": c("Un Noir sur cinq donne cet échec avant tout. C'est une Bogo-Indienne greffée sur notre ordre de coups.",
                              "One Black player in five gives this check first. It's a Bogo-Indian grafted onto our move order.")},
                {"san": "Bd2",
                 "comment": c("On interpose le fou plutôt que le cavalier : après l'échange, notre fou reprend la diagonale et le fianchetto garde tout son sens.",
                              "Interpose the bishop rather than the knight: after the trade our bishop takes the diagonal and the fianchetto keeps its point."),
                 "critical": True},
                "a5", "Nf3", "d5", "a3", "Be7",
            ],
        },
    ],
}
