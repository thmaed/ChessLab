# -*- coding: utf-8 -*-
"""Partie du centre & gambit danois (1.e4 e5 2.d4 exd4) — répertoire BLANC.

Ouvrir le centre d'entrée : 3.Dxd4 (partie du centre, Dame en e3 et grand roque)
ou 3.c3 (gambit danois, deux pions pour une attaque fulgurante). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "center-game",
    "name": "Center Game",
    "side": "white",
    "level": "club",
    "eco": ["C21", "C22"],
    "summary": c(
        "On ouvre le centre dès le 2e coup. Deux esprits : la partie du centre (3.Dxd4, Dame en e3 et grand roque agressif) ou le gambit danois (3.c3, deux pions pour un développement et une attaque éclair).",
        "Open the centre on move two. Two flavours: the Center Game (3.Qxd4, queen to e3 and aggressive long castling) or the Danish Gambit (3.c3, two pawns for lightning development and attack).",
    ),
    "lines": [
        # 1) Partie du centre — 3.Dxd4
        {
            "chapter": {"id": "center", "title": c("Partie du centre — 3.Dxd4", "Center Game — 3.Qxd4")},
            "moves": [
                "e4", "e5", "d4", "exd4",
                {"san": "Qxd4", "eco": "Center Game",
                 "comment": c("On reprend de la dame ; …Cc6 gagne un temps mais la dame trouve un bon poste en e3.",
                              "Recapture with the queen; …Nc6 gains a tempo, but the queen finds a good post on e3.")},
                "Nc6",
                {"san": "Qe3", "comment": c("La dame se met à l'abri en e3, prépare Cc3, Fd2 et le grand roque agressif.",
                                            "The queen tucks into e3, preparing Nc3, Bd2 and aggressive long castling.")},
                "Nf6", "Nc3", "Be7", "Bd2", "O-O", "O-O-O", "d6", "f3", "a6",
            ],
        },
        # 2) Gambit danois — 3.c3
        {
            "chapter": {"id": "danish", "title": c("Gambit danois — 3.c3", "Danish Gambit — 3.c3")},
            "moves": [
                "e4", "e5", "d4", "exd4",
                {"san": "c3", "comment": c("Le gambit danois : on offre un, puis deux pions pour un développement et une attaque foudroyants.",
                                           "The Danish Gambit: offer one, then two pawns for blazing development and attack.")},
                "dxc3", "Bc4", "cxb2", "Bxb2",
                {"san": "d5", "comment": c("La parade nette : les Noirs RENDENT les pions par …d5 pour égaliser et neutraliser les fous.",
                                           "The clean antidote: Black GIVES the pawns back with …d5 to equalise and blunt the bishops.")},
                "Bxd5", "Nf6", "Bxf7+", "Kxf7", "Qxd8", "Bb4+", "Qd2", "Bxd2+", "Nxd2",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-d6", "title": c("4…d6 — l'installation solide", "4…d6 — the solid setup")},
            "moves": [
                "e4", "e5", "d4", "exd4", "Qxd4", "Nc6", "Qe3",
                {"san": "d6",
                 "comment": c("La réponse la plus fréquente, et le cours partait d'ailleurs. Les Noirs ouvrent leur fou et attendent.",
                              "The most common reply, and the course started elsewhere. Black frees the bishop and waits."),
                 "critical": True},
                {"san": "Bd2",
                 "comment": c("Le fou prépare le grand roque : c'est tout le sel de la Partie du Centre, sinon la sortie précoce de la dame ne rapporte rien.",
                              "The bishop prepares long castling: that's the whole point of the Centre Game — otherwise the early queen sortie gains nothing.")},
                "Nf6", "Nc3", "Be7", "O-O-O",
                {"san": "O-O",
                 "comment": c("Rois opposés. On attaque par g4-h4 pendant qu'ils cherchent encore leur plan.",
                              "Opposite castling. We attack with g4-h4 while they're still looking for a plan.")},
            ],
        },
        {
            "chapter": {"id": "vs-b6", "title": c("4…b6 — le fianchetto", "4…b6 — the fianchetto")},
            "moves": [
                "e4", "e5", "d4", "exd4", "Qxd4", "Nc6", "Qe3",
                {"san": "b6",
                 "comment": c("Une partie sur cinq : les Noirs veulent …Fa6 pour échanger le fou f1 et empêcher le roque.",
                              "One game in five: Black wants …Ba6 to trade the f1 bishop and stop us castling.")},
                "Nc3",
                {"san": "Nb4",
                 "comment": c("Le cavalier vise c2 et d3. On ne panique pas : la dame se déplace, et le cavalier b4 finira mal placé.",
                              "The knight eyes c2 and d3. Don't panic: the queen steps aside and the b4 knight ends up misplaced.")},
                "Qe2", "Ba6", "Qd1", "Bxf1", "Kxf1",
                {"san": "Bc5",
                 "comment": c("Nous avons perdu le roque, eux la paire de fous et deux temps. Le compte est en notre faveur.",
                              "We've lost castling rights; they've lost the bishop pair and two tempi. The balance favours us.")},
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,87). Chemins par
        # `path_to_hole.py`, lignes au moteur à profondeur 21. ───────────────
        {
            "chapter": {"id": "center-main", "title": c("Partie du centre — 3.Dxd4", "Center Game — 3.Qxd4")},
            "moves": [
                "e4", "e5", "d4",
                {"san": "Nc6",
                 "comment": c("Les Noirs refusent la prise et défendent e5 — un joueur sur neuf, et le cours ne voyait que …exd4.",
                              "Black declines the capture and defends e5 — one player in nine, and the course only saw …exd4."),
                 "critical": True},
                {"san": "d5",
                 "comment": c("On ferme au lieu d'échanger : le cavalier c6 est refoulé, et les Noirs se retrouvent avec une Espagnole fermée sans en avoir les compensations.",
                              "We close instead of trading: the c6 knight is pushed back, and Black ends up in a closed Ruy Lopez structure without its compensations."),
                 "critical": True},
                "Nce7", "Nf3", "Ng6",
                {"san": "h4",
                 "comment": c("Le pion attaque le cavalier g6 avant qu'il ne s'installe. Le centre étant bloqué, une avancée d'aile ne coûte rien.",
                              "The pawn hits the g6 knight before it settles. With the centre locked, a wing advance costs nothing."),
                 "critical": True},
                "h5", "Nc3", "Bc5", "Na4", "Be7",
            ],
        },
        {
            "chapter": {"id": "center-main", "title": c("Partie du centre — 3.Dxd4", "Center Game — 3.Qxd4")},
            "moves": [
                "e4", "e5", "d4", "exd4", "Qxd4", "Nc6", "Qe3", "Nf6", "Nc3",
                {"san": "Bb4",
                 "comment": c("Le clouage, joué une fois sur deux ici — et le cours ne prévoyait que …Fe7. Les Noirs visent le cavalier c3 pour affaiblir e4.",
                              "The pin, played half the time here — and the course only planned for …Be7. Black targets the c3 knight to weaken e4."),
                 "critical": True},
                {"san": "a3",
                 "comment": c("On demande une réponse tout de suite. S'ils prennent, notre dame se retrouve sur la grande diagonale et nos pions restent sains ; s'ils reculent, ils ont perdu un temps.",
                              "We ask the question at once. If they take, our queen lands on the long diagonal and our pawns stay healthy; if they retreat, they have lost a tempo."),
                 "critical": True},
                "Bxc3+", "Qxc3", "O-O", "f3", "d5", "Bg5", "dxe4", "Bxf6", "Qxf6",
            ],
        },
        {
            "chapter": {"id": "center-main", "title": c("Partie du centre — 3.Dxd4", "Center Game — 3.Qxd4")},
            "moves": [
                "e4", "e5", "d4", "exd4", "Qxd4", "Nc6", "Qe3", "b6", "Nc3",
                {"san": "Bc5",
                 "comment": c("Trois Noirs sur quatre développent ainsi après …b6, et le cours ne connaissait que …Cb4. Le fou vise notre dame en e3 — c'est justement ce qui va nous servir.",
                              "Three Black players in four develop like this after …b6, and the course only knew …Nb4. The bishop eyes our queen on e3 — which is exactly what will serve us."),
                 "critical": True},
                {"san": "Qg3",
                 "comment": c("La dame esquive VERS l'attaque : de g3 elle regarde g7 et le roque adverse, et c'est le fou qui devra s'expliquer.",
                              "The queen dodges TOWARDS the attack: from g3 she eyes g7 and Black's coming castled king, and it is the bishop that must explain itself."),
                 "critical": True},
                "Nf6", "Bd2", "O-O",
                {"san": "O-O-O",
                 "comment": c("Grand roque, la signature de la Partie du centre : les rois partent de chaque côté, et c'est une course d'attaques où nous avons un temps d'avance.",
                              "Castling long, the signature of the Center Game: the kings go to opposite wings, and it becomes a race of attacks in which we are a tempo ahead."),
                 "critical": True},
                "d5", "exd5", "Bd6", "Qh4", "Ne5",
            ],
        },
        {
            "chapter": {"id": "danish", "title": c("Gambit danois — 3.c3", "Danish Gambit — 3.c3")},
            "moves": [
                "e4", "e5", "d4", "exd4", "c3",
                {"san": "Nc6",
                 "comment": c("Les Noirs refusent le gambit et développent. Un joueur sur dix, et le cours ne prévoyait que la prise …dxc3.",
                              "Black declines the gambit and develops. One player in ten, and the course only planned for the capture …dxc3."),
                 "critical": True},
                {"san": "cxd4",
                 "comment": c("On reprend et on obtient ce que le gambit cherchait de toute façon : le grand centre, sans avoir rien payé.",
                              "We recapture and get what the gambit was after anyway: the big centre, without having paid for it."),
                 "critical": True},
                "d5", "e5", "f6", "Nf3", "fxe5", "Nxe5", "Nxe5", "dxe5", "Bc5",
            ],
        },
        {
            "chapter": {"id": "danish", "title": c("Gambit danois — 3.c3", "Danish Gambit — 3.c3")},
            "moves": [
                "e4", "e5", "d4", "exd4", "c3", "dxc3", "Bc4", "cxb2", "Bxb2",
                {"san": "Bb4+",
                 "comment": c("L'échec intercalé, joué par près d'un Noir sur trois — et le cours ne voyait que …d5. Ils cherchent à échanger avant que nos fous ne fassent leur travail.",
                              "The in-between check, played by nearly one Black player in three — and the course only saw …d5. They try to trade before our bishops get to work."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("On bloque avec une pièce qu'on développe. Deux pions offerts, deux fous en batterie sur le roque adverse et un développement complet : c'est le marché danois, et il tient tant qu'on ne ralentit pas.",
                              "We block with a piece we are developing anyway. Two pawns given, two bishops trained on Black's king and full development: that is the Danish bargain, and it holds as long as we never slow down."),
                 "critical": True},
                "Nf6", "Qb3", "Bxc3+", "Qxc3", "d6", "Ne2", "Be6", "O-O", "Nbd7",
            ],
        },
    ],
}
