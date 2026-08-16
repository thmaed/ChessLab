# -*- coding: utf-8 -*-
"""Anglaise (1.c4) — répertoire BLANC.

Arbre approfondi : Sicilienne inversée 1…e5 (dragon inversé), Symétrique 1…c5
(avec la rupture d4), et l'attaque Mikenas 2.Cc3 e6 3.e4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "english-opening",
    "name": "English Opening",
    "side": "white",
    "level": "club",
    "eco": ["A10", "A39"],
    "summary": c(
        "Une ouverture de flanc hypermoderne : on contrôle d5 à distance et on garde une flexibilité totale. Souvent une sicilienne avec un temps de plus.",
        "A hypermodern flank opening: control d5 from afar and keep total flexibility. Often a Sicilian with an extra tempo.",
    ),
    "lines": [
        # 1) Sicilienne inversée — 1…e5
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                {"san": "c4", "eco": "English Opening",
                 "comment": c("On revendique d5 sans engager les pions centraux : jeu souple.",
                              "Claiming d5 without committing the central pawns: flexible play.")},
                {"san": "e5", "comment": c("Les Noirs prennent le centre : c'est une sicilienne à camps inversés, un temps en plus pour les Blancs.",
                                           "Black grabs the centre: it's a Sicilian with colours reversed, White a tempo up.")},
                "Nc3", "Nf6", "Nf3", "Nc6", "g3", "d5", "cxd5", "Nxd5", "Bg2",
                {"san": "Nb6", "comment": c("Le dragon inversé : les Blancs jouent la structure sicilienne avec un temps de plus.",
                                            "The reversed Dragon: White plays the Sicilian structure a tempo up.")},
                "O-O", "Be7", "d3", "O-O", "a3", "a5", "Be3", "Re8",
            ],
        },
        # 2) Variante symétrique — 1…c5
        {
            "chapter": {"id": "symmetrical", "title": c("Variante symétrique — 1…c5", "Symmetrical — 1…c5")},
            "moves": [
                "c4",
                {"san": "c5", "eco": "English Opening: Symmetrical Variation",
                 "comment": c("La symétrique : chacun campe sur ses positions. Les Blancs cherchent à rompre la symétrie au bon moment.",
                              "The Symmetrical: both sides mirror. White looks to break the symmetry at the right moment.")},
                "Nc3", "Nc6", "g3", "g6", "Bg2", "Bg7", "Nf3", "Nf6", "O-O", "O-O",
                {"san": "d4", "comment": c("Le bon moment pour rompre : d4 casse la symétrie et ouvre le fou g2.",
                                           "The right moment to break: d4 shatters the symmetry and opens the g2 bishop.")},
                "cxd4", "Nxd4", "Nxd4", "Qxd4", "d6", "Qd3", "a6",
            ],
        },
        # 3) Attaque Mikenas — 2.Cc3 e6 3.e4
        {
            "chapter": {"id": "mikenas", "title": c("Attaque Mikenas — 3.e4", "Mikenas Attack — 3.e4")},
            "moves": [
                "c4", "Nf6", "Nc3", "e6",
                {"san": "e4", "comment": c("L'attaque Mikenas : les Blancs prennent tout le centre. Le jeu devient concret d'emblée.",
                                           "The Mikenas Attack: White seizes the whole centre. Play turns concrete at once.")},
                {"san": "d5", "comment": c("La réponse la plus critique : on frappe e4 tout de suite.",
                                           "The most critical reply: hit e4 immediately.")},
                "e5", "d4", "exf6", "dxc3", "fxg7", "cxd2+", "Bxd2", "Bxg7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-kid-setup", "title": c("Contre l'installation …Cf6/…g6", "vs the …Nf6/…g6 setup")},
            "moves": [
                "c4",
                {"san": "Nf6",
                 "comment": c("Le début le plus fréquent après 1.c4, et le cours partait de …e5 ou …c5.",
                              "The most common reply to 1.c4, and the course started from …e5 or …c5."),
                 "critical": True},
                "Nc3",
                {"san": "g6",
                 "comment": c("Les Noirs visent une Est-Indienne. On peut la refuser en occupant le centre tout de suite.",
                              "Black is heading for a King's Indian. We can decline it by taking the centre at once.")},
                {"san": "d4",
                 "comment": c("Transposition assumée : l'Anglaise se transforme en jeu de pions dames, où notre pion c4 est déjà idéalement placé.",
                              "A deliberate transposition: the English turns into a queen's pawn game, where our c4 pawn already stands ideally.")},
                "d5", "Nf3", "Bg7",
                {"san": "Qb3",
                 "comment": c("La pression sur d5 avant le roque : c'est l'idée qui donne le ton à toute la variante.",
                              "Pressure on d5 before castling: the idea that sets the tone for the whole line.")},
                "dxc4", "Qxc4",
            ],
        },
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                "c4", "e5", "Nc3",
                {"san": "Nc6",
                 "comment": c("Le développement le plus naturel, absent du chapitre qui partait de …Cf6.",
                              "The most natural developing move, missing from the chapter, which started from …Nf6.")},
                {"san": "g3",
                 "comment": c("Fianchetto : c'est une Sicilienne avec un temps de plus. Le fou g2 mordra sur d5 toute la partie.",
                              "Fianchetto: this is a Sicilian with an extra tempo. The g2 bishop will bite on d5 all game.")},
                "g6", "Bg2", "Bg7", "d3", "a5", "e3",
            ],
        },
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                "c4", "e5", "Nc3",
                {"san": "Bc5",
                 "comment": c("Un coup de club fréquent : le fou sort vite, mais il devra bouger encore quand d4 arrivera.",
                              "A common club move: the bishop develops fast, but it will have to move again once d4 comes.")},
                "e3", "Nc6", "Nf3", "d6", "a3",
                {"san": "a5",
                 "comment": c("Les Noirs freinent b4. On joue d4 quand même : le fou c5 perd son temps, et c'est notre avantage.",
                              "Black slows b4 down. We play d4 anyway: the c5 bishop loses time, and that's our edge.")},
                "d4", "Ba7",
            ],
        },
    ],
}
