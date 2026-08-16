# -*- coding: utf-8 -*-
"""Ouverture Réti (1.Cf3 d5 2.c4) — répertoire BLANC.

Une ouverture de flanc hypermoderne : on attaque d5 de loin, souvent avec un
(double) fianchetto. Arbre : 2…d4 (avance), 2…dxc4 (accepté), 2…c6 (Réti-Slave
double fianchetto). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "reti-opening",
    "name": "Réti Opening",
    "side": "white",
    "level": "club",
    "eco": ["A09", "A11"],
    "summary": c(
        "L'ouverture hypermoderne par excellence : 1.Cf3 puis c4 et un fianchetto en g2. On ne prend pas le centre, on le mine à distance. Souple, positionnelle, peu de théorie forcée.",
        "The hypermodern opening par excellence: 1.Nf3 then c4 and a g2 fianchetto. Don't occupy the centre — undermine it from afar. Flexible, positional, little forced theory.",
    ),
    "lines": [
        # 1) 2…d4 (avance)
        {
            "chapter": {"id": "advance", "title": c("2…d4 (avance)", "2…d4 (advance)")},
            "moves": [
                {"san": "Nf3", "eco": "Réti Opening",
                 "comment": c("On développe et on garde le centre souple : c4 et Fg2 suivront pour presser d5.",
                              "Develop and keep the centre flexible: c4 and Bg2 will follow to pressure d5.")},
                "d5",
                {"san": "c4", "comment": c("Le gambit Réti : on offre c4 pour dévier d5 et ouvrir le fou g2.",
                                           "The Réti Gambit: offer c4 to deflect d5 and open the g2 bishop.")},
                {"san": "d4", "comment": c("Les Noirs avancent ; on la contourne par g3 et un jeu à la Benoni inversé.",
                                           "Black pushes; White plays around it with g3 and reversed-Benoni play.")},
                "g3", "Nc6", "Bg2", "e5", "d3", "Nf6", "O-O", "Be7", "e3", "O-O",
            ],
        },
        # 2) 2…dxc4 (accepté)
        {
            "chapter": {"id": "accepted", "title": c("2…dxc4 (accepté)", "2…dxc4 (accepted)")},
            "moves": [
                "Nf3", "d5", "c4",
                {"san": "dxc4", "comment": c("Accepté : les Noirs ne garderont pas c4 ; les Blancs le récupèrent et gardent l'initiative.",
                                             "Accepted: Black won't hold c4; White regains it and keeps the initiative.")},
                "e3", "Nf6", "Bxc4", "e6", "O-O", "c5", "Qe2", "Nc6", "Rd1", "a6",
            ],
        },
        # 3) 2…c6 (Réti-Slave, double fianchetto)
        {
            "chapter": {"id": "slav-reti", "title": c("2…c6 — double fianchetto", "2…c6 — double fianchetto")},
            "moves": [
                "Nf3", "d5", "c4", "c6",
                {"san": "g3", "comment": c("Le double fianchetto : Fg2 puis b3+Fb2 encadrent le centre noir des deux côtés.",
                                           "The double fianchetto: Bg2 then b3+Bb2 clamp Black's centre from both sides.")},
                "Nf6", "Bg2", "Bf5", "O-O", "e6", "b3", "Be7", "Bb2", "O-O", "d3", "h6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-e6", "title": c("2…e6 — la défense solide", "2…e6 — the solid defence")},
            "moves": [
                "Nf3", "d5", "c4",
                {"san": "e6",
                 "comment": c("Les Noirs soutiennent d5 sans se découvrir. Le cours partait de …d4 ou …c6 : c'est la réponse la plus sobre, et elle manquait.",
                              "Black supports d5 without committing. The course started from …d4 or …c6: this is the soberest reply, and it was missing."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("Transposition assumée vers un jeu de pions dames. Le Réti n'est pas une religion : quand les Noirs jouent solidement, on prend le centre.",
                              "A deliberate transposition into a queen's pawn game. The Réti is no religion: when Black plays solidly, we take the centre.")},
                "Nf6", "Nc3", "c5", "cxd5", "cxd4", "Qxd4",
            ],
        },
        {
            "chapter": {"id": "advance", "title": c("2…d4 — le pion avancé", "2…d4 — the advanced pawn")},
            "moves": [
                "Nf3", "d5", "c4", "d4", "g3",
                {"san": "c5",
                 "comment": c("Plus d'un Noir sur deux soutient son pion ici, et le chapitre continuait autrement. Ils bâtissent un coin de pions qu'il faudra saper, pas attaquer de front.",
                              "More than half of Black players support the pawn here, and the chapter went elsewhere. They build a pawn wedge that must be undermined, not stormed."),
                 "critical": True},
                "Bg2", "Nc6", "e3",
                {"san": "e5",
                 "comment": c("Les Noirs tiennent le centre. Notre plan : exd4, puis pression sur la colonne e et sur le pion d4 devenu isolé.",
                              "Black holds the centre. Our plan: exd4, then pressure down the e-file and against the now isolated d4 pawn.")},
                "d3", "Nf6", "O-O",
            ],
        },
    ],
}
