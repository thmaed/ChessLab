# -*- coding: utf-8 -*-
"""Gambit dame accepté (1.d4 d5 2.c4 dxc4) — répertoire BLANC.

Arbre approfondi : ligne principale 3.Cf3 (pion isolé), variante centrale 3.e4,
et la tentative …a6/…b5 pour garder le pion (réfutée). Lignes vérifiées.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "queens-gambit-accepted",
    "name": "Queen's Gambit Accepted",
    "side": "white",
    "level": "club",
    "eco": ["D20", "D29"],
    "summary": c(
        "Les Noirs prennent en c4 — mais ne peuvent pas garder le pion. Les Blancs reprennent le centre par e3/e4 et jouissent d'une belle liberté de développement.",
        "Black grabs c4 — but can't hold the pawn. White regains the centre with e3/e4 and enjoys easy, free development.",
    ),
    "lines": [
        # 1) Ligne principale — 3.Cf3
        {
            "chapter": {"id": "classical", "title": c("Ligne principale — 3.Cf3", "Main Line — 3.Nf3")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "dxc4", "eco": "Queen's Gambit Accepted",
                 "comment": c("Accepter le pion : les Noirs ne le garderont pas, mais gagnent du temps de développement.",
                              "Accepting the pawn: Black won't keep it, but gains development time.")},
                {"san": "Nf3", "comment": c("On empêche …e5 avant de reprendre le pion tranquillement.",
                                            "Stopping …e5 before calmly recovering the pawn.")},
                "Nf6", "e3", "e6", "Bxc4", "c5", "O-O", "a6",
                {"san": "a4", "comment": c("On freine …b5 ; il naîtra un pion dame isolé où les Blancs pressent activement.",
                                           "Restrain …b5; an isolated queen's pawn arises with active pressure for White.")},
                "Nc6", "Qe2", "cxd4", "Rd1", "Be7", "exd4", "O-O", "Nc3",
            ],
        },
        # 2) Variante centrale — 3.e4
        {
            "chapter": {"id": "central", "title": c("Variante centrale — 3.e4", "Central Variation — 3.e4")},
            "moves": [
                "d4", "d5", "c4", "dxc4",
                {"san": "e4", "eco": "Queen's Gambit Accepted: Central Variation",
                 "comment": c("La version ambitieuse : les Blancs bâtissent d'emblée un centre e4+d4 imposant.",
                              "The ambitious version: White builds a big e4+d4 centre at once.")},
                "e5", "Nf3", "exd4", "Bxc4", "Nc6", "O-O", "Be6",
                {"san": "Bxe6", "comment": c("On échange en e6 pour attaquer b7 et e6 à la dame — un pion revient souvent.",
                                             "Trade on e6 to hit b7 and e6 with the queen — a pawn usually returns.")},
                "fxe6", "Qb3", "Qd7", "Qxb7", "Rb8", "Qa6", "Nf6",
            ],
        },
        # 3) La tentative …a6/…b5 (garder le pion)
        {
            "chapter": {"id": "hold-attempt", "title": c("La tentative …a6/…b5", "The …a6/…b5 hold attempt")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "Nf3",
                {"san": "a6", "comment": c("Les Noirs veulent tenir c4 par …b5. C'est une illusion : le pion tombe.",
                                           "Black wants to hold c4 with …b5. It's an illusion: the pawn falls.")},
                "e3", "b5",
                {"san": "a4", "comment": c("Le coup de sape : a4 attaque la chaîne b5-c4 par la base.",
                                           "The undermining blow: a4 hits the b5-c4 chain at its base.")},
                "Bb7", "axb5", "axb5", "Rxa8", "Bxa8", "b3", "cxb3", "Qxb3",
            ],
        },
    ],
}
