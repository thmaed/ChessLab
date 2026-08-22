# -*- coding: utf-8 -*-
"""Partie espagnole / Ruy Lopez (1.e4 e5 2.Cf3 Cc6 3.Fb5) — répertoire BLANC.

Arbre approfondi : fermée (Breyer), Marshall, ouverte, échange, berlinoise,
Schliemann, Steinitz moderne. Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "steinitz", "title": c("Défense Steinitz — 3…d6", "Steinitz Defence — 3…d6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5",
                {"san": "d6",
                 "comment": c("Un quart des parties après 3.Fb5, et le cours partait de …a6. La Steinitz est solide, passive, et parfaitement jouable en club.",
                              "A quarter of games after 3.Bb5, and the course started from …a6. The Steinitz is solid, passive, and perfectly playable at club level."),
                 "critical": True},
                {"san": "O-O",
                 "comment": c("On roque sans se presser. Le pion e4 n'est pas vraiment en prise : …Cxe4 perd sur Te1 et d4.",
                              "We castle without hurry. The e4 pawn isn't really hanging: …Nxe4 loses to Re1 and d4.")},
                "Bd7", "c3", "a6", "Ba4", "Nf6", "Re1",
            ],
        },
        {
            "chapter": {"id": "vs-philidor", "title": c("2…d6 — la Philidor", "2…d6 — the Philidor")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d6",
                 "comment": c("L'adversaire refuse l'Espagnole dès le deuxième coup. Sans réponse ici, tout le répertoire tombe une partie sur six.",
                              "The opponent declines the Ruy Lopez at move two. With no answer here, the whole repertoire fails in one game out of six."),
                 "critical": True},
                "d4", "Nf6", "Nc3", "Nc6",
                {"san": "d5",
                 "comment": c("On ferme le centre au moment où le cavalier c6 doit reculer : les Noirs manquent d'espace, nous avons le plan.",
                              "We close the centre exactly when the c6 knight must retreat: Black lacks space, we have the plan.")},
                "Ne7", "a4",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,78). ────────────────
        {
            "chapter": {"id": "classical", "title": c("Défense classique — 3…Fc5", "Classical Defence — 3…Bc5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5",
                {"san": "Bc5",
                 "comment": c("La défense classique : un Noir sur huit, et le cours ne prévoyait que …a6, …Cf6, …f5 et …d6. Le fou sort avant d'être gêné, mais il néglige la menace sur c6.",
                              "The classical defence: one Black player in eight, and the course only planned for …a6, …Nf6, …f5 and …d6. The bishop comes out before it can be hemmed in, but it ignores the threat to c6."),
                 "critical": True},
                {"san": "c3",
                 "comment": c("On prépare d4 avec gain de temps sur le fou c5 : c'est la réfutation positionnelle de cette sortie précoce, pas une réfutation tactique.",
                              "We prepare d4 with tempo on the c5 bishop: the positional refutation of that early sortie, not a tactical one."),
                 "critical": True},
                "Nf6", "O-O", "O-O", "d4", "Bb6", "a4", "a6", "Bxc6", "dxc6",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante d'échange — 4.Fxc6", "Exchange Variation — 4.Bxc6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Bxc6", "dxc6", "O-O",
                {"san": "Bd6",
                 "comment": c("Plus de quatre Noirs sur dix jouent ce fou modeste — et le cours ne connaissait que …f6. Il défend e5 sans affaiblir le roque, ce qui est plus malin qu'il n'y paraît.",
                              "More than four Black players in ten play this modest bishop move — and the course only knew …f6. It defends e5 without weakening the castled king, which is smarter than it looks."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On ouvre au moment où leurs deux fous ne sont pas coordonnés. Toute la variante d'échange tient sur une idée : notre majorité à l'aile roi est saine, la leur à l'aile dame ne l'est pas.",
                              "We open while their two bishops are uncoordinated. The whole Exchange Variation rests on one idea: our kingside majority is healthy, their queenside majority is not."),
                 "critical": True},
                "exd4", "Qxd4", "f6", "Be3", "Ne7", "Nbd2", "Ng6", "Nc4", "Be7",
            ],
        },
        {
            "chapter": {"id": "closed", "title": c("Espagnole fermée", "Closed Ruy Lopez")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4",
                {"san": "b5",
                 "comment": c("Près d'un Noir sur trois chasse le fou tout de suite, et le cours ne prévoyait que …Cf6 et …d6. C'est prématuré : chaque poussée de pion à l'aile dame se paiera plus tard.",
                              "Nearly one Black player in three kicks the bishop at once, and the course only planned for …Nf6 and …d6. It is premature: every queenside pawn push will be paid for later."),
                 "critical": True},
                {"san": "Bb3",
                 "comment": c("Le fou reste sur la diagonale a2-g8, celle qui compte. Il n'a pas été chassé, il a été INVITÉ à sa meilleure case.",
                              "The bishop stays on the a2-g8 diagonal, the one that matters. It was not driven away, it was INVITED to its best square."),
                 "critical": True},
                "Nf6", "O-O", "d6", "c3", "Be7", "h3", "O-O", "d4", "exd4",
            ],
        },
        {
            "chapter": {"id": "vs-petrov", "title": c("Contre la Petroff — 2…Cf6", "vs the Petrov — 2…Nf6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6",
                 "comment": c("La Petroff coupe court à l'Espagnole : les Noirs contre-attaquent au lieu de défendre e5. Un joueur sur dix, et le cours ne prévoyait que …Cc6 et …d6.",
                              "The Petrov cuts the Ruy Lopez short: Black counterattacks instead of defending e5. One player in ten, and the course only planned for …Nc6 and …d6."),
                 "critical": True},
                "Nxe5",
                {"san": "d6",
                 "comment": c("Le coup obligatoire : reprendre tout de suite par …Cxe4 perd la dame après De2. On chasse d'abord.",
                              "The forced move: recapturing at once with …Nxe4 loses the queen to Qe2. Kick the knight first."),
                 "critical": True},
                "Nf3", "Nxe4", "d4", "d5", "Bd3", "Bd6", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-philidor", "title": c("Contre la Philidor — 2…d6", "vs the Philidor — 2…d6")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4",
                {"san": "exd4",
                 "comment": c("Près de six Noirs sur dix relâchent la tension, et le cours ne voyait que …Cf6. Ils nous donnent le centre pour ne pas être étouffés.",
                              "Nearly six Black players in ten release the tension, and the course only saw …Nf6. They hand us the centre to avoid being squeezed."),
                 "critical": True},
                "Nxd4", "c5", "Nb3", "Nf6", "Nc3", "Be6", "Bf4", "Nc6", "Qd2", "Be7",
            ],
        },
    ],
}
