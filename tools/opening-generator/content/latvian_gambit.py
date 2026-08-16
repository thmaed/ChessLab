# -*- coding: utf-8 -*-
"""Gambit letton (1.e4 e5 2.Cf3 f5) — répertoire NOIR.

Une sicilienne inversée ultra-agressive et douteuse : contre-attaque immédiate.
Arbre : 3.Cxe5 (principale), 3.exf5, 3.Fc4 (le plus tranchant). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "latvian-gambit",
    "name": "Latvian Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C40"],
    "summary": c(
        "Le miroir du gambit du Roi, mais côté noir : …f5 dès le 2e coup, un jeu de tout ou rien. Objectivement risqué, mais un cauchemar pour qui n'est pas préparé.",
        "The mirror of the King's Gambit, but for Black: …f5 on move two, all-or-nothing play. Objectively risky, but a nightmare for the unprepared.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3.Cxe5", "Main Line — 3.Nxe5")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "f5", "eco": "Latvian Gambit",
                 "comment": c("Le gambit letton : contre-attaque immédiate au lieu de défendre e5.",
                              "The Latvian Gambit: an immediate counterattack instead of defending e5.")},
                "Nxe5", "Qf6", "d4", "d6", "Nc4", "fxe4", "Nc3", "Qg6", "Ne3", "Nf6", "Be2", "Be7",
            ],
        },
        {
            "chapter": {"id": "exf5", "title": c("3.exf5", "3.exf5")},
            "moves": [
                "e4", "e5", "Nf3", "f5",
                {"san": "exf5", "comment": c("Les Blancs prennent en f5 ; …e4 gagne du temps sur le cavalier et ouvre le jeu.",
                                             "White takes on f5; …e4 gains time on the knight and opens the game.")},
                "e4", "Ne5", "Nf6", "Be2", "d6", "Nc4", "Bxf5",
            ],
        },
        # La réfutation que les Blancs ont à disposition au 6e coup. Sans elle
        # le chapitre ne montrait que 6.Cc4, le coup qui laisse les Noirs bien.
        {
            "chapter": {"id": "exf5", "title": c("3.exf5 — la ligne principale", "3.exf5 — the main line")},
            "moves": [
                "e4", "e5", "Nf3", "f5", "exf5", "e4", "Ne5", "Nf6", "Be2", "d6",
                {"san": "Bh5+", "role": "trap", "critical": True,
                 "comment": c("Le coup désagréable, à connaître AVANT de jouer le Letton : l'échec en h5 gagne la qualité par force.",
                              "The unpleasant move, to know BEFORE playing the Latvian: the h5 check wins the exchange by force.")},
                {"san": "Ke7",
                 "comment": c("Forcé — …Cxh5 permet Cf7 et le roi noir ne s'en sort pas mieux.",
                              "Forced — …Nxh5 allows Nf7 and the black king fares no better.")},
                "Nf7", "Qe8", "d4", "Nxh5",
                {"san": "Nxh8",
                 "comment": c("La qualité tombe. Le Letton reste jouable en blitz, pas contre quelqu'un qui connaît cette ligne.",
                              "The exchange drops. The Latvian stays playable in blitz, not against someone who knows this line.")},
            ],
        },
        {
            "chapter": {"id": "bc4", "title": c("3.Fc4 — le plus tranchant", "3.Bc4 — the sharpest")},
            "moves": [
                "e4", "e5", "Nf3", "f5",
                {"san": "Bc4", "comment": c("La réfutation ambitieuse : le fou vise f7. Les Noirs plongent dans le chaos.",
                                            "The ambitious refutation: the bishop eyes f7. Black plunges into chaos.")},
                "fxe4", "Nxe5", "Qg5", "d4", "Qxg2", "Qh5+", "g6", "Bf7+", "Kd8", "Bxg6", "Qxh1+",
            ],
        },

        # ── Quand les Blancs déclinent (16/08) ────────────────────────────────
        {
            "chapter": {"id": "vs-bc4", "title": c("2.Fc4 — le gambit n'a pas lieu", "2.Bc4 — the gambit never happens")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4",
                 "comment": c("Le Letton suppose 2.Cf3 : sans cavalier en f3, …f5 n'attaquerait rien et affaiblirait le roque pour rien.",
                              "The Latvian assumes 2.Nf3: with no knight on f3, …f5 would attack nothing and weaken the king for nothing."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On développe sainement. Un joueur de gambit doit savoir reconnaître les positions où son arme ne s'applique pas.",
                              "We develop soundly. A gambit player must recognise the positions where the weapon simply doesn't apply.")},
                "d3", "c6", "Nf3", "d5", "Bb3", "a5",
            ],
        },
        {
            "chapter": {"id": "main-nd4", "title": c("Ligne principale — 4.Cd4", "Main line — 4.Nd4")},
            "moves": [
                "e4", "e5", "Nf3", "f5", "exf5", "e4",
                {"san": "Nd4",
                 "comment": c("Le coup le plus fréquent ici — près d'une partie sur deux — et le chapitre continuait autrement.",
                              "The most common move here — nearly one game in two — and the chapter went elsewhere."),
                 "critical": True},
                {"san": "Qf6", "role": "inaccuracy",
                 "comment": c("La suite naturelle du gambit, mais soyons francs : après Cb5 puis De2, les Noirs perdent le roque et restent sous pression. Le Letton est une arme de surprise, pas une ligne saine — à jouer en connaissance de cause.",
                              "The gambit's natural follow-up, but let's be honest: after Nb5 and Qe2, Black loses castling rights and stays under pressure. The Latvian is a surprise weapon, not a sound line — play it knowing that.")},
                "Nb5", "Qe5", "Qe2", "Kd8",
            ],
        },
    ],
}
