# -*- coding: utf-8 -*-
"""Défense Caro-Kann (1.e4 c6) — répertoire NOIR.

Arbre approfondi : Classique 4…Ff5 (grande ligne jusqu'au roque opposé) et
4…Cd7 (Karpov), Avance, attaque Panov, Échange, Fantaisie 3.f3, Deux Cavaliers
2.Cc3 & Cf3. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "caro-kann",
    "name": "Caro-Kann Defense",
    "side": "black",
    "level": "club",
    "eco": ["B10", "B19"],
    "summary": c(
        "La solidité incarnée : comme la française, les Noirs jouent …d5, mais SANS enfermer leur fou de cases blanches, qui sort en f5. Structure saine, plan clair.",
        "Solidity itself: like the French, Black plays …d5 — but WITHOUT shutting in the light-squared bishop, which comes out to f5. Sound structure, clear plan.",
    ),
    "lines": [
        # 1) Classique 4…Ff5 (ligne principale)
        {
            "chapter": {"id": "classical", "title": c("Variante classique — 4…Ff5", "Classical — 4…Bf5")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "Nc3", "comment": c("Le développement classique ; les Noirs vont prendre en e4 et sortir leur fou.",
                                            "The classical development; Black will take on e4 and free the bishop.")},
                "dxe4", "Nxe4",
                {"san": "Bf5", "eco": "Caro-Kann Defense: Classical Variation",
                 "comment": c("Toute l'idée de la Caro : le fou sort AVANT …e6. Aucune pièce enfermée.",
                              "The whole point of the Caro: the bishop develops BEFORE …e6. No piece shut in.")},
                "Ng3", "Bg6", "h4", "h6", "Nf3", "Nd7",
                {"san": "h5", "comment": c("Le pion h chasse le fou dans son dernier refuge.",
                                           "The h-pawn chases the bishop to its last refuge.")},
                "Bh7", "Bd3",
                {"san": "Bxd3", "comment": c("On échange le bon fou blanc pour désamorcer l'attaque à l'aile roi.",
                                             "Trade off White's good bishop to defuse the kingside attack.")},
                "Qxd3", "e6",
                {"san": "Bf4", "comment": c("Les Blancs développent et roquent long ; les Noirs feront de même à gauche… ou à droite.",
                                            "White develops and castles long; Black will do likewise — or the other way.")},
                "Ngf6", "O-O-O", "Be7", "Kb1", "O-O",
            ],
        },
        # 2) Classique — 4…Cd7 (Karpov)
        {
            "chapter": {"id": "karpov", "title": c("Karpov — 4…Cd7", "Karpov — 4…Nd7")},
            "moves": [
                "e4", "c6", "d4", "d5", "Nc3", "dxe4", "Nxe4",
                {"san": "Nd7", "eco": "Caro-Kann Defense: Karpov Variation",
                 "comment": c("La Karpov : …Cd7 avant …Cgf6, pour reprendre du cavalier sans casser les pions.",
                              "The Karpov: …Nd7 before …Ngf6, so the knight can recapture without wrecking the pawns.")},
                "Nf3", "Ngf6", "Nxf6+", "Nxf6",
                {"san": "Bd3", "comment": c("Structure ultra-solide ; les Noirs choisissent un plan de fianchetto discret.",
                                            "A rock-solid structure; Black opts for a quiet fianchetto plan.")},
                "g6", "O-O", "Bg7", "Re1", "O-O", "c3", "Bg4",
            ],
        },
        # 3) Avance
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance", "Advance Variation")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "e5", "eco": "Caro-Kann Defense: Advance Variation",
                 "comment": c("L'avance : le centre se ferme. Contrairement à la française, le fou noir respire.",
                              "The Advance: the centre closes. Unlike the French, Black's bishop breathes.")},
                {"san": "Bf5", "comment": c("Le fou sort immédiatement — c'est le grand avantage sur la française.",
                                            "The bishop comes out at once — the big edge over the French.")},
                "Nf3", "e6", "Be2", "c5", "O-O", "Nc6", "c3",
                {"san": "Qb6", "comment": c("On pèse sur d4 et b2 ; les Noirs ont un jeu facile et sans faiblesse.",
                                            "Pressing on d4 and b2; Black has an easy, weakness-free game.")},
            ],
        },
        # 4) Attaque Panov
        {
            "chapter": {"id": "panov", "title": c("Attaque Panov", "Panov Attack")},
            "moves": [
                "e4", "c6", "d4", "d5", "exd5", "cxd5",
                {"san": "c4", "eco": "Caro-Kann Defense: Panov Attack",
                 "comment": c("L'attaque Panov : jeu ouvert avec pion isolé — plus dynamique que le reste de la Caro.",
                              "The Panov Attack: open play with an isolated pawn — more dynamic than the rest of the Caro.")},
                "Nf6", "Nc3", "e6", "Nf3", "Be7", "cxd5", "Nxd5", "Bd3", "Nc6", "O-O", "O-O",
            ],
        },
        # 5) Échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "c6", "d4", "d5", "exd5", "cxd5",
                {"san": "Bd3", "eco": "Caro-Kann Defense: Exchange Variation",
                 "comment": c("L'échange tranquille : structure symétrique, les Noirs égalisent sans difficulté.",
                              "The quiet exchange: symmetrical structure, Black equalises easily.")},
                "Nc6", "c3", "Nf6", "Bf4", "Bg4", "Qb3", "Qd7", "Nd2", "e6", "Ngf3", "Bd6",
            ],
        },
        # 6) Fantaisie — 3.f3
        {
            "chapter": {"id": "fantasy", "title": c("Variante Fantaisie — 3.f3", "Fantasy Variation — 3.f3")},
            "moves": [
                "e4", "c6", "d4", "d5",
                {"san": "f3", "eco": "Caro-Kann Defense: Fantasy Variation",
                 "comment": c("La Fantaisie : les Blancs soutiennent e4 à tout prix. Frapper le centre est la bonne réaction.",
                              "The Fantasy: White props up e4 at all costs. Striking the centre is the right reaction.")},
                "e6", "Nc3", "Bb4", "a3", "Bxc3+", "bxc3", "dxe4", "fxe4",
                {"san": "Qh4+", "critical": True,
                 "comment": c("La punition de 3.f3 : la case h4 est ouverte et le roi blanc n'a plus de refuge.",
                              "The punishment for 3.f3: h4 is open and the white king has nowhere to hide.")},
                "Ke2", "Qxe4+", "Kf2",
                {"san": "Qh4+",
                 "comment": c("Un pion de plus et un roi blanc à l'air libre : les Noirs sont nettement mieux.",
                              "A pawn up and the white king out in the open: Black is clearly better.")},
                "g3",
            ],
        },
        # 7) Deux Cavaliers — 2.Cc3 & 3.Cf3
        {
            "chapter": {"id": "two-knights", "title": c("Deux Cavaliers — 2.Cc3 & Cf3", "Two Knights — 2.Nc3 & Nf3")},
            "moves": [
                "e4", "c6",
                {"san": "Nc3", "comment": c("Les Deux Cavaliers : les Blancs jouent vite et gardent la tension centrale.",
                                            "The Two Knights: White develops quickly and keeps the central tension.")},
                "d5", "Nf3",
                {"san": "Bg4", "comment": c("On cloue le cavalier f3 avant qu'il ne soutienne un centre blanc.",
                                            "Pin the f3-knight before it can prop up a White centre.")},
                "h3", "Bxf3", "Qxf3", "Nf6", "d3", "e6", "g3", "Bc5",
            ],
        },
    ],
}
