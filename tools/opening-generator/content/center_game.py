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
    ],
}
