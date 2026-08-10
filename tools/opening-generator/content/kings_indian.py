# -*- coding: utf-8 -*-
"""Est-indienne (1.d4 Cf6 2.c4 g6 3.Cc3 Fg7) — répertoire NOIR."""


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
                "O-O", "Nc6", "d5", "Ne7",
                {"san": "Ne1", "comment": c("Course aux ailes : les Noirs jouent …f5-f4-g5-g4, les Blancs c5 à l'aile dame.",
                                            "A race on the wings: Black plays …f5-f4-g5-g4, White pushes c5 on the queenside.")},
            ],
        },
        {
            "chapter": {"id": "saemisch", "title": c("Variante Sämisch — 5.f3", "Sämisch — 5.f3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "e4", "d6",
                {"san": "f3", "eco": "King's Indian Defense: Sämisch Variation",
                 "comment": c("Le Sämisch : centre bétonné, roque long possible. Les Noirs frappent par …e5 ou …c5.",
                              "The Sämisch: a rock-solid centre, long castling in view. Black hits with …e5 or …c5.")},
                "O-O", "Be3", "e5", "d5", "c6",
            ],
        },
        {
            "chapter": {"id": "fianchetto", "title": c("Variante du fianchetto — 5.g3", "Fianchetto — 5.g3")},
            "moves": [
                "d4", "Nf6", "c4", "g6", "Nc3", "Bg7", "Nf3", "O-O",
                {"san": "g3", "comment": c("Les Blancs fianchettent aussi : la ligne la plus positionnelle, moins de feu d'artifice.",
                                           "White fianchettoes too: the most positional line, fewer fireworks.")},
                "d6", "Bg2", "Nbd7", "O-O", "e5",
            ],
        },
    ],
}
