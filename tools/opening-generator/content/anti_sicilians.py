# -*- coding: utf-8 -*-
"""Anti-siciliennes (1.e4 c5, quand les Blancs évitent 2.Cf3/3.d4) — NOIR.

Ce que le joueur de club affronte VRAIMENT face à la sicilienne : Alapin
(2…d5 et 2…Cf6), Rossolimo (…g6 et …e6), Moscou (…Fd7 et …Cd7), Grand Prix,
gambit Smith-Morra, sicilienne fermée, gambit de l'aile. Lignes passées à l'audit moteur (`audit.py`).
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
        # 1) Alapin 2.c3 — 2…d5 (ligne principale)
        {
            "chapter": {"id": "alapin", "title": c("Alapin — 2.c3", "Alapin — 2.c3")},
            "moves": [
                "e4", "c5",
                {"san": "c3", "eco": "Sicilian Defense: Alapin Variation",
                 "comment": c("L'Alapin : les Blancs préparent d4 sans se laisser prendre en d4. Frapper au centre est la clé.",
                              "The Alapin: White prepares d4 without allowing …cxd4 tricks. Striking the centre is the key.")},
                {"san": "d5", "comment": c("La réponse la plus simple : on ouvre et on égalise proprement.",
                                           "The simplest reply: open up and equalise cleanly.")},
                "exd5", "Qxd5",
                {"san": "d4", "comment": c("Les Blancs gagnent un temps sur la dame en poussant d4.",
                                           "White gains a tempo on the queen by pushing d4.")},
                "Nf6", "Nf3", "e6",
                {"san": "Be2", "comment": c("Chacun développe ; il naîtra une structure de pion dame isolé (IQP) équilibrée.",
                                            "Both sides develop; a balanced isolated queen's-pawn (IQP) structure arises.")},
                "Nc6", "O-O", "cxd4", "cxd4", "Be7", "Nc3", "Qd6",
            ],
        },
        # 2) Alapin — 2…Cf6
        {
            "chapter": {"id": "alapin-nf6", "title": c("Alapin — 2…Cf6", "Alapin — 2…Nf6")},
            "moves": [
                "e4", "c5", "c3",
                {"san": "Nf6", "comment": c("L'autre grande réponse : on attaque e4 tout de suite.",
                                            "The other main reply: hit e4 immediately.")},
                {"san": "e5", "comment": c("Le pion avance ; le cavalier doit reculer en d5, où il sera bousculé.",
                                           "The pawn advances; the knight must go to d5, where it gets harassed.")},
                "Nd5", "d4", "cxd4", "Nf3", "Nc6", "cxd4", "d6",
                {"san": "Bc4", "comment": c("Le fou attaque le cavalier d5 ; les Noirs le repoussent et frappent e5.",
                                            "The bishop hits the d5-knight; Black kicks it and strikes at e5.")},
                "Nb6", "Bb3", "dxe5",
            ],
        },
        # 3) Rossolimo — 3…g6
        {
            "chapter": {"id": "rossolimo-g6", "title": c("Rossolimo — 3.Fb5 g6", "Rossolimo — 3.Bb5 g6")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "Bb5", "eco": "Sicilian Defense: Rossolimo Variation",
                 "comment": c("Le Rossolimo : les Blancs échangent en c6 pour jouer la structure. …g6 est fiable.",
                              "The Rossolimo: White trades on c6 to play the structure. …g6 is reliable.")},
                "g6", "Bxc6", "dxc6",
                {"san": "d3", "comment": c("Sans les dames actives, la paire de fous noire compense le pion doublé.",
                                           "With queens likely to come off, Black's bishop pair offsets the doubled pawn.")},
                "Bg7", "h3", "Nf6", "Nc3", "Nd7", "Be3", "e5",
            ],
        },
        # 4) Rossolimo — 3…e6
        {
            "chapter": {"id": "rossolimo-e6", "title": c("Rossolimo — 3.Fb5 e6", "Rossolimo — 3.Bb5 e6")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "Bb5",
                {"san": "e6", "comment": c("On garde la structure intacte et on chasse le fou par …a6/…b5.",
                                           "Keep the structure intact and chase the bishop with …a6/…b5.")},
                "O-O", "Nge7", "c3", "a6", "Ba4", "b5", "Bc2", "Bb7",
            ],
        },
        # 5) Moscou — 3.Fb5+ Fd7
        {
            "chapter": {"id": "moscow-bd7", "title": c("Moscou — 3.Fb5+ Fd7", "Moscow — 3.Bb5+ Bd7")},
            "moves": [
                "e4", "c5", "Nf3", "d6",
                {"san": "Bb5+", "eco": "Sicilian Defense: Moscow Variation",
                 "comment": c("La Moscou : l'échec en b5. …Fd7 est net et sans histoire.",
                              "The Moscow: the b5 check. …Bd7 is clean and trouble-free.")},
                "Bd7", "Bxd7+", "Qxd7", "O-O", "Nc6", "c3", "Nf6", "Re1", "e6", "d4", "cxd4", "cxd4", "d5",
            ],
        },
        # 6) Moscou — 3.Fb5+ Cd7
        {
            "chapter": {"id": "moscow-nd7", "title": c("Moscou — 3.Fb5+ Cd7", "Moscow — 3.Bb5+ Nd7")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "Bb5+",
                {"san": "Nd7", "comment": c("La version combative : on garde le fou de cases claires pour …e5 et …Fe7.",
                                            "The combative version: keep the light bishop for …e5 and …Be7.")},
                "d4", "Ngf6", "Nc3", "cxd4", "Qxd4", "e5", "Qd3", "h6",
            ],
        },
        # 7) Gambit Smith-Morra — accepté
        {
            "chapter": {"id": "smith-morra", "title": c("Gambit Smith-Morra — 2.d4", "Smith-Morra Gambit — 2.d4")},
            "moves": [
                "e4", "c5",
                {"san": "d4", "comment": c("Le gambit Smith-Morra : un pion pour un développement rapide et des colonnes ouvertes.",
                                           "The Smith-Morra Gambit: a pawn for fast development and open files.")},
                "cxd4", "c3",
                {"san": "dxc3", "eco": "Sicilian Defense: Smith-Morra Gambit Accepted",
                 "comment": c("Accepter puis se défendre précisément neutralise le gambit.",
                              "Accept, then defend precisely to neutralise the gambit.")},
                "Nxc3", "Nc6", "Nf3", "d6",
                {"san": "Bc4", "comment": c("Le fou vise f7 ; les Noirs adoptent le dispositif défensif type.",
                                            "The bishop eyes f7; Black adopts the standard defensive setup.")},
                "e6", "O-O", "a6",
                {"san": "Qe2", "comment": c("Contre la pression sur e5/d5, la formation …a6, …Cf6, …Fe7, …0-0 tient bon.",
                                            "Against the pressure on e5/d5, the …a6, …Nf6, …Be7, …0-0 formation holds firm.")},
                "Nf6", "Rd1",
                {"san": "Qc7", "critical": True,
                 "comment": c("La dame AVANT le fou : …Fe7 tout de suite laisse e5 ! et les Blancs récupèrent tout avec intérêt.",
                              "The queen BEFORE the bishop: …Be7 at once allows e5! and White gets everything back with interest.")},
                "Bf4", "Be7", "Rac1", "O-O",
            ],
        },
        # 8) Attaque Grand Prix — 4…Fg7 5.Fb5
        {
            "chapter": {"id": "grand-prix", "title": c("Attaque Grand Prix — 2.Cc3 & f4", "Grand Prix Attack — 2.Nc3 & f4")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "f4", "eco": "Sicilian Defense: Grand Prix Attack",
                 "comment": c("Le Grand Prix : les Blancs veulent f4-f5 et un assaut sur le roi. …g6 et …Fg7 contiennent l'attaque.",
                              "The Grand Prix: White wants f4-f5 and a kingside assault. …g6 and …Bg7 contain it.")},
                "g6", "Nf3", "Bg7",
                {"san": "Bb5", "comment": c("Le fou vient clouer/échanger en c6 pour affaiblir le contrôle noir du centre.",
                                            "The bishop comes to pin/trade on c6 to weaken Black's grip on the centre.")},
                "Nd4", "O-O", "Nxb5", "Nxb5", "d6",
            ],
        },
        # 9) Sicilienne fermée — 2.Cc3 & g3
        {
            "chapter": {"id": "closed", "title": c("Sicilienne fermée — 2.Cc3 & g3", "Closed Sicilian — 2.Nc3 & g3")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "g3", "eco": "Sicilian Defense: Closed",
                 "comment": c("La fermée : jeu de manœuvre. Les Noirs prennent leur espace à l'aile dame par …Tb8 et …b5.",
                              "The Closed: a manoeuvring game. Black grabs queenside space with …Rb8 and …b5.")},
                "g6", "Bg2", "Bg7", "d3", "d6", "f4", "e6", "Nf3", "Nge7", "O-O", "O-O", "Be3", "Nd4",
            ],
        },
        # 10) Gambit de l'aile — 2.b4
        {
            "chapter": {"id": "wing-gambit", "title": c("Gambit de l'aile — 2.b4", "Wing Gambit — 2.b4")},
            "moves": [
                "e4", "c5",
                {"san": "b4", "comment": c("Le gambit de l'aile : un pion d'aile pour dévier le pion c et prendre le centre.",
                                           "The Wing Gambit: a flank pawn to deflect the c-pawn and grab the centre.")},
                "cxb4", "a3",
                {"san": "d5", "comment": c("La réfutation nette : on rend le pion pour ouvrir le centre et prendre l'initiative.",
                                           "The clean refutation: give the pawn back to open the centre and seize the initiative.")},
                "exd5", "Qxd5", "Nf3", "e5", "axb4", "Bxb4",
            ],
        },
    ],
}
