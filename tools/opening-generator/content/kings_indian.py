# -*- coding: utf-8 -*-
"""Est-indienne (1.d4 Cf6 2.c4 g6 3.Cc3 Fg7) — répertoire NOIR.

Arbre approfondi : Classique / Mar del Plata (course aux ailes), Sämisch 5.f3,
Fianchetto 5.g3, Quatre Pions 5.f4, Averbakh 5.Fe2+Fg5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-indian",
    "name": "King's Indian Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["E60", "E99"],
    "summary": c(
        "On laisse le centre aux Blancs pour le pulvériser ensuite par …e5 et une ruée de pions à l'aile roi (…f5-f4-g4). L'ouverture de l'attaquant.",
        "Give White the centre, then blow it up with …e5 and a kingside pawn storm (…f5-f4-g4). The attacker's opening.",
    ),
    "lines": [
        # 1) Classique — Mar del Plata
        {
            "chapter": {"id": "classical", "title": c("Classique — Mar del Plata", "Classical — Mar del Plata")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3",
                {"san": "Bg7", "eco": "King's Indian Defense",
                 "comment": c("Le fou roi fianchetté : cœur de tout le système.",
                              "The fianchettoed king's bishop: the heart of the whole system.")},
                "e4", "d6", "Nf3", "O-O", "Be2",
                {"san": "e5", "comment": c("Le coup de rupture : on défie le centre blanc.",
                                           "The freeing break: challenging White's centre.")},
                "O-O", "Nc6",
                {"san": "d5", "comment": c("Les Blancs ferment le centre : la course aux ailes est lancée.",
                                           "White closes the centre: the race on the wings is on.")},
                "Ne7",
                {"san": "Ne1", "comment": c("Les Blancs dégagent f3 pour f4 et poussent c5 à l'aile dame.",
                                            "White clears f3 for f4 and pushes c5 on the queenside.")},
                {"san": "Nd7", "comment": c("On réoriente le cavalier et on prépare la ruée …f5-f4-g5-g4.",
                                            "Reroute the knight and prepare the …f5-f4-g5-g4 storm.")},
                "Be3", "f5", "f3", "f4", "Bf2", "g5", "b4", "Ng6", "c5", "Nf6",
            ],
        },
        # 2) Sämisch — 5.f3
        {
            "chapter": {"id": "saemisch", "title": c("Variante Sämisch — 5.f3", "Sämisch — 5.f3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "e4", "d6",
                {"san": "f3", "eco": "King's Indian Defense: Sämisch Variation",
                 "comment": c("Le Sämisch : centre bétonné, roque long possible. Les Noirs frappent par …e5 ou …c5.",
                              "The Sämisch: a rock-solid centre, long castling in view. Black hits with …e5 or …c5.")},
                "O-O", "Be3", "e5", "d5", "c6", "Qd2", "cxd5", "cxd5", "Nbd7", "g4", "Nc5", "Nge2",
                {"san": "Bxg4", "critical": True,
                 "comment": c("Le sacrifice de démolition : le pion g4 est le pilier du centre blanc. Après fxg4, …Ccxe4 récupère tout et le roi blanc reste nu.",
                              "The demolition sacrifice: the g4 pawn props up White's whole centre. After fxg4, …Ncxe4 wins everything back and the white king is left bare.")},
                "fxg4", "Ncxe4", "Nxe4", "Nxe4",
            ],
        },
        # 11.h4 — le vrai test du Sämisch avec g4. Cge2 laissait …Fxg4 ;
        # ici les Blancs poussent d'abord et les Noirs doivent bloquer.
        {
            "chapter": {"id": "saemisch", "title": c("Variante Sämisch — 5.f3", "Sämisch — 5.f3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "e4", "d6", "f3", "O-O", "Be3", "e5", "d5", "c6",
                "Qd2", "cxd5", "cxd5", "Nbd7", "g4", "Nc5",
                {"san": "h4", "critical": True,
                 "comment": c("Plus fort que Cge2 : les Blancs poussent AVANT de développer, et …Fxg4 ne marche plus.",
                              "Stronger than Nge2: White pushes BEFORE developing, and …Bxg4 no longer works.")},
                {"san": "h5",
                 "comment": c("Il faut bloquer : laisser h4-h5 ouvrir la colonne h serait fatal au roque.",
                              "Black must block: letting h4-h5 open the h-file would be fatal to the king.")},
                "g5", "Ne8", "b4", "Nd7",
            ],
        },
        # 3) Fianchetto — 5.g3
        {
            "chapter": {"id": "fianchetto", "title": c("Variante du fianchetto — 5.g3", "Fianchetto — 5.g3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "Nf3", "O-O",
                {"san": "g3", "comment": c("Les Blancs fianchettent aussi : la ligne la plus positionnelle, moins de feu d'artifice.",
                                           "White fianchettoes too: the most positional line, fewer fireworks.")},
                "d6", "Bg2", "Nbd7", "O-O", "e5", "e4", "exd4", "Nxd4", "Re8", "h3", "a6",
            ],
        },
        # 4) Attaque des Quatre Pions — 5.f4
        {
            "chapter": {"id": "four-pawns", "title": c("Quatre Pions — 5.f4", "Four Pawns — 5.f4")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "e4", "d6",
                {"san": "f4", "comment": c("Les Quatre Pions : centre gigantesque, mais surchargé et attaquable par …c5.",
                                           "The Four Pawns: a giant centre, but overextended and open to …c5.")},
                "O-O", "Nf3", "c5", "d5", "e6", "Be2", "exd5", "cxd5", "Bg4", "O-O", "Nbd7",
            ],
        },
        # 5) Averbakh — 5.Fe2 & Fg5
        {
            "chapter": {"id": "averbakh", "title": c("Averbakh — 5.Fe2 & Fg5", "Averbakh — 5.Be2 & Bg5")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "e4", "d6", "Be2", "O-O",
                {"san": "Bg5", "comment": c("L'Averbakh : le fou en g5 gêne …e5 (à cause du clouage). Les Noirs jouent …c5.",
                                            "The Averbakh: the g5 bishop discourages …e5 (the pin). Black plays …c5.")},
                "c5", "d5", "e6", "Qd2", "exd5", "exd5", "Re8",
            ],
        },
    ],
}
