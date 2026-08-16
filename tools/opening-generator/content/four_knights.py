# -*- coding: utf-8 -*-
"""Partie des Quatre Cavaliers (1.e4 e5 2.Cf3 Cc6 3.Cc3 Cf6) — répertoire BLANC.

Arbre : espagnole des Quatre Cavaliers (4.Fb5, dégommage Metger), écossaise
des Quatre Cavaliers (4.d4), gambit Halloween (4.Cxe5). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "four-knights",
    "name": "Four Knights Game",
    "side": "white",
    "level": "club",
    "eco": ["C46", "C49"],
    "summary": c(
        "Développement symétrique et sain : les quatre cavaliers sortent, puis on choisit entre le calme espagnol (Fb5), l'ouverture du centre (écossaise) ou le chaos (Halloween).",
        "Sound symmetrical development: all four knights come out, then choose between the quiet Spanish (Bb5), opening the centre (Scotch) or chaos (Halloween).",
    ),
    "lines": [
        {
            "chapter": {"id": "spanish", "title": c("Espagnole — 4.Fb5", "Spanish — 4.Bb5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "Bb5", "eco": "Four Knights Game: Spanish Variation",
                 "comment": c("La version espagnole : symétrie parfaite. Les Blancs jouent la structure et le dégommage Metger.",
                              "The Spanish version: perfect symmetry. White plays the structure and the Metger unpin.")},
                "Bb4", "O-O", "O-O", "d3", "d6", "Bg5", "Bxc3", "bxc3", "Qe7", "Re1", "Nd8", "d4", "Ne6",
            ],
        },
        {
            "chapter": {"id": "scotch", "title": c("Écossaise — 4.d4", "Scotch — 4.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "d4", "comment": c("On ouvre le centre : jeu ouvert et actif où les Blancs gardent une petite initiative.",
                                           "Opening the centre: open, active play where White keeps a slight initiative.")},
                "exd4", "Nxd4", "Bb4", "Nxc6", "bxc6", "Bd3", "d5", "exd5", "cxd5", "O-O", "O-O", "Bg5", "c6",
            ],
        },
        {
            "chapter": {"id": "halloween", "title": c("Gambit Halloween — 4.Cxe5", "Halloween Gambit — 4.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6",
                {"san": "Nxe5", "comment": c("Le gambit Halloween : on sacrifie un cavalier pour chasser les pièces noires et prendre un centre monstrueux.",
                                             "The Halloween Gambit: sacrifice a knight to chase Black's pieces and grab a monster centre.")},
                "Nxe5", "d4", "Nc6", "d5", "Ne5", "f4", "Ng6", "e5", "Ng8", "d6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "italian-four-knights", "title": c("4…Fc5 — la Quatre Cavaliers italienne", "4…Bc5 — the Italian Four Knights")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3",
                {"san": "Bc5",
                 "comment": c("Plus d'un quart des parties, et le cours n'en parlait pas. Le fou en c5 laisse une faiblesse : le pion e5 n'a plus qu'un défenseur.",
                              "More than a quarter of games, and the course didn't mention it. The bishop on c5 leaves a weakness: the e5 pawn has only one defender."),
                 "critical": True},
                {"san": "Nxe5", "critical": True,
                 "comment": c("La fourchette classique : on prend, et si …Cxe5 alors d4 récupère la pièce en attaquant fou et cavalier à la fois.",
                              "The classic fork trick: we take, and if …Nxe5 then d4 regains the piece, hitting bishop and knight at once.")},
                "Nxe5", "d4",
                {"san": "Bd6",
                 "comment": c("Le seul coup : reculer en b6 ou b4 perdrait sur d5 ou dxe5.",
                              "The only move: retreating to b6 or b4 would lose to d5 or dxe5.")},
                "dxe5", "Bxe5", "Bd3",
            ],
        },
        {
            "chapter": {"id": "philidor-order", "title": c("2…d6 — l'ordre Philidor", "2…d6 — the Philidor order")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d6",
                 "comment": c("Les Noirs évitent la Quatre Cavaliers en défendant e5 par un pion. Le cours n'avait aucune réponse.",
                              "Black sidesteps the Four Knights by defending e5 with a pawn. The course had no answer.")},
                {"san": "d4",
                 "comment": c("On frappe tout de suite : la Philidor souffre de son manque d'espace, et c'est là qu'il faut le lui rappeler.",
                              "Strike at once: the Philidor suffers from a lack of space, and this is the moment to remind it.")},
                "exd4", "Nxd4", "Nf6", "Bd3", "Bd7", "Nc3", "Be7",
            ],
        },
        # La réfutation du gambit Halloween. Le chapitre laissait croire au
        # sacrifice sans dire ce qui l'arrête ; c'est précisément le reproche
        # que le testeur faisait au reste du répertoire.
        {
            "chapter": {"id": "halloween", "title": c("Gambit Halloween — 4.Cxe5", "Halloween Gambit — 4.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Nc3", "Nf6", "Nxe5", "Nxe5", "d4",
                {"san": "Ng6", "critical": True, "role": "trap",
                 "comment": c("LE coup qui réfute le gambit, joué par près d'un Noir sur deux. Le cavalier recule là où d4-d5 ne l'attaque plus. À connaître avant de se lancer : le Halloween est une arme de surprise, pas une ligne saine.",
                              "THE move that refutes the gambit, played by nearly half of Black players. The knight retreats where d4-d5 no longer hits it. Know this before you leap: the Halloween is a surprise weapon, not a sound line.")},
            ],
        },
    ],
}
