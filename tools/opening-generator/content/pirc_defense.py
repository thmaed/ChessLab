# -*- coding: utf-8 -*-
"""Défense Pirc (1.e4 d6 2.d4 Cf6 3.Cc3 g6) — répertoire NOIR.

Arbre approfondi : Classique 4.Cf3, Attaque autrichienne 4.f4 (5…0-0 et la
contre-attaque 5…c5), Attaque 150 (4.Fe3), Byrne (4.Fg5). Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "pirc-defense",
    "name": "Pirc Defense",
    "side": "black",
    "level": "club",
    "eco": ["B07", "B09"],
    "summary": c(
        "Hypermoderne : on laisse les Blancs bâtir un grand centre… pour mieux le harceler avec le fou g7, …e5 et …c5. Souple et piégeuse.",
        "Hypermodern: let White build a big centre… then harass it with the g7 bishop, …e5 and …c5. Flexible and tricky.",
    ),
    "lines": [
        # 1) Système classique — 4.Cf3
        {
            "chapter": {"id": "classical", "title": c("Système classique — 4.Cf3", "Classical System — 4.Nf3")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3",
                {"san": "g6", "eco": "Pirc Defense",
                 "comment": c("Le Pirc : le fou file en g7 et vise le centre à distance.",
                              "The Pirc: the bishop goes to g7 and targets the centre from afar.")},
                {"san": "Nf3", "comment": c("Le développement le plus naturel et le plus sûr.",
                                            "The most natural and safest development.")},
                "Bg7", "Be2", "O-O", "O-O", "c6",
                {"san": "a4", "comment": c("Les Blancs freinent l'expansion …b5 avant de continuer.",
                                           "White restrains the …b5 break before continuing.")},
                "a5", "h3", "Nbd7", "Be3",
                {"san": "e5", "comment": c("La rupture centrale thématique : les Noirs revendiquent enfin le centre.",
                                           "The thematic central break: Black finally claims the centre.")},
            ],
        },
        # 2) Attaque autrichienne — 5…0-0
        {
            "chapter": {"id": "austrian-oo", "title": c("Autrichienne — 4.f4 0-0", "Austrian — 4.f4 0-0")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6",
                {"san": "f4", "eco": "Pirc Defense: Austrian Attack",
                 "comment": c("L'Attaque autrichienne, la plus ambitieuse : centre massif et poussée f5 en vue.",
                              "The Austrian Attack, the most ambitious: a huge centre with f5 in the air.")},
                "Bg7", "Nf3", "O-O",
                {"san": "Bd3", "comment": c("Les Noirs contre-attaquent au bon moment par …c5 ou …e5.",
                                            "Black counters at the right moment with …c5 or …e5.")},
                "Na6", "O-O",
                {"san": "c5", "comment": c("On frappe la base d4 ; le grand centre blanc devient une cible.",
                                           "Strike the d4 base; White's big centre becomes a target.")},
                "d5", "Bg4",
            ],
        },
        # 3) Attaque autrichienne — 5…c5 (contre-attaque)
        {
            "chapter": {"id": "austrian-c5", "title": c("Autrichienne — 4.f4 c5", "Austrian — 4.f4 c5")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6", "f4", "Bg7", "Nf3",
                {"san": "c5", "comment": c("La contre-attaque directe : on frappe d4 avant même de roquer.",
                                           "The direct counter: hitting d4 before even castling.")},
                "dxc5",
                {"san": "Qa5", "comment": c("La dame récupère c5 en attaquant e5/c3 : les Noirs égalisent l'espace.",
                                            "The queen regains c5 while hitting e5/c3: Black equalises the space.")},
                "Bd3", "Qxc5", "Qe2", "O-O", "Be3", "Qa5",
            ],
        },
        # 4) Attaque 150 — 4.Fe3
        {
            "chapter": {"id": "150", "title": c("Attaque 150 — 4.Fe3", "150 Attack — 4.Be3")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6",
                {"san": "Be3", "comment": c("L'Attaque 150 : Dd2 et Fh6 pour échanger le fort fou g7, puis h4-h5.",
                                            "The 150 Attack: Qd2 and Bh6 to trade the strong g7 bishop, then h4-h5.")},
                "Bg7", "Qd2", "c6", "f3", "b5", "Nge2", "Nbd7",
                {"san": "Bh6", "comment": c("Les Blancs échangent le fou-dragon ; les Noirs gardent la solidité et ripostent à l'aile dame.",
                                            "White trades the dragon bishop; Black stays solid and hits back on the queenside.")},
                "Bxh6", "Qxh6", "Bb7",
            ],
        },
        # 5) Byrne — 4.Fg5
        {
            "chapter": {"id": "byrne", "title": c("Byrne — 4.Fg5", "Byrne — 4.Bg5")},
            "moves": [
                "e4", "d6", "d4", "Nf6", "Nc3", "g6",
                {"san": "Bg5", "comment": c("La Byrne : le fou cloue f6 tout de suite, avec Dd2 et 0-0-0 en tête.",
                                            "The Byrne: the bishop pins f6 at once, with Qd2 and 0-0-0 in mind.")},
                "Bg7", "Qd2", "c6", "f3", "b5", "O-O-O", "Nbd7", "Bh6", "Bxh6", "Qxh6",
            ],
        },
    ],
}
