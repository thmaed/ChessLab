# -*- coding: utf-8 -*-
"""Partie du Fou (1.e4 e5 2.Fc4) — répertoire BLANC.

Arbre : 2…Cf6 (avec d3), 2…Fc5 (c3+d4), et le gambit Urusov 2…Cf6 3.d4.
Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "bishops-opening",
    "name": "Bishop's Opening",
    "side": "white",
    "level": "club",
    "eco": ["C23", "C24"],
    "summary": c(
        "Le fou file en c4 dès le 2e coup, visant f7 sans engager le cavalier roi. Souvent une italienne détournée, avec la possibilité d'un centre par d4 ou d'un jeu tranquille par d3.",
        "The bishop hits c4 on move two, eyeing f7 without committing the king's knight. Often a rerouted Italian, with the option of a d4 centre or quiet play with d3.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("2…Cf6 — 3.d3", "2…Nf6 — 3.d3")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4", "eco": "Bishop's Opening",
                 "comment": c("Le fou italien sans …Cf3 : on garde le choix entre d3 tranquille et d4 tranchant.",
                              "The Italian bishop without …Nf3: keeping the choice between quiet d3 and sharp d4.")},
                "Nf6", "d3", "c6", "Nf3", "d5", "Bb3", "Bd6", "exd5", "cxd5", "O-O", "O-O", "Nc3", "Nc6",
            ],
        },
        {
            "chapter": {"id": "bc5", "title": c("2…Fc5 — 3.c3 & d4", "2…Bc5 — 3.c3 & d4")},
            "moves": [
                "e4", "e5", "Bc4", "Bc5",
                {"san": "c3", "comment": c("On prépare d4 pour bâtir un centre : c'est l'esprit du gambit Evans, sans …b4.",
                                           "Preparing d4 to build a centre: the spirit of the Evans Gambit, without …b4.")},
                "Nf6", "d4", "exd4", "cxd4", "Bb4+", "Bd2", "Bxd2+", "Nbxd2", "d5", "exd5", "Nxd5", "Ngf3", "O-O",
            ],
        },
        {
            "chapter": {"id": "urusov", "title": c("Gambit Urusov — 3.d4", "Urusov Gambit — 3.d4")},
            "moves": [
                "e4", "e5", "Bc4", "Nf6",
                {"san": "d4", "comment": c("Le gambit Urusov : un pion contre un développement fulgurant et une attaque sur f7.",
                                           "The Urusov Gambit: a pawn for lightning development and an attack on f7.")},
                "exd4", "Nf3", "Nc6", "e5", "d5", "Bb5", "Ne4", "Nxd4", "Bc5",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "two-knights", "title": c("2…Cc6 — vers les Deux Cavaliers", "2…Nc6 — into the Two Knights")},
            "moves": [
                "e4", "e5", "Bc4",
                {"san": "Nc6",
                 "comment": c("Un tiers des parties, et le cours partait de …Cf6 ou …Fc5. Le coup le plus naturel n'était pas traité.",
                              "A third of games, and the course started from …Nf6 or …Bc5. The most natural move was untreated."),
                 "critical": True},
                "Nf3", "Nf6",
                {"san": "Ng5",
                 "comment": c("On bascule dans les Deux Cavaliers, la ligne la plus tranchante : f7 est attaqué deux fois.",
                              "We switch into the Two Knights, the sharpest line: f7 is hit twice."),
                 "critical": True},
                "d5", "exd5",
                {"san": "Na5",
                 "comment": c("La bonne défense. Reprendre en d5 perdrait sur Cxf7 — c'est le piège que tout joueur de 3.Cg5 attend.",
                              "The right defence. Recapturing on d5 would lose to Nxf7 — the trap every 3.Ng5 player is hoping for.")},
                "Bb5+", "Bd7",
            ],
        },
        {
            "chapter": {"id": "main", "title": c("2…Cf6 — 3.d3", "2…Nf6 — 3.d3")},
            "moves": [
                "e4", "e5", "Bc4", "Nf6", "d3",
                {"san": "Bc5",
                 "comment": c("Plus d'un tiers des parties après 3.d3, et le chapitre continuait autrement. Position symétrique, jeu lent : ce sont les plans qui décident.",
                              "Over a third of games after 3.d3, and the chapter went elsewhere. A symmetrical position and slow play: plans decide."),
                 "critical": True},
                "Nf3", "O-O", "O-O", "d6", "c3",
                {"san": "Bg4",
                 "comment": c("Les Noirs clouent avant qu'on joue Cbd2. On répond Fg5 : le clouage vaut aussi pour eux.",
                              "Black pins before we get Nbd2 in. We answer Bg5: the pin cuts both ways.")},
                "Bg5", "Nbd7",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,87). ────────────────
        {
            "chapter": {"id": "bishops-main", "title": c("Ouverture du fou", "Bishop's Opening")},
            "moves": [
                "e4", "e5", "Bc4", "Nc6", "Nf3",
                {"san": "Bc5",
                 "comment": c("On transpose dans l'Italienne, et c'est le cas le plus fréquent — un Noir sur trois. Le cours ne prévoyait que …Cf6.",
                              "We transpose into the Italian, and it is the most frequent case — one Black player in three. The course only planned for …Nf6."),
                 "critical": True},
                {"san": "O-O",
                 "comment": c("Le roi à l'abri d'abord. Dans ces positions calmes, celui qui roque le premier choisit ensuite où la partie se jouera.",
                              "King to safety first. In these quiet positions, whoever castles first then decides where the game will be played.")},
                "Nf6", "Nc3", "O-O", "d3", "h6", "h3", "d6",
                {"san": "Na4",
                 "comment": c("Le cavalier va chercher le fou c5, la meilleure pièce noire. L'échanger vaut le voyage, même par le bord de l'échiquier.",
                              "The knight goes after the c5 bishop, Black's best piece. Trading it is worth the trip, even round the edge of the board."),
                 "critical": True},
                "Bb6",
            ],
        },
        {
            "chapter": {"id": "bishops-main", "title": c("Ouverture du fou", "Bishop's Opening")},
            "moves": [
                "e4", "e5", "Bc4",
                {"san": "d6",
                 "comment": c("Une réponse modeste — un joueur sur dix — que le cours ignorait : il ne voyait que …Cf6, …Fc5 et …Cc6. Les Noirs ferment la diagonale du fou c4 avec un pion.",
                              "A modest reply — one player in ten — the course ignored: it only saw …Nf6, …Bc5 and …Nc6. Black shuts the c4 bishop's diagonal with a pawn."),
                 "critical": True},
                "Nf3", "Be7",
                {"san": "d4",
                 "comment": c("Puisqu'ils jouent petit, on prend grand : les Noirs ont dépensé deux coups à ne rien contester au centre.",
                              "Since they play small, we take big: Black has spent two moves contesting nothing in the centre."),
                 "critical": True},
                "exd4", "Nxd4", "Nf6", "Nc3", "O-O", "O-O", "Nc6",
            ],
        },
        {
            "chapter": {"id": "urusov", "title": c("Gambit Urusov — 3…Cf6 4.d4", "Urusov Gambit — 3…Nf6 4.d4")},
            "moves": [
                "e4", "e5", "Bc4", "Nf6", "d4",
                {"san": "Nxe4",
                 "comment": c("Un Noir sur cinq prend le pion e4 plutôt que le pion d4 — et c'est une imprécision que le cours ne relevait pas. Le cavalier va se retrouver seul en territoire ennemi.",
                              "One Black player in five takes the e4 pawn rather than d4 — an inaccuracy the course did not flag. The knight ends up alone in enemy territory."),
                 "critical": True},
                {"san": "dxe5",
                 "comment": c("On ouvre la colonne d et on chasse le cavalier avec un pion. Les Blancs sont nettement mieux : c'est la punition tranquille de …Cxe4.",
                              "We open the d-file and evict the knight with a pawn. White is clearly better: the quiet punishment of …Nxe4."),
                 "critical": True},
                "c6", "Qe2", "Nc5", "a3", "Be7", "Nf3", "O-O", "O-O", "d6",
            ],
        },
        {
            "chapter": {"id": "bishops-quiet", "title": c("Ligne tranquille — 4.d3", "Quiet line — 4.d3")},
            "moves": [
                "e4", "e5", "Bc4", "Nf6", "d3",
                {"san": "Nc6",
                 "comment": c("Un Noir sur cinq développe ainsi, et le cours ne voyait que …c6 et …Fc5.",
                              "One Black player in five develops like this, and the course only saw …c6 and …Bc5."),
                 "critical": True},
                "Nf3", "Bc5",
                {"san": "c3",
                 "comment": c("La structure d'Italienne lente : on prépare d4 à petits pas, et le fou c5 devra un jour décider s'il recule ou s'il s'échange.",
                              "The slow Italian structure: we prepare d4 step by step, and the c5 bishop will one day have to choose between retreating and trading."),
                 "critical": True},
                "a5", "O-O", "d6", "Re1", "O-O", "h3", "Ba7",
            ],
        },
        {
            "chapter": {"id": "bishops-main", "title": c("Ouverture du fou", "Bishop's Opening")},
            "moves": [
                "e4", "e5", "Bc4", "Nc6", "Nf3",
                {"san": "h6",
                 "comment": c("Le coup d'attente qui ne développe rien. Un Noir sur sept le joue, et il se paie comptant.",
                              "The waiting move that develops nothing. One Black player in seven plays it, and it is paid for in cash."),
                 "critical": True},
                "d4", "exd4", "Nxd4", "Nf6", "Nc3", "Bb4", "Nxc6", "dxc6",
                {"san": "Qxd8+",
                 "comment": c("Les Noirs reprennent du ROI : plus de roque, et une finale où leur temps perdu en …h6 se compte double.",
                              "Black recaptures with the KING: no more castling, and an endgame where the tempo spent on …h6 counts twice."),
                 "critical": True},
                "Kxd8",
            ],
        },
    ],
}
