# -*- coding: utf-8 -*-
"""Gambit dame refusé (1.d4 d5 2.c4 e6) — répertoire BLANC.

Arbre approfondi : Orthodoxe/Tartakower, variante de l'échange (attaque de
minorité), variante Lasker, Cambridge Springs. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "queens-gambit-declined",
    "name": "Queen's Gambit Declined",
    "side": "white",
    "level": "club",
    "eco": ["D30", "D69"],
    "summary": c(
        "L'ouverture classique par excellence : le gambit dame met une pression durable au centre. Les Noirs refusent par …e6, sûrs mais un peu passifs.",
        "The classical opening par excellence: the Queen's Gambit puts lasting pressure on the centre. Black declines with …e6, solid but a touch passive.",
    ),
    "lines": [
        # 1) Orthodoxe / Tartakower
        {
            "chapter": {"id": "orthodox", "title": c("Orthodoxe / Tartakower", "Orthodox / Tartakower")},
            "moves": [
                "d4", "d5",
                {"san": "c4", "comment": c("Le gambit dame : on offre c4 pour dévier le pion d5 et dominer le centre.",
                                           "The Queen's Gambit: offering c4 to deflect the d5 pawn and control the centre.")},
                {"san": "e6", "eco": "Queen's Gambit Declined",
                 "comment": c("Le refus solide : les Noirs soutiennent d5 (mais enferment leur fou c8).",
                              "The solid decline: Black supports d5 (but shuts in the c8 bishop).")},
                "Nc3", "Nf6", "Bg5", "Be7", "e3", "O-O", "Nf3", "h6", "Bh4",
                {"san": "b6", "comment": c("Le système Tartakower : les Noirs résolvent le fou c8 par …Fb7.",
                                           "The Tartakower system: Black solves the c8 bishop with …Bb7.")},
                "cxd5", "Nxd5", "Bxe7", "Qxe7", "Nxd5", "exd5", "Rc1", "Be6",
            ],
        },
        # 2) Variante de l'échange — attaque de minorité
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "d4", "d5", "c4", "e6",
                {"san": "cxd5", "eco": "Queen's Gambit Declined: Exchange Variation",
                 "comment": c("L'échange donne la fameuse attaque de minorité : b4-b5 pour créer une faiblesse en c6.",
                              "The exchange gives the famous minority attack: b4-b5 to create a weakness on c6.")},
                "exd5", "Nc3", "Nf6", "Bg5", "c6", "Qc2", "Be7", "e3", "O-O", "Bd3", "Nbd7", "Nge2", "Re8", "O-O", "Nf8",
            ],
        },
        # 3) Variante Lasker
        {
            "chapter": {"id": "lasker", "title": c("Variante Lasker", "Lasker Variation")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "Nf6", "Bg5", "Be7", "e3", "O-O", "Nf3", "h6", "Bh4",
                {"san": "Ne4", "comment": c("La Lasker : on échange des pièces pour alléger la position étriquée des Noirs.",
                                            "The Lasker: trade pieces to ease Black's cramped position.")},
                "Bxe7", "Qxe7", "cxd5", "Nxc3", "bxc3", "exd5", "Qb3", "Rd8", "c4", "dxc4", "Bxc4",
            ],
        },
        # 4) Cambridge Springs
        {
            "chapter": {"id": "cambridge-springs", "title": c("Cambridge Springs", "Cambridge Springs")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "Nf6", "Bg5", "Nbd7", "Nf3", "c6", "e3",
                {"san": "Qa5", "eco": "Queen's Gambit Declined: Cambridge Springs Defense",
                 "comment": c("Cambridge Springs : la dame cloue c3 et menace …Ce4 ou …dxc4 avec du contre-jeu.",
                              "Cambridge Springs: the queen pins c3 and threatens …Ne4 or …dxc4 with counterplay.")},
                "Nd2", "Bb4", "Qc2", "O-O", "Bh4", "c5",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs prennent ou jouent …c6", "If Black takes or plays …c6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "dxc4",
                 "comment": c("Le Gambit Dame ACCEPTÉ, un quart des parties. Les Noirs ne tiendront pas le pion : notre jeu consiste à le reprendre au bon moment.",
                              "The Queen's Gambit ACCEPTED, a quarter of games. Black can't hold the pawn: our game is to take it back at the right moment."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Sans hâte. Fxc4 viendra quand le fou pourra s'y installer sans perdre de temps.",
                              "No hurry. Bxc4 comes when the bishop can settle there without losing time.")},
                "e6", "Bxc4", "c5", "Nf3", "Nf6", "O-O",
            ],
        },
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs prennent ou jouent …c6", "If Black takes or plays …c6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "c6",
                 "comment": c("La Slave. Elle a son cours ; l'essentiel est de ne pas la confondre avec le Refusé, car le fou c8 y reste libre.",
                              "The Slav. It has its own course; the key is not to confuse it with the Declined, because the c8 bishop stays free.")},
                "Nf3", "dxc4",
                {"san": "a4",
                 "comment": c("Le coup à connaître : on empêche …b5 de tenir le pion. Sans lui, les Noirs gardent le gain matériel.",
                              "The move to know: it stops …b5 from holding the pawn. Without it, Black keeps the material."),
                 "critical": True},
                "e6", "e3", "b5", "axb5",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,79). Répertoire BLANC.
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre 2…Cf6", "vs 2…Nf6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "Nf6",
                 "comment": c("Les Noirs développent avant de choisir leur défense — un joueur sur sept — et le cours ne prévoyait que …e6, …dxc4 et …c6.",
                              "Black develops before choosing a defence — one player in seven — and the course only planned for …e6, …dxc4 and …c6."),
                 "critical": True},
                {"san": "cxd5",
                 "comment": c("On prend avant que …c6 ou …e6 ne viennent soutenir d5 : c'est le seul instant où cet échange rapporte quelque chose.",
                              "We take before …c6 or …e6 support d5: the only moment when this exchange gains anything."),
                 "critical": True},
                "c6", "dxc6", "Nxc6", "Nf3", "e5", "dxe5", "Qxd1+", "Kxd1", "Ng4",
            ],
        },
        {
            "chapter": {"id": "vs-slav", "title": c("Contre la Slave — 2…c6", "vs the Slav — 2…c6")},
            "moves": [
                "d4", "d5", "c4", "c6", "Nf3",
                {"san": "Nf6",
                 "comment": c("Près d'un Noir sur deux joue ce développement, et le cours ne prévoyait que …dxc4. C'était l'un des plus gros manques du répertoire.",
                              "Nearly one Black player in two makes this developing move, and the course only planned for …dxc4. It was one of the repertoire's biggest gaps."),
                 "critical": True},
                "Nc3", "dxc4",
                {"san": "a4",
                 "comment": c("On empêche …b5 avant qu'il n'existe. Sans cette poussée, les Noirs garderaient le pion c4 et le fou c8 sortirait enfin — les deux choses que la Slave cherche.",
                              "We stop …b5 before it exists. Without that push Black would keep the c4 pawn and finally free the c8 bishop — the two things the Slav is after."),
                 "critical": True},
                "Bf5", "Ne5", "Nbd7", "Nxc4", "Nb6", "Ne5", "Nbd7",
            ],
        },
        {
            "chapter": {"id": "exchange-qgd", "title": c("Variante d'échange — 3.cxd5", "Exchange Variation — 3.cxd5")},
            "moves": [
                "d4", "d5", "c4", "e6", "cxd5", "exd5", "Nc3", "Nf6", "Bg5",
                {"san": "Be7",
                 "comment": c("Près d'un Noir sur deux brise le clouage en développant, et le cours ne voyait que …c6.",
                              "Nearly one Black player in two breaks the pin by developing, and the course only saw …c6."),
                 "critical": True},
                "e3", "h6", "Bh4", "c6",
                {"san": "Bd3",
                 "comment": c("L'attaque de minorité se prépare : nos pions b et a avanceront à l'aile dame pour créer une faiblesse durable en c6. C'est le plan qui donne son sens à l'échange en d5.",
                              "The minority attack takes shape: our a- and b-pawns will advance on the queenside to create a lasting weakness on c6. That plan is what makes the d5 exchange worthwhile."),
                 "critical": True},
                "Ne4", "Bxe7", "Qxe7", "Bxe4", "dxe4",
            ],
        },
        {
            "chapter": {"id": "vs-qga", "title": c("Contre le gambit accepté — 2…dxc4", "vs the Accepted — 2…dxc4")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e3",
                {"san": "Nf6",
                 "comment": c("Un Noir sur cinq développe avant …e6, et le cours ne prévoyait que …e6.",
                              "One Black player in five develops before …e6, and the course only planned for …e6."),
                 "critical": True},
                "Nf3", "e6", "Bxc4", "a6", "O-O", "c5", "dxc5",
                {"san": "Bxc5",
                 "comment": c("Les Noirs récupèrent le pion et proposent l'échange des dames. On accepte : le roi noir perd le roque, et une finale à structure saine nous convient.",
                              "Black regains the pawn and offers the queen trade. We accept: Black's king loses castling, and a healthy-structure endgame suits us."),
                 "critical": True},
                "Qxd8+", "Kxd8",
            ],
        },
        {
            "chapter": {"id": "vs-qga", "title": c("Contre le gambit accepté — 2…dxc4", "vs the Accepted — 2…dxc4")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e3",
                {"san": "b5",
                 "comment": c("La tentative de garder le pion — un Noir sur cinq — et il faut connaître la punition, elle est nette.",
                              "The attempt to keep the pawn — one Black player in five — and the punishment must be known, it is clear-cut."),
                 "critical": True},
                "a4",
                {"san": "b4",
                 "comment": c("Ils avancent au lieu d'échanger. Le pion b4 est désormais seul, loin de ses bases, et il ne défend plus c4.",
                              "They push instead of trading. The b4 pawn is now alone, far from home, and no longer defends c4."),
                 "critical": True},
                {"san": "Qf3",
                 "comment": c("La dame frappe simultanément a8 et le pion c4 indéfendable. C'est le coup qui rend cette ligne franchement mauvaise pour les Noirs.",
                              "The queen hits a8 and the undefendable c4 pawn at the same time. This is the move that makes the whole line plainly bad for Black."),
                 "critical": True},
                "c6", "Bxc4", "e6", "Ne2", "Nf6", "e4", "Bb7",
            ],
        },
    ],
}
