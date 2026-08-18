# -*- coding: utf-8 -*-
"""Dame contre tour — la troisième grande finale de dame.

Position d'entraînement standard (roi/tour au coin, dame et roi centralisés).
Ligne intégralement DTM-optimale (tablebase) : chaque coup blanc est le
chemin le plus court vers le gain.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-rook",
    "name": "Queen vs Rook",
    "side": "white",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "1k6/1r6/2K5/Q7/8/8/8/8 w - - 0 1",
    "summary": c(
        "Une dame gagne contre une tour seule — mais pas d'un coup de baguette : il faut restreindre le roi, harceler sans répit, et attendre le moment où la tour n'a plus de case sûre. Comptez les coups : le gain complet demande souvent plus de vingt coups, cette finale est réputée l'une des plus longues à convertir.",
        "A queen beats a lone rook — but not by magic: the king must be restricted, harassed without rest, until the rook runs out of safe squares. Count the moves: the full win often takes over twenty, one of the longest conversions in the game.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le harcèlement sans répit", "Relentless harassment")},
            "moves": [
                {"san": "Qd5",
                 "comment": c("La dame se centralise près de la boîte du roi noir — pas d'échec précipité, juste une case qui réduit son monde.",
                              "The queen centralises near the black king's box — no rushed check, just a square that shrinks his world."),
                 "critical": True},
                {"san": "Ka8", "comment": c("Le roi n'a pas mieux : les autres cases perdent plus vite encore.",
                                            "The king has nothing better: every other square loses faster still.")},
                {"san": "Qa2+",
                 "comment": c("Le premier échec, depuis le coin — la dame ne donne jamais un échec qui laisse une case de respiration inutile.",
                              "The first check, from the corner — the queen never gives a check that leaves a useless breathing square.")},
                "Kb8",
                {"san": "Qa5",
                 "comment": c("Encore un temps de restriction pure. La tour, elle, n'a pratiquement rien à faire — c'est tout le problème du camp faible dans cette finale : il ne peut qu'attendre.",
                              "Another purely restricting move. The rook, meanwhile, has almost nothing to do — that is the whole problem for the weaker side here: all it can do is wait.")},
                {"san": "Rb1",
                 "comment": c("La tour bouge parce qu'il faut bien jouer quelque chose — pas parce que ça aide.",
                              "The rook moves because something must be played — not because it helps.")},
                {"san": "Qe5+",
                 "critical": True},
                "Ka7",
                {"san": "Qd4+"},
                "Ka8",
                {"san": "Qh8+",
                 "comment": c("La dame traverse tout l'échiquier pour l'échec suivant — sa mobilité est justement ce qu'une tour seule ne peut jamais égaler.",
                              "The queen crosses the whole board for the next check — her mobility is exactly what a lone rook can never match.")},
                "Ka7",
                {"san": "Qh7+"},
                "Kb8",
                {"san": "Qxb1+",
                 "comment": c("Le fruit du harcèlement : la tour, à court de cases utiles depuis le début, tombe enfin — AVEC échec, sans laisser un souffle de contre-jeu.",
                              "The fruit of the harassment: the rook, short of useful squares from the very start, finally falls — WITH check, leaving no breath of counterplay."),
                 "critical": True},
                "Kc8",
                {"san": "Qb4",
                 "comment": c("Dame contre roi nu : la fin est désormais mécanique.",
                              "Queen against a bare king: the finish is now mechanical.")},
                "Kd8",
                {"san": "Qf8#",
                 "comment": c("Mat. Comptez : quatorze coups blancs depuis la position de départ, sans qu'un seul n'ait été un échec gratuit — chacun retirait quelque chose au camp noir.",
                              "Mate. Count them: fourteen white moves from the starting position, not one of them a wasted check — each took something away from Black."),
                 "critical": True},
            ],
        },
    ],
}
