# -*- coding: utf-8 -*-
"""Attaque Veresov (1.d4 Cf6 2.Cc3 d5 3.Fg5) — répertoire BLANC.

La « Trompowsky du cavalier c3 » : peu de théorie, un clouage sur f6 et souvent
la poussée e4. Arbre : 3…Cbd7 4.f3 (agressive), 3…Ff5, 3…c6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "veresov-attack",
    "name": "Veresov Attack",
    "side": "white",
    "level": "club",
    "eco": ["D01"],
    "summary": c(
        "Une ouverture de système, cousine de la Trompowsky : Cc3 + Fg5, on cloue f6 et on vise la poussée e4. Peu de théorie, du jeu concret et des idées d'attaque directes.",
        "A system opening, cousin of the Trompowsky: Nc3 + Bg5, pin f6 and aim for the e4 push. Little theory, concrete play and direct attacking ideas.",
    ),
    "lines": [
        # 1) 3…Cbd7 4.f3 (agressive)
        {
            "chapter": {"id": "nbd7", "title": c("3…Cbd7 — 4.f3", "3…Nbd7 — 4.f3")},
            "moves": [
                "d4", "Nf6", "Nc3", "d5",
                {"san": "Bg5", "eco": "Veresov Attack",
                 "comment": c("Le coup Veresov : le fou cloue f6 tout de suite ; suivront f3 et e4 pour ouvrir le centre.",
                              "The Veresov move: the bishop pins f6 at once; f3 and e4 will follow to open the centre.")},
                "Nbd7",
                {"san": "f3", "comment": c("On prépare e4 sans permettre …Cg4 : le centre va s'ouvrir au profit des pièces blanches.",
                                           "Preparing e4 without allowing …Ng4: the centre will open in White's pieces' favour.")},
                "e6", "e4", "dxe4", "fxe4", "h6", "Bh4", "c5",
            ],
        },
        # 2) 3…Ff5
        {
            "chapter": {"id": "bf5", "title": c("3…Ff5", "3…Bf5")},
            "moves": [
                "d4", "Nf6", "Nc3", "d5", "Bg5",
                {"san": "Bf5", "comment": c("Les Noirs sortent le fou avant …e6 ; on l'échange en f6 pour la paire de fous et la colonne e semi-ouverte.",
                                            "Black frees the bishop before …e6; White trades on f6 for the bishop pair and a half-open e-file.")},
                "Bxf6", "exf6", "e3", "c6", "Bd3", "Bxd3", "Qxd3", "Bd6", "Nge2", "O-O",
            ],
        },
        # 3) 3…c6
        {
            "chapter": {"id": "c6", "title": c("3…c6", "3…c6")},
            "moves": [
                "d4", "Nf6", "Nc3", "d5", "Bg5", "c6",
                {"san": "e3", "comment": c("Installation solide ; contre …Db6, la tour b1 défend b2 et on continue Fd3, Cge2.",
                                           "A solid setup; against …Qb6, Rb1 defends b2 and White continues Bd3, Nge2.")},
                "h6", "Bh4", "Qb6", "Rb1", "e6", "Nf3", "Bd6", "Bd3", "Nbd7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        #
        # Le moteur propose e4 sur les deux positions — une Pirc ou une
        # Française. Ce serait quitter la Veresov, qui EST 3.Fg5. On garde le
        # système ; les deux lignes sont saines.
        {
            "chapter": {"id": "vs-g6", "title": c("2…g6 — le fianchetto", "2…g6 — the fianchetto")},
            "moves": [
                "d4", "Nf6", "Nc3",
                {"san": "g6",
                 "comment": c("Plus d'un quart des parties, et le cours partait de …d5. Les Noirs vont au fianchetto avant de se déterminer au centre.",
                              "Over a quarter of games, and the course started from …d5. Black fianchettoes before committing in the centre."),
                 "critical": True},
                {"san": "Bg5",
                 "comment": c("Le coup du système, sans se laisser détourner : le fou cloue le cavalier qui garde d5 et e4.",
                              "The system move, undistracted: the bishop pins the knight that guards d5 and e4."),
                 "critical": True},
                "d5", "e3", "Bg7", "Nf3", "O-O", "Be2",
            ],
        },
        {
            "chapter": {"id": "vs-e6", "title": c("2…e6 — l'installation française", "2…e6 — the French setup")},
            "moves": [
                "d4", "Nf6", "Nc3",
                {"san": "e6",
                 "comment": c("Un quart des parties. Les Noirs gardent …d5 en réserve et surveillent e4.",
                              "A quarter of games. Black keeps …d5 in reserve and watches e4.")},
                "Bg5", "Be7", "Nf3", "d5",
                {"san": "Bxf6",
                 "comment": c("On échange volontairement : sans le cavalier f6, e4 devient possible et notre centre prend toute la place.",
                              "We trade deliberately: without the f6 knight, e4 becomes possible and our centre takes over."),
                 "critical": True},
                "Bxf6", "e4",
            ],
        },
    ],
}
