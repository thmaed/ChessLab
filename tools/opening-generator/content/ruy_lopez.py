# -*- coding: utf-8 -*-
"""Partie espagnole / Ruy Lopez (1.e4 e5 2.Cf3 Cc6 3.Fb5) — répertoire BLANC.

Arbre approfondi : fermée (Breyer), Marshall, ouverte, échange, berlinoise,
Schliemann, Steinitz moderne. Lignes vérifiées (Wikipédia).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "ruy-lopez",
    "name": "Ruy Lopez",
    "side": "white",
    "level": "advanced",
    "eco": ["C60", "C99"],
    "summary": c(
        "L'ouverture la plus profonde du répertoire 1.e4 : le fou b5 met une pression durable sur c6 et e5. Pression positionnelle patiente, riche en plans et en systèmes.",
        "The deepest opening in the 1.e4 repertoire: the b5 bishop puts lasting pressure on c6 and e5. Patient positional pressure, rich in plans and systems.",
    ),
    "lines": [
        # 1) Fermée — Breyer (ligne principale)
        {
            "chapter": {"id": "closed", "title": c("Espagnole fermée — Breyer", "Closed Ruy Lopez — Breyer")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "Bb5", "comment": c("Le coup espagnol : on cloue indirectement c6, défenseur de e5.",
                                            "The Spanish move: indirectly pinning c6, the defender of e5.")},
                {"san": "a6", "eco": "Ruy Lopez: Morphy Defense",
                 "comment": c("La défense Morphy : les Noirs posent la question au fou.",
                              "The Morphy Defence: Black puts the question to the bishop.")},
                {"san": "Ba4", "comment": c("On garde le fou et la pression.",
                                            "Keep the bishop and the pressure.")},
                "Nf6", "O-O", "Be7", "Re1", "b5", "Bb3", "d6",
                {"san": "c3", "comment": c("La clé de voûte : c3 prépare d4 et une case de repli en c2 pour le fou.",
                                           "The keystone: c3 prepares d4 and a c2 retreat for the bishop.")},
                "O-O", "h3",
                {"san": "Nb8", "eco": "Ruy Lopez: Closed, Breyer Variation",
                 "comment": c("La manœuvre Breyer : le cavalier revient en d7 pour soutenir e5 et libérer le pion c.",
                              "The Breyer manoeuvre: the knight reroutes to d7 to support e5 and free the c-pawn.")},
                "d4", "Nbd7",
            ],
        },
        # 2) Attaque Marshall
        {
            "chapter": {"id": "marshall", "title": c("Attaque Marshall", "Marshall Attack")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5", "Bb3", "O-O", "c3",
                {"san": "d5", "role": "trap", "critical": True,
                 "eco": "Ruy Lopez: Marshall Attack",
                 "comment": c("Le gambit Marshall : un pion pour une attaque féroce et durable contre le roi blanc.",
                              "The Marshall gambit: a pawn for a fierce, lasting attack on White's king.")},
                "exd5", "Nxd5", "Nxe5", "Nxe5", "Rxe5", "c6",
                {"san": "d4", "comment": c("Les Blancs rendent des coups sains ; la théorie va très loin, mieux vaut la connaître.",
                                           "White plays sound moves; the theory runs deep — best to know it.")},
                "Bd6",
            ],
        },
        # 3) Défense ouverte
        {
            "chapter": {"id": "open", "title": c("Défense ouverte — 5…Cxe4", "Open Defence — 5…Nxe4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O",
                {"san": "Nxe4", "eco": "Ruy Lopez: Open Variation",
                 "comment": c("L'Ouverte : les Noirs prennent e4 pour un jeu de pièces actif au prix d'une structure fragile.",
                              "The Open: Black grabs e4 for active piece play at the cost of a loose structure.")},
                "d4", "b5", "Bb3", "d5", "dxe5", "Be6", "c3", "Bc5",
            ],
        },
        # 4) Variante d'échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
                {"san": "Bxc6", "eco": "Ruy Lopez: Exchange Variation",
                 "comment": c("On échange en c6 : les Noirs ont la paire de fous, les Blancs une meilleure structure. But : la finale.",
                              "Trading on c6: Black gets the bishop pair, White the better structure. Aim: the endgame.")},
                "dxc6", "O-O", "f6", "d4", "exd4", "Nxd4", "c5",
            ],
        },
        # 5) Berlinoise
        {
            "chapter": {"id": "berlin", "title": c("Défense berlinoise", "Berlin Defense")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5",
                {"san": "Nf6", "eco": "Ruy Lopez: Berlin Defense",
                 "comment": c("La Berlinoise, réputation de forteresse : les Noirs visent une finale sûre.",
                              "The Berlin, famed as a fortress: Black heads for a safe endgame.")},
                "O-O", "Nxe4", "d4", "Nd6", "Bxc6", "dxc6", "dxe5", "Nf5", "Qxd8+", "Kxd8",
                {"san": "Nc3", "comment": c("La fameuse finale berlinoise : sans dames, les Blancs jouent la structure et l'espace.",
                                            "The famous Berlin endgame: queens off, White plays structure and space.")},
                "Ke8", "h3", "Ne7",
            ],
        },
        # 6) Schliemann / Jaenisch
        {
            "chapter": {"id": "schliemann", "title": c("Gambit Schliemann — 3…f5", "Schliemann Gambit — 3…f5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5",
                {"san": "f5", "role": "trap", "critical": True,
                 "eco": "Ruy Lopez: Schliemann Defense",
                 "comment": c("Le Schliemann : très agressif, les Noirs frappent e4 immédiatement. À connaître pour bien réagir.",
                              "The Schliemann: highly aggressive, Black hits e4 at once. Know it to react well.")},
                {"san": "Nc3", "comment": c("La réponse la plus fiable : on renforce e4 plutôt que de le laisser filer.",
                                            "The most reliable reply: reinforce e4 rather than let it go.")},
                "fxe4", "Nxe4", "d5", "Nxe5", "dxe4", "Nxc6", "Qg5",
            ],
        },
        # 7) Steinitz moderne
        {
            "chapter": {"id": "modern-steinitz", "title": c("Steinitz moderne — 3…a6 4.Fa4 d6", "Modern Steinitz — 3…a6 4.Ba4 d6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4",
                {"san": "d6", "eco": "Ruy Lopez: Modern Steinitz Defense",
                 "comment": c("Le Steinitz moderne : solide et sans risque, les Noirs renoncent à …Cf6 pour verrouiller la maison.",
                              "The Modern Steinitz: solid and risk-free, Black skips …Nf6 to keep the house locked.")},
                "c3", "Nf6", "d4", "Bd7",
            ],
        },
    ],
}
