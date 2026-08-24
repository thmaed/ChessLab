# -*- coding: utf-8 -*-
"""Pions électriques — deux passés séparés d'une colonne, et le roi qui grille.

Un « pion électrique » est un pion passé séparé d'un autre par UNE SEULE
colonne. Le roi adverse ne peut en toucher aucun : dès qu'il s'approche de
l'un, il sort du carré de l'autre, qui file à dame. Ils se gardent mutuellement
sans qu'aucune pièce ne les soutienne — d'où le nom.

L'écart d'une colonne est le point exact : collés, un seul roi les arrête ;
plus éloignés, le roi n'a plus à choisir, il en perd un franchement. À une
colonne d'intervalle, la menace est RÉCIPROQUE.

Position et définition fournies par l'utilisateur (24/08/2026), vérifiées à la
tablebase : gain blanc, mat en 39. Chaque coup de la ligne est tranché par
l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-electric-pawns",
    "name": "Electric Pawns",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/8/2k5/8/P1P5/8/7K b - - 0 1",
    "summary": c(
        "Deux pions passés séparés par UNE colonne, un roi blanc à l'autre bout de l'échiquier, et pourtant les Noirs sont perdus. Le roi noir ne peut toucher ni l'un ni l'autre : s'approcher du premier, c'est sortir du carré du second. Ils se gardent l'un l'autre — d'où leur nom.",
        "Two passed pawns one file apart, a white king at the far end of the board, and yet Black is lost. Black's king can touch neither: approaching one means stepping out of the other's square. They guard each other — hence the name.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-shock", "title": c("Toucher l'un, c'est laisser filer l'autre", "Touch one, and the other runs")},
            "moves": [
                {"san": "Kc4",
                 "comment": c("Le roi noir s'attaque au pion c3 — la seule façon d'en prendre un, puisque b4 est contrôlé par les deux pions à la fois.",
                              "Black's king goes after the c3 pawn — the only way to take one, since b4 is covered by both pawns at once."),
                 "critical": True},
                {"san": "a4",
                 "comment": c("LE coup. Les Blancs n'essaient pas de sauver c3 : ils lancent l'autre. Le roi noir est maintenant devant un choix qui n'en est pas un — prendre en c3, ou courir après le pion a. Il ne peut pas les deux.",
                              "THE move. White does not try to save c3: he launches the other one. Black's king now faces a choice that isn't one — take on c3, or chase the a-pawn. He cannot do both."),
                 "critical": True},
                {"san": "Kxc3",
                 "comment": c("Le roi noir encaisse. Comptez le carré du pion a4 depuis c3 : il est déjà dehors, et chaque pas vers a8 arrive un temps trop tard.",
                              "Black's king collects. Count the a4 pawn's square from c3: he is already outside it, and every step toward a8 arrives one tempo late."),
                 "critical": True},
                "a5", "Kb4", "a6", "Kb5", "a7", "Kb6",
                {"san": "a8=Q",
                 "comment": c("À dame, avec un roi noir à deux cases. Le pion c3 n'était pas un cadeau : c'était l'appât. Retenez l'écart d'UNE colonne — collés, le roi noir les arrêtait tous les deux ; plus écartés, il n'aurait même pas eu à choisir.",
                              "Queening, with Black's king two squares away. The c3 pawn was no gift: it was the bait. Remember the ONE-file gap — side by side, Black's king would stop both; further apart, he would not even have had to choose."),
                 "critical": True},
            ],
        },
    ],
}
