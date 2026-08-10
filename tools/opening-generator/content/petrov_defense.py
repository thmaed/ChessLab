# -*- coding: utf-8 -*-
"""Défense russe / Petrov (1.e4 e5 2.Cf3 Cf6) — répertoire NOIR.

Arbre approfondi : ligne principale 3.Cxe5 (jusqu'au milieu de jeu symétrique),
attaque Steinitz 3.d4, attaque Nimzowitsch 5.Cc3, et le piège de l'ordre des
coups 3…Cxe4?!. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "petrov-defense",
    "name": "Petrov Defense",
    "side": "black",
    "level": "club",
    "eco": ["C42", "C43"],
    "summary": c(
        "La défense de la solidité : au lieu de défendre e5, les Noirs contre-attaquent e4 par symétrie. Réputation d'égalité tenace — la bête noire des joueurs d'attaque.",
        "The defence of solidity: instead of defending e5, Black counterattacks e4 by symmetry. A famously tough equaliser — the bane of attacking players.",
    ),
    "lines": [
        # 1) Ligne principale — 3.Cxe5
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3.Cxe5", "Main Line — 3.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6", "eco": "Petrov Defense",
                 "comment": c("La symétrie : les Noirs répondent à l'attaque de e5 en attaquant e4.",
                              "Symmetry: Black meets the attack on e5 by attacking e4.")},
                {"san": "Nxe5", "comment": c("Attention : reprendre tout de suite par …Cxe4 est une erreur. D'abord …d6 !",
                                             "Careful: recapturing with …Nxe4 at once is a mistake. First …d6!")},
                {"san": "d6", "comment": c("On chasse le cavalier AVANT de reprendre en e4 : l'ordre des coups est capital.",
                                           "Kick the knight BEFORE taking on e4: move order is crucial.")},
                "Nf3", "Nxe4", "d4", "d5",
                {"san": "Bd3", "comment": c("Position type de la Petrov : symétrique, saine, réputée pour son égalité.",
                                            "The typical Petrov position: symmetrical, sound, famous for equality.")},
                "Bd6", "O-O", "O-O", "c4", "c6", "cxd5", "cxd5", "Nc3", "Nxc3", "bxc3", "Bg4",
            ],
        },
        # 2) Attaque Steinitz — 3.d4
        {
            "chapter": {"id": "steinitz", "title": c("Attaque Steinitz — 3.d4", "Steinitz Attack — 3.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "d4", "eco": "Petrov Defense: Steinitz Variation",
                 "comment": c("Les Blancs ouvrent le centre plutôt que de prendre e5. …Cxe4 est correct.",
                              "White opens the centre instead of taking e5. …Nxe4 is correct.")},
                "Nxe4", "Bd3", "d5", "Nxe5", "Nd7", "Nxd7", "Bxd7", "O-O", "Bd6", "c4", "c6", "Nc3", "Nxc3", "bxc3", "O-O",
            ],
        },
        # 3) Attaque Nimzowitsch — 5.Cc3
        {
            "chapter": {"id": "nimzowitsch", "title": c("Nimzowitsch — 5.Cc3", "Nimzowitsch — 5.Nc3")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6", "Nxe5", "d6", "Nf3", "Nxe4",
                {"san": "Nc3", "comment": c("Au lieu de d4, les Blancs proposent l'échange des cavaliers pour un léger avantage d'espace.",
                                            "Instead of d4, White offers a knight trade for a slight space edge.")},
                "Nxc3", "dxc3", "Be7", "Be3", "O-O", "Qd2", "Nd7", "O-O-O", "Ne5",
            ],
        },
        # 4) Piège de l'ordre des coups — 3…Cxe4?!
        {
            "chapter": {"id": "move-order-trap", "title": c("Piège — 3…Cxe4?!", "Trap — 3…Nxe4?!")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6", "Nxe5",
                {"san": "Nxe4", "role": "inaccuracy", "critical": True,
                 "comment": c("Le mauvais ordre : on reprend sans chasser le cavalier. Piège classique en vue.",
                              "The wrong order: recapturing without kicking the knight first. A classic trap looms.")},
                {"san": "Qe2", "role": "trap",
                 "comment": c("Le clouage mortel : après 4…Cf6?? 5.Cc6+ ! gagne la dame. Le SEUL coup est 4…De7.",
                              "The deadly pin: after 4…Nf6?? 5.Nc6+! wins the queen. The ONLY move is 4…Qe7.")},
                {"san": "Qe7", "comment": c("On oppose la dame et on prépare la fourchette …d6 : les Blancs ne peuvent garder le butin.",
                                            "Oppose queens and prepare the …d6 fork: White cannot keep the loot.")},
                "Qxe4", "d6", "d4", "dxe5", "dxe5", "Nc6",
            ],
        },
    ],
}
