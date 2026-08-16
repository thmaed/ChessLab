# -*- coding: utf-8 -*-
"""Partie écossaise (1.e4 e5 2.Cf3 Cc6 3.d4) — répertoire BLANC.

Approfondie : Mieses, classique 4…Fc5, Steinitz 4…Dh4, gambit écossais.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "scotch-game",
    "name": "Scotch Game",
    "side": "white",
    "level": "club",
    "eco": ["C44", "C45"],
    "summary": c(
        "On ouvre le centre tout de suite avec 3.d4 : jeu clair, pièces actives, peu de théorie lourde. Idéal pour prendre l'initiative sans mémoriser des tonnes de lignes.",
        "Open the centre at once with 3.d4: clear play, active pieces, little heavy theory. Ideal for seizing the initiative without memorising tons of lines.",
    ),
    "lines": [
        {
            "chapter": {"id": "mieses", "title": c("Variante Mieses", "Mieses Variation")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "d4", "comment": c("Le cœur de l'Écossaise : on brise le centre immédiatement.",
                                           "The heart of the Scotch: break the centre immediately.")},
                "exd4",
                {"san": "Nxd4", "eco": "Scotch Game",
                 "comment": c("Bien centralisé, le cavalier domine le milieu de l'échiquier.",
                              "Well centralised, the knight dominates the middle of the board.")},
                "Nf6",
                {"san": "Nxc6", "comment": c("La ligne moderne de Mieses : on échange puis on pousse e5.",
                                             "The modern Mieses line: trade, then push e5.")},
                "bxc6", "e5",
                {"san": "Qe7", "comment": c("Le seul bon coup : la dame attaque e5 et prépare …Cd5.",
                                            "The only good move: the queen hits e5 and prepares …Nd5.")},
                "Qe2", "Nd5", "c4", "Ba6", "b3", "g6",
            ],
        },
        {
            "chapter": {"id": "classical", "title": c("Variante classique — 4…Fc5", "Classical — 4…Bc5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Bc5", "comment": c("Les Noirs attaquent le cavalier d4 avec développement.",
                                            "Black hits the d4 knight while developing.")},
                {"san": "Be3", "comment": c("On défend d4 et on prépare c3 : la case f2 reste solide.",
                                            "Defend d4 and prepare c3: the f2 square stays solid.")},
                "Qf6", "c3", "Nge7", "Bc4", "Ne5", "Be2", "Qg6", "O-O", "d6",
            ],
        },
        {
            "chapter": {"id": "steinitz", "title": c("Variante Steinitz — 4…Dh4", "Steinitz — 4…Qh4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Qh4", "role": "sideline", "critical": True,
                 "eco": "Scotch Game: Steinitz Variation",
                 "comment": c("La sortie provocante de la dame vise e4 et g2 ; les Blancs se développent avec des tempos.",
                              "The provocative queen sortie eyes e4 and g2; White develops with tempo.")},
                {"san": "Nc3", "comment": c("On développe et on prépare Cde2 ou Fe2, sans céder à la panique.",
                                            "Develop and prepare Nde2 or Be2, without panicking.")},
                "Bb4", "Be2", "Qxe4", "Ndb5",
            ],
        },
        {
            "chapter": {"id": "scotch-gambit", "title": c("Gambit écossais — 4.Fc4", "Scotch Gambit — 4.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4",
                {"san": "Bc4", "role": "sideline", "eco": "Scotch Gambit",
                 "comment": c("Le Gambit écossais : au lieu de reprendre, on développe vite et on vise f7.",
                              "The Scotch Gambit: instead of recapturing, develop fast and target f7.")},
                "Nf6", "e5", "d5", "Bb5", "Ne4", "Nxd4", "Bc5",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-philidor", "title": c("2…d6 — la Philidor", "2…d6 — the Philidor")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d6",
                 "comment": c("Les Noirs défendent e5 avec un pion et refusent tout le débat. Un cours de 1.e4 e5 doit y répondre : c'est une entrée, pas une variante.",
                              "Black defends e5 with a pawn and declines the whole debate. A 1.e4 e5 course must answer it: this is an entry point, not a sideline."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On frappe immédiatement. La Philidor est solide mais étroite : lui laisser le temps de respirer serait lui rendre service.",
                              "Strike at once. The Philidor is solid but cramped: giving it time to breathe would be doing it a favour.")},
                "Nd7", "Bd3", "Ngf6", "O-O", "Be7", "Nc3",
                {"san": "O-O",
                 "comment": c("Les Noirs sont sains mais sans espace ni contre-jeu. Notre plan est simple : Te1, a4, et l'étouffement.",
                              "Black is sound but has neither space nor counterplay. Our plan is simple: Re1, a4, and squeeze.")},
            ],
        },
    ],
}
