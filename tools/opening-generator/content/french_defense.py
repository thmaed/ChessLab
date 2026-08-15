# -*- coding: utf-8 -*-
"""Défense française (1.e4 e6) — répertoire NOIR.

Arbre approfondi : Winawer (pion empoisonné 7.Dg4 Dc7 et 7…0-0), Avance
(6.a3 et gambit Milner-Barry), Tarrasch (3…c5 ouverte et 3…Cf6 fermée),
Classique (Steinitz 4.e5 et 4.Fg5), Rubinstein 3…dxe4, Échange. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "french-defense",
    "name": "French Defense",
    "side": "black",
    "level": "club",
    "eco": ["C00", "C19"],
    "summary": c(
        "Solide et combative : les Noirs cèdent un peu d'espace pour frapper le centre par …c5 et …f6. Le seul souci, le fou de cases blanches, guide tout le plan.",
        "Solid and combative: Black concedes a little space to strike the centre with …c5 and …f6. The one problem piece, the light-squared bishop, shapes the whole plan.",
    ),
    "lines": [
        # 1) Winawer — pion empoisonné 7.Dg4 Dc7 (ligne principale)
        {
            "chapter": {"id": "winawer", "title": c("Winawer — 7.Dg4", "Winawer — 7.Qg4")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3",
                {"san": "Bb4", "eco": "French Defense: Winawer Variation",
                 "comment": c("La Winawer : on cloue le cavalier c3 pour désorganiser le centre blanc.",
                              "The Winawer: pin the c3 knight to disrupt White's centre.")},
                {"san": "e5", "comment": c("Le centre se ferme ; la bataille portera sur la chaîne de pions d4-e5.",
                                           "The centre closes; the fight will be about the d4-e5 pawn chain.")},
                "c5", "a3", "Bxc3+", "bxc3",
                {"san": "Ne7", "comment": c("Les Blancs ont la paire de fous, les Noirs des pions doublés à attaquer : jeu double-tranchant.",
                                            "White has the bishop pair, Black has doubled pawns to attack: double-edged play.")},
                {"san": "Qg4", "comment": c("Le coup critique : la dame attaque g7 et met à l'épreuve le roi noir.",
                                            "The critical move: the queen hits g7 and tests Black's king.")},
                {"san": "Qc7", "comment": c("La ligne du pion empoisonné : on laisse g7 pour arracher c3 et d4 en retour.",
                                            "The Poisoned Pawn line: give up g7 to grab c3 and d4 in return.")},
                "Qxg7", "Rg8", "Qxh7", "cxd4", "Ne2", "Nbc6", "f4",
                {"san": "dxc3", "comment": c("Chacun dévore l'aile de l'autre : la partie se joue au fil du rasoir.",
                                             "Each side devours the other's wing: play balances on a knife's edge.")},
            ],
        },
        # 2) Winawer — 7.Dg4 0-0
        {
            "chapter": {"id": "winawer-oo", "title": c("Winawer — 7.Dg4 0-0", "Winawer — 7.Qg4 0-0")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Bb4", "e5", "c5", "a3", "Bxc3+", "bxc3", "Ne7", "Qg4",
                {"san": "O-O", "comment": c("La version prudente : on roque au lieu de prendre le pion empoisonné.",
                                            "The safe version: castle instead of grabbing the poisoned pawn.")},
                "Bd3", "Nbc6", "Qh5", "Ng6", "Nf3", "Qc7", "Be3", "c4",
            ],
        },
        # 3) Avance — 6.a3
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance — 6.a3", "Advance Variation — 6.a3")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "e5", "eco": "French Defense: Advance Variation",
                 "comment": c("L'avance : les Blancs ferment le centre. Les Noirs vont assiéger la base d4.",
                              "The Advance: White closes the centre. Black will besiege the d4 base.")},
                {"san": "c5", "comment": c("Le coup de rupture typique : on attaque d4 à sa racine.",
                                           "The typical break: hitting d4 at its root.")},
                "c3", "Nc6", "Nf3",
                {"san": "Qb6", "comment": c("La dame vise b2 et surtout d4 : la pression s'accumule.",
                                            "The queen eyes b2 and above all d4: the pressure mounts.")},
                "a3",
                {"san": "Nh6", "comment": c("Le cavalier contourne par h6 pour sauter en f5 et frapper d4/e3.",
                                            "The knight routes via h6 to land on f5 and hit d4/e3.")},
                "b4", "cxd4", "cxd4", "Nf5",
            ],
        },
        # 4) Avance — gambit Milner-Barry 6.Fd3
        {
            "chapter": {"id": "milner-barry", "title": c("Avance — gambit Milner-Barry", "Advance — Milner-Barry Gambit")},
            "moves": [
                "e4", "e6", "d4", "d5", "e5", "c5", "c3", "Nc6", "Nf3", "Qb6",
                {"san": "Bd3", "comment": c("Le gambit Milner-Barry : les Blancs abandonnent d4 pour attaquer le roi resté au centre.",
                                            "The Milner-Barry Gambit: White gives up d4 to attack the king stuck in the centre.")},
                "cxd4", "cxd4", "Bd7",
                {"san": "O-O", "comment": c("On peut prendre en d4, mais il faut ensuite défendre très précisément.",
                                            "Grabbing d4 is fine, but precise defence must follow.")},
                "Nxd4", "Nxd4", "Qxd4", "Nc3",
            ],
        },
        # 5) Tarrasch — 3…c5 (ouverte)
        {
            "chapter": {"id": "tarrasch-open", "title": c("Tarrasch — 3.Cd2 c5", "Tarrasch — 3.Nd2 c5")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "Nd2", "eco": "French Defense: Tarrasch Variation",
                 "comment": c("La Tarrasch : plus souple, elle évite le clouage …Fb4.",
                              "The Tarrasch: more flexible, it sidesteps the …Bb4 pin.")},
                {"san": "c5", "comment": c("On frappe le centre sans tarder : il naîtra un pion dame isolé à jouer activement.",
                                           "Strike the centre at once: an isolated queen's pawn arises, to be played actively.")},
                "exd5", "exd5", "Ngf3", "Nc6", "Bb5", "Bd6", "O-O", "Nge7", "dxc5", "Bxc5", "Nb3", "Bd6", "Re1", "O-O",
            ],
        },
        # 6) Tarrasch — 3…Cf6 (fermée)
        {
            "chapter": {"id": "tarrasch-closed", "title": c("Tarrasch — 3.Cd2 Cf6", "Tarrasch — 3.Nd2 Nf6")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nd2",
                {"san": "Nf6", "comment": c("La version fermée : plus stratégique, avec l'avance …f6 pour miner e5.",
                                            "The closed version: more strategic, with a later …f6 to undermine e5.")},
                "e5", "Nfd7", "Bd3", "c5", "c3", "Nc6", "Ne2", "cxd4", "cxd4", "f6",
            ],
        },
        # 7) Classique — Steinitz 4.e5
        {
            "chapter": {"id": "steinitz", "title": c("Classique — Steinitz 4.e5", "Classical — Steinitz 4.e5")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Nf6",
                {"san": "e5", "comment": c("La Steinitz : les Blancs gagnent de l'espace ; on frappe par …c5 et …f6.",
                                           "The Steinitz: White grabs space; Black hits back with …c5 and …f6.")},
                "Nfd7", "f4", "c5", "Nf3", "Nc6", "Be3", "cxd4", "Nxd4", "Bc5",
            ],
        },
        # 8) Classique — 4.Fg5
        {
            "chapter": {"id": "classical-bg5", "title": c("Classique — 4.Fg5", "Classical — 4.Bg5")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Nf6",
                {"san": "Bg5", "comment": c("La classique proprement dite : le fou cloue f6 avant de pousser e5.",
                                            "The Classical proper: the bishop pins f6 before pushing e5.")},
                "Be7", "e5", "Nfd7", "Bxe7", "Qxe7", "f4", "O-O", "Nf3", "c5",
            ],
        },
        # 9) Rubinstein — 3…dxe4
        {
            "chapter": {"id": "rubinstein", "title": c("Rubinstein — 3…dxe4", "Rubinstein — 3…dxe4")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3",
                {"san": "dxe4", "comment": c("La Rubinstein : on rend le centre pour une position solide et sans faiblesse.",
                                             "The Rubinstein: give up the centre for a solid, weakness-free position.")},
                "Nxe4", "Nd7", "Nf3", "Ngf6", "Nxf6+", "Nxf6", "Bd3", "c5",
            ],
        },
        # 10) Échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "exd5", "eco": "French Defense: Exchange Variation",
                 "comment": c("L'échange libère le fou problématique des Noirs : la position devient symétrique et facile à jouer.",
                              "The exchange frees Black's problem bishop: the position becomes symmetrical and easy to play.")},
                "exd5", "Nf3", "Nf6", "Bd3", "Bd6", "O-O", "O-O", "Bg5", "Bg4", "Nbd2", "Nbd7",
            ],
        },
    ],
}
