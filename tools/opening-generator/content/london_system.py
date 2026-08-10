# -*- coding: utf-8 -*-
"""Système Londres (1.d4 + Ff4) + Jobava Londres — répertoire BLANC.

Arbre approfondi : Londres contre …d5 (plan Ce5 + attaque), Jobava 2.Cc3,
contre le fianchetto …g6, et contre …c5 (avec le piège …Db6). Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "london-system",
    "name": "London System",
    "side": "white",
    "level": "club",
    "eco": ["D02", "A48"],
    "summary": c(
        "Un système facile à jouer contre presque tout : Ff4, e3, Fd3, c3, Cbd2. Peu de théorie, des plans solides et une attaque à l'aile roi souvent au menu.",
        "An easy system against almost everything: Bf4, e3, Bd3, c3, Nbd2. Little theory, solid plans and a kingside attack often on the menu.",
    ),
    "lines": [
        # 1) Londres contre …d5 (ligne principale)
        {
            "chapter": {"id": "main", "title": c("Londres contre …d5", "London vs …d5")},
            "moves": [
                "d4", "d5",
                {"san": "Bf4", "eco": "London System",
                 "comment": c("Le coup-signature : le fou sort AVANT e3, jamais enfermé.",
                              "The signature move: the bishop develops BEFORE e3, never shut in.")},
                "Nf6", "e3", "e6", "Nf3", "c5", "c3", "Nc6",
                {"san": "Nbd2", "comment": c("La formation type est complète ; suivra Fd3, puis Ce5 et une attaque.",
                                             "The standard formation is complete; Bd3 follows, then Ne5 and an attack.")},
                "Bd6",
                {"san": "Bg3", "comment": c("On garde le bon fou en le glissant en g3 plutôt que de l'échanger.",
                                            "Keep the good bishop by sliding it to g3 rather than trading.")},
                "O-O", "Bd3", "b6",
                {"san": "Ne5", "comment": c("Le cavalier s'installe sur son avant-poste : c'est le pivot de l'attaque londonienne.",
                                            "The knight lands on its outpost: the pivot of the London attack.")},
                "Bb7", "f4", "Ne4",
            ],
        },
        # 2) Jobava Londres — 2.Cc3
        {
            "chapter": {"id": "jobava", "title": c("Jobava Londres — 2.Cc3", "Jobava London — 2.Nc3")},
            "moves": [
                "d4", "Nf6",
                {"san": "Nc3", "comment": c("La version Jobava, plus mordante : le cavalier sort avant, prêt à jouer e4 ou Cb5.",
                                            "The sharper Jobava version: the knight develops first, ready for e4 or Nb5.")},
                "d5", "Bf4",
                {"san": "a6", "comment": c("Les Noirs préviennent le saut Cb5-c7 avant de continuer.",
                                           "Black rules out the Nb5-c7 jump before continuing.")},
                "e3", "e6", "Bd3", "c5", "dxc5", "Bxc5", "Nf3", "Nc6", "O-O", "O-O",
            ],
        },
        # 3) Contre le fianchetto …g6
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto — …g6", "vs the fianchetto — …g6")},
            "moves": [
                "d4", "Nf6", "Bf4", "g6",
                {"san": "Nc3", "comment": c("Contre …g6, la Londres tient très bien : e3, h4-h5 est même possible.",
                                            "Against …g6 the London holds up well: e3, and even h4-h5 is on.")},
                "d5", "e3", "Bg7",
                {"san": "h4", "comment": c("La ruée h4-h5 vise directement le roque adverse — la Londres a des dents.",
                                           "The h4-h5 rush aims straight at the enemy castled king — the London has teeth.")},
                "h5", "Bd3", "O-O", "Nf3", "c5",
            ],
        },
        # 4) Contre …c5 (et le piège …Db6)
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "d4", "Nf6", "Bf4", "c5", "e3",
                {"san": "Qb6", "comment": c("Le coup piquant : la dame attaque b2. Il faut connaître la parade.",
                                            "The pesky move: the queen hits b2. You must know the reply.")},
                {"san": "Nc3", "comment": c("On développe en menaçant Cb5 ; prendre b2 devient très dangereux pour les Noirs.",
                                            "Develop while threatening Nb5; grabbing b2 becomes very risky for Black.")},
                "e6", "Rb1", "Nc6", "Nf3", "Be7", "Bd3", "O-O", "O-O", "cxd4",
            ],
        },
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "d4", "Nf6", "Bf4", "c5", "e3", "Qb6", "Nc3",
                {"san": "Qxb2", "role": "inaccuracy", "critical": True,
                 "comment": c("Trop gourmand : prendre b2 laisse la dame se faire piéger.",
                              "Too greedy: grabbing b2 lets the queen get trapped.")},
                {"san": "Nb5", "role": "trap",
                 "comment": c("La réfutation : Cb5 menace Cc7+ fourchette, et la dame en b2 manque de cases. À éviter côté noir !",
                              "The refutation: Nb5 threatens the Nc7+ fork, and the b2-queen is short of squares. Avoid it as Black!")},
                "Na6", "Rb1", "Qxa2", "Ra1",
            ],
        },
    ],
}
