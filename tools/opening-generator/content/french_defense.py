# -*- coding: utf-8 -*-
"""Défense française (1.e4 e6) — répertoire NOIR."""


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
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance", "Advance Variation")},
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
            ],
        },
        {
            "chapter": {"id": "winawer", "title": c("Variante Winawer", "Winawer Variation")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3",
                {"san": "Bb4", "eco": "French Defense: Winawer Variation",
                 "comment": c("La Winawer : on cloue le cavalier c3 pour désorganiser le centre blanc.",
                              "The Winawer: pin the c3 knight to disrupt White's centre.")},
                "e5", "c5", "a3", "Bxc3+", "bxc3",
                {"san": "Ne7", "comment": c("Les Blancs ont la paire de fous, les Noirs des pions doublés à attaquer : jeu double-tranchant.",
                                            "White has the bishop pair, Black has doubled pawns to attack: double-edged play.")},
            ],
        },
        {
            "chapter": {"id": "tarrasch", "title": c("Variante Tarrasch — 3.Cd2", "Tarrasch — 3.Nd2")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "Nd2", "eco": "French Defense: Tarrasch Variation",
                 "comment": c("La Tarrasch : plus souple, elle évite le clouage …Fb4.",
                              "The Tarrasch: more flexible, it sidesteps the …Bb4 pin.")},
                {"san": "c5", "comment": c("On frappe le centre sans tarder.",
                                           "Strike the centre without delay.")},
                "exd5", "exd5", "Ngf3", "Nc6",
            ],
        },
        {
            "chapter": {"id": "classical", "title": c("Variante classique — 3.Cc3 Cf6", "Classical — 3.Nc3 Nf6")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Nf6",
                {"san": "e5", "comment": c("Les Blancs gagnent de l'espace ; le cavalier file en d7 puis on frappe par …c5 et …f6.",
                                           "White grabs space; the knight goes to d7, then Black hits with …c5 and …f6.")},
                "Nfd7", "f4", "c5",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "exd5", "eco": "French Defense: Exchange Variation",
                 "comment": c("L'échange libère le fou problématique des Noirs : la position devient symétrique et facile à jouer.",
                              "The exchange frees Black's problem bishop: the position becomes symmetrical and easy to play.")},
                "exd5", "Nf3", "Nf6", "Bd3", "Bd6",
            ],
        },
    ],
}
