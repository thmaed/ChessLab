# -*- coding: utf-8 -*-
"""Partie écossaise (1.e4 e5 2.Cf3 Cc6 3.d4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "scotch-game",
    "name": "Scotch Game",
    "side": "white",
    "level": "club",
    "eco": ["C44", "C45"],
    "summary": c(
        "On ouvre le centre tout de suite avec 3.d4 : jeu clair, pièces actives, peu de théorie lourde à retenir. Idéal pour prendre l'initiative.",
        "Open the centre at once with 3.d4: clear play, active pieces, little heavy theory. Ideal for seizing the initiative.",
    ),
    "lines": [
        {
            "chapter": {"id": "mieses", "title": c("Variante Mieses", "Mieses Variation")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "d4", "comment": c("Le cœur de l'Écossaise : on brise le centre immédiatement.",
                                           "The heart of the Scotch: break the centre immediately.")},
                "exd4",
                {"san": "Nxd4", "eco": "Scotch Game", "comment": c("Bien centralisé, le cavalier domine le milieu de l'échiquier.",
                                                                    "Well centralised, the knight dominates the middle of the board.")},
                "Nf6",
                {"san": "Nxc6", "comment": c("La ligne moderne de Mieses : on échange puis on pousse e5 pour gêner le Cf6.",
                                             "The modern Mieses line: trade, then push e5 to harass the f6 knight.")},
                "bxc6", "e5",
                {"san": "Qe7", "comment": c("Le seul bon coup : la dame attaque e5 et prépare …Cd5.",
                                            "The only good move: the queen hits e5 and prepares …Nd5.")},
                "Qe2", "Nd5",
            ],
        },
        {
            "chapter": {"id": "classical", "title": c("Variante classique — 4…Fc5", "Classical — 4…Bc5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Bc5", "comment": c("Les Noirs attaquent le cavalier d4 avec développement.",
                                            "Black hits the d4 knight while developing.")},
                {"san": "Be3", "comment": c("On défend d4 et on prépare c3 : la case f2 est solide.",
                                            "Defend d4 and prepare c3: the f2 square stays solid.")},
                "Qf6", "c3", "Nge7",
            ],
        },
        {
            "chapter": {"id": "scotch-gambit", "title": c("Gambit écossais", "Scotch Gambit")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4",
                {"san": "Bc4", "role": "sideline", "eco": "Scotch Gambit",
                 "comment": c("Le Gambit écossais : au lieu de reprendre, on développe vite et on vise f7.",
                              "The Scotch Gambit: instead of recapturing, develop fast and target f7.")},
                "Nf6", "e5", "d5",
            ],
        },
    ],
}
