# -*- coding: utf-8 -*-
"""Anti-siciliennes (1.e4 c5, quand les Blancs évitent 2.Cf3/3.d4) — NOIR.

Ce que le joueur de club affronte VRAIMENT face à la sicilienne : Alapin,
Rossolimo, Moscou, Grand Prix, gambit Smith-Morra, sicilienne fermée.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "anti-sicilians",
    "name": "Anti-Sicilians",
    "side": "black",
    "level": "club",
    "eco": ["B20", "B29"],
    "summary": c(
        "La plupart des adversaires de club fuient la sicilienne ouverte. Voici les réponses saines aux Alapin, Rossolimo, Grand Prix, Smith-Morra et compagnie.",
        "Most club opponents dodge the Open Sicilian. Here are sound answers to the Alapin, Rossolimo, Grand Prix, Smith-Morra and friends.",
    ),
    "lines": [
        {
            "chapter": {"id": "alapin", "title": c("Alapin — 2.c3", "Alapin — 2.c3")},
            "moves": [
                "e4", "c5",
                {"san": "c3", "eco": "Sicilian Defense: Alapin Variation",
                 "comment": c("L'Alapin : les Blancs préparent d4 sans se laisser prendre en d4. Frapper au centre est la clé.",
                              "The Alapin: White prepares d4 without allowing …cxd4 tricks. Striking the centre is the key.")},
                {"san": "d5", "comment": c("La réponse la plus simple : on ouvre et on égalise proprement.",
                                           "The simplest reply: open up and equalise cleanly.")},
                "exd5", "Qxd5", "d4", "Nf6", "Nf3", "e6",
            ],
        },
        {
            "chapter": {"id": "rossolimo", "title": c("Rossolimo — 2.Cf3 Cc6 3.Fb5", "Rossolimo — 2.Nf3 Nc6 3.Bb5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "Bb5", "eco": "Sicilian Defense: Rossolimo Variation",
                 "comment": c("Le Rossolimo : les Blancs échangent en c6 pour jouer la structure. …g6 est fiable.",
                              "The Rossolimo: White trades on c6 to play the structure. …g6 is reliable.")},
                "g6", "Bxc6", "dxc6", "d3", "Bg7",
            ],
        },
        {
            "chapter": {"id": "moscow", "title": c("Moscou — 2.Cf3 d6 3.Fb5+", "Moscow — 2.Nf3 d6 3.Bb5+")},
            "moves": [
                "e4", "c5", "Nf3", "d6",
                {"san": "Bb5+", "eco": "Sicilian Defense: Moscow Variation",
                 "comment": c("La Moscou : l'échec en b5. …Fd7 est net et sans histoire.",
                              "The Moscow: the b5 check. …Bd7 is clean and trouble-free.")},
                "Bd7", "Bxd7+", "Qxd7", "O-O", "Nc6",
            ],
        },
        {
            "chapter": {"id": "smith-morra", "title": c("Gambit Smith-Morra — 2.d4", "Smith-Morra Gambit — 2.d4")},
            "moves": [
                "e4", "c5",
                {"san": "d4", "comment": c("Le gambit Smith-Morra : un pion pour un développement rapide et des colonnes ouvertes.",
                                           "The Smith-Morra Gambit: a pawn for fast development and open files.")},
                "cxd4", "c3",
                {"san": "dxc3", "role": "mainLine", "eco": "Sicilian Defense: Smith-Morra Gambit Accepted",
                 "comment": c("Accepter puis se défendre précisément (…d6, …Cf6, …e6, …a6, …Fe7) neutralise le gambit.",
                              "Accept, then defend precisely (…d6, …Nf6, …e6, …a6, …Be7) to neutralise the gambit.")},
                "Nxc3", "Nc6", "Nf3", "d6",
            ],
        },
        {
            "chapter": {"id": "grand-prix", "title": c("Attaque Grand Prix — 2.Cc3 & f4", "Grand Prix Attack — 2.Nc3 & f4")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "f4", "eco": "Sicilian Defense: Grand Prix Attack",
                 "comment": c("Le Grand Prix : les Blancs veulent f4-f5 et un assaut sur le roi. …g6 et …Fg7 contiennent l'attaque.",
                              "The Grand Prix: White wants f4-f5 and a kingside assault. …g6 and …Bg7 contain it.")},
                "g6", "Nf3", "Bg7",
            ],
        },
        {
            "chapter": {"id": "closed", "title": c("Sicilienne fermée — 2.Cc3 & g3", "Closed Sicilian — 2.Nc3 & g3")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "g3", "eco": "Sicilian Defense: Closed",
                 "comment": c("La fermée : jeu de manœuvre. Les Noirs prennent leur espace à l'aile dame par …Tb8 et …b5.",
                              "The Closed: a manoeuvring game. Black grabs queenside space with …Rb8 and …b5.")},
                "g6", "Bg2", "Bg7", "d3", "d6",
            ],
        },
    ],
}
