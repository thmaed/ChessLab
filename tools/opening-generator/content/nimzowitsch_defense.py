# -*- coding: utf-8 -*-
"""Défense Nimzowitsch (1.e4 Cc6) — NOIR.

Provocante et hypermoderne : …Cc6 dès le 1er coup, on invite d4-d5 pour attaquer
le centre à revers. Arbre : 2.d4 d5 3.Cc3 et 2.d4 d5 3.e5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "nimzowitsch-defense",
    "name": "Nimzowitsch Defense",
    "side": "black",
    "level": "club",
    "eco": ["B00"],
    "summary": c(
        "Une arme de surprise hypermoderne : 1…Cc6 invite les Blancs à avancer d4-d5, puis on harcèle ce centre. Peu de théorie connue de l'adversaire — son grand atout.",
        "A hypermodern surprise weapon: 1…Nc6 invites White to push d4-d5, then Black harasses that centre. Its big plus: opponents rarely know the theory.",
    ),
    "lines": [
        # 1) 2.d4 d5 3.Cc3
        {
            "chapter": {"id": "nc3", "title": c("2.d4 d5 3.Cc3", "2.d4 d5 3.Nc3")},
            "moves": [
                "e4",
                {"san": "Nc6", "eco": "Nimzowitsch Defense",
                 "comment": c("Le coup Nimzowitsch : le cavalier sort avant les pions, prêt à mordre le centre blanc.",
                              "The Nimzowitsch move: the knight comes out before the pawns, ready to bite the centre.")},
                "d4",
                {"san": "d5", "comment": c("On frappe e4 tout de suite ; la partie prend un tour concret.",
                                           "Strike e4 at once; the game turns concrete.")},
                "Nc3", "dxe4", "d5", "Ne5", "Qd4", "Ng6", "Nxe4", "Nf6",
            ],
        },
        # 2) 2.d4 d5 3.e5 (avance)
        {
            "chapter": {"id": "advance", "title": c("2.d4 d5 3.e5 (avance)", "2.d4 d5 3.e5 (advance)")},
            "moves": [
                "e4", "Nc6", "d4", "d5",
                {"san": "e5", "comment": c("L'avance ferme le centre ; le fou noir sort en f5 avant …e6, comme dans une Caro-Kann d'avance.",
                                           "The advance closes the centre; Black's bishop comes to f5 before …e6, as in an Advance Caro-Kann.")},
                "Bf5", "Ne2", "e6", "Ng3", "Bg6", "h4", "h5",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-nf3", "title": c("2.Cf3 — le coup le plus fréquent", "2.Nf3 — the most common move")},
            "moves": [
                "e4", "Nc6",
                {"san": "Nf3",
                 "comment": c("LE trou principal du cours : quatre parties sur dix, et aucune réponse. L'élève sortait du répertoire au deuxième coup.",
                              "The course's main hole: four games in ten, and no answer at all. The student left the repertoire at move two."),
                 "critical": True},
                {"san": "e5",
                 "comment": c("On transpose volontairement dans un jeu ouvert : avec le cavalier déjà en c6, c'est une partie italienne ou espagnole ordinaire, terrain connu.",
                              "We deliberately transpose into an open game: with the knight already on c6, it's an ordinary Italian or Ruy Lopez — familiar ground."),
                 "critical": True},
                "Bc4", "Nf6",
                {"san": "Ng5",
                 "comment": c("Les Deux Cavaliers. À connaître : la réponse est …d5, et surtout PAS …Cxd5 ensuite.",
                              "The Two Knights. Know this: the reply is …d5, and definitely NOT …Nxd5 afterwards.")},
                "d5", "exd5",
                {"san": "Na5", "critical": True,
                 "comment": c("La bonne défense. Reprendre en d5 perd sur Cxf7 — c'est le piège que tout joueur de 4.Cg5 espère.",
                              "The right defence. Recapturing on d5 loses to Nxf7 — the trap every 4.Ng5 player is hoping for.")},
            ],
        },
        {
            "chapter": {"id": "vs-d4", "title": c("2.d4 d5 — la ligne principale", "2.d4 d5 — the main line")},
            "moves": [
                "e4", "Nc6", "d4", "d5",
                {"san": "exd5",
                 "comment": c("Plus d'un quart des parties après …d5, et le cours n'y répondait pas.",
                              "Over a quarter of games after …d5, and the course had no reply.")},
                {"san": "Qxd5",
                 "comment": c("On reprend à la dame : le cavalier c6 la défend déjà, et Cc3 ne gagne donc pas de temps comme dans la Scandinave.",
                              "We recapture with the queen: the c6 knight already guards her, so Nc3 gains no tempo as it would in the Scandinavian."),
                 "critical": True},
                "Ne2", "Nf6", "Nbc3", "Qa5", "Be3",
            ],
        },
    ],
}
