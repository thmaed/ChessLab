# -*- coding: utf-8 -*-
"""Centurini — le roi défenseur sur la bonne case, devant le pion.

Sourcé Centurini (1856) : fou et pion contre fou de MÊME couleur. Principe
du maître italien, vérifié à l'oracle : la position est nulle si le roi
défenseur atteint une case devant le pion qui n'est PAS de la couleur du
fou. Racine à 5 pièces, chaque coup noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-centurini-wrong-color",
    "name": "Centurini — the Right Square",
    "side": "black",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "5b2/1k6/1P6/1K6/8/8/8/2B5 w - - 0 1",
    "summary": c(
        "Fou et pion contre fou de la même couleur : le principe de Centurini tient en une phrase — nulle si le roi défenseur atteint, devant le pion, une case qui N'EST PAS de la couleur du fou. Ici, b7 n'est pas de la couleur des fous (clairs) : la forteresse est déjà en place.",
        "Bishop and pawn versus a same-coloured bishop: Centurini's principle in one sentence — a draw if the defending king reaches a square in front of the pawn that is NOT the bishop's colour. Here, b7 isn't the bishops' colour (light): the fortress is already in place.",
    ),
    "lines": [
        {
            "chapter": {"id": "hold-the-square", "title": c("Tenir la case, tenir la diagonale", "Hold the square, hold the diagonal")},
            "moves": [
                {"san": "Bd2", "comment": c("Les blancs manœuvrent le fou sans que cela change rien — le roi noir bloque déjà la seule case qui compte.", "White manoeuvres the bishop without changing anything — Black's king already blocks the one square that matters.")},
                {"san": "Bd6",
                 "comment": c("Le fou noir doit rester sur une diagonale qui continue à surveiller la case de blocage — ici, deux cases de recul lui suffisent. Nulle vérifiée : aucune tentative blanche testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Black's bishop must stay on a diagonal that keeps watching the blocking square — here, two squares of retreat are enough. Verified draw: no White try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "abandon-the-square", "title": c("Abandonner la case, perdre la forteresse", "Abandoning the square loses the fortress")},
            "moves": [
                "Bd2",
                {"san": "Ka8", "role": "trap",
                 "comment": c("Un repli qui semble prudent — se mettre au coin, loin de tout. Mais quitter b7, c'est laisser le roi blanc entrer directement.",
                              "A retreat that looks cautious — tuck into the corner, away from everything. But leaving b7 lets White's king walk straight in."),
                 "critical": True},
                {"san": "Kc6",
                 "comment": c("Le roi blanc s'installe devant son propre pion — la case que le roi noir vient d'abandonner. La forteresse n'existait que tant que cette case précise restait occupée par le bon camp.",
                              "White's king settles in front of its own pawn — the square Black's king just gave up. The fortress only existed as long as that one exact square stayed occupied by the right side."),
                 "critical": True},
            ],
        },
    ],
}
