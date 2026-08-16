# -*- coding: utf-8 -*-
"""Contre-gambit Albin (1.d4 d5 2.c4 e5) — NOIR.

On rend un pion pour un coin de pion avancé en d4, très gênant, et une attaque
rapide. Arbre : principale 3.dxe5 d4 4.Cf3, le piège de Lasker (4.e3??), et la
ligne 5.a3. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "albin-countergambit",
    "name": "Albin Countergambit",
    "side": "black",
    "level": "club",
    "eco": ["D08", "D09"],
    "summary": c(
        "Un contre-gambit piquant : on sacrifie e5 pour planter un pion en d4, épine permanente dans le camp blanc, et jouer vite à l'attaque. Douteux au fond, mais mordant et piégeux.",
        "A pesky countergambit: sacrifice e5 to plant a pawn on d4, a permanent thorn in White's camp, and attack fast. Dubious deep down, but biting and full of traps.",
    ),
    "lines": [
        # 1) Principale — 3.dxe5 d4 4.Cf3
        {
            "chapter": {"id": "main", "title": c("Principale — 3.dxe5 d4 4.Cf3", "Main — 3.dxe5 d4 4.Nf3")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "e5", "eco": "Albin Countergambit",
                 "comment": c("Le contre-gambit Albin : on offre e5 pour avancer …d4 et prendre l'initiative.",
                              "The Albin Countergambit: offer e5 to push …d4 and seize the initiative.")},
                "dxe5",
                {"san": "d4", "comment": c("Le pion d4 est le cœur de l'Albin : avancé, protégé, il gêne tout le développement blanc.",
                                           "The d4 pawn is the heart of the Albin: advanced and protected, it cramps White's whole development.")},
                "Nf3", "Nc6", "g3", "Be6", "Bg2", "Qd7", "O-O", "O-O-O", "Nbd2", "Nge7",
            ],
        },
        # 2) Piège de Lasker — 4.e3??
        {
            "chapter": {"id": "lasker-trap", "title": c("Piège de Lasker — 4.e3??", "Lasker Trap — 4.e3??")},
            "moves": [
                "d4", "d5", "c4", "e5", "dxe5", "d4",
                {"san": "e3", "role": "trap", "critical": True,
                 "comment": c("Le coup naturel… mais perdant : ouvrir en e3 tombe dans le célèbre piège de Lasker.",
                              "The natural move… but losing: opening with e3 walks into the famous Lasker Trap.")},
                "Bb4+", "Bd2", "dxe3",
                {"san": "Bxb4", "role": "trap",
                 "comment": c("La seconde erreur, la fatale : reprendre le fou laisse le pion e3 filer. fxe3 était obligatoire.",
                              "The second mistake, the fatal one: recapturing the bishop lets the e3 pawn run. fxe3 was forced.")},
                {"san": "exf2+", "comment": c("Le pion file : échec, et la sous-promotion suit.",
                                              "The pawn races on: check, and the underpromotion follows.")},
                "Ke2",
                {"san": "fxg1=N+", "critical": True,
                 "comment": c("SOUS-PROMOTION en cavalier avec échec ! (Une dame permettrait Txg1.) Les Noirs gagnent du matériel — le piège de Lasker.",
                              "UNDERPROMOTION to a knight with check! (A queen would allow Rxg1.) Black wins material — the Lasker Trap.")},
            ],
        },
        # 3) 5.a3
        {
            "chapter": {"id": "a3", "title": c("5.a3", "5.a3")},
            "moves": [
                "d4", "d5", "c4", "e5", "dxe5", "d4", "Nf3", "Nc6",
                {"san": "a3", "comment": c("Les Blancs préparent b4 pour l'espace ; …a5 fige l'aile dame et garde le bon jeu.",
                                           "White prepares b4 for space; …a5 freezes the queenside and keeps good play.")},
                "a5", "Nbd2", "Nge7", "g3", "Ng6", "Bg2", "Ngxe5",
            ],
        },

        # ── Sans c4, il n'y a pas de contre-gambit (16/08) ────────────────────
        #
        # L'Albin EST 1.d4 d5 2.c4 e5. Contre la London ou 2.Cf3, le sacrifice
        # n'existe pas : le dire vaut mieux que laisser chercher un coup qui
        # n'a plus de sens.
        {
            "chapter": {"id": "no-c4", "title": c("Si les Blancs ne jouent pas c4", "If White doesn't play c4")},
            "moves": [
                "d4", "d5",
                {"san": "Bf4",
                 "comment": c("La London. Pas de c4, donc pas d'Albin : …e5 ne serait plus un gambit mais un pion donné pour rien.",
                              "The London. No c4, so no Albin: …e5 would no longer be a gambit but a pawn given away."),
                 "critical": True},
                {"san": "c5",
                 "comment": c("Le même esprit que le contre-gambit — frapper d4 sans attendre — mais avec un coup sain.",
                              "The same spirit as the countergambit — hit d4 without delay — but with a sound move."),
                 "critical": True},
                "e3", "Nc6", "Nf3",
                {"san": "Bg4",
                 "comment": c("On cloue le défenseur de d4. C'est la méthode contre tous les systèmes qui bâtissent ce pion sans le soutenir par c3 assez tôt.",
                              "We pin the defender of d4. That's the method against every system that builds this pawn without supporting it with c3 in time.")},
                "c3", "cxd4", "exd4",
            ],
        },
    ],
}
