# -*- coding: utf-8 -*-
"""Dame contre pion en 7e (pion central) — la vis sans fin, et deux joyaux.

Ligne dérivée sous l'oracle : la sous-promotion cavalier du désespoir est
DANS la tablebase (meilleure défense !), on l'enseigne donc telle quelle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-pawn",
    "name": "Queen vs 7th-Rank Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "queens",
    "level": "club",
    "rootFEN": "7Q/8/8/1K6/8/8/3pk3/8 w - - 0 1",
    "summary": c(
        "Vous avez promu le premier, l'adversaire est à UNE case d'en faire autant. La dame gagne contre un pion central — mais pas en fonçant : par une vis sans fin qui force le roi adverse devant son pion, un temps volé à chaque tour de spirale.",
        "You queened first; your opponent is ONE square from doing the same. The queen beats a central pawn — but not by rushing: with an endless-screw of checks that forces the enemy king in front of its pawn, stealing one tempo per turn of the spiral.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La vis sans fin", "The endless screw")},
            "moves": [
                {"san": "Qe5+",
                 "comment": c("La dame ne fonce pas sur le pion : elle échèque en SE RAPPROCHANT — chaque échec la pose une case plus près, en zigzag.",
                              "The queen doesn't rush the pawn: she checks while CLOSING IN — every check lands her one square nearer, zigzagging."),
                 "critical": True},
                "Kf2",
                {"san": "Qd4+", "comment": c("Toujours l'échec qui gagne une case.", "Always the check that gains a square.")},
                "Ke2",
                {"san": "Qe4+"},
                "Kf2",
                {"san": "Qd3",
                 "comment": c("Pas d'échec cette fois : la dame contrôle d1 PAR-DERRIÈRE. Le roi noir n'a qu'une façon de sauver son pion…",
                              "No check this time: the queen eyes d1 FROM BEHIND. The black king has only one way to keep his pawn alive…")},
                "Ke1",
                {"san": "Qe3+",
                 "comment": c("…et la voilà, la clé de toute la finale : cet échec force le roi DEVANT son propre pion.",
                              "…and here is the key to the whole ending: this check forces the king IN FRONT of his own pawn."),
                 "critical": True},
                {"san": "Kd1",
                 "comment": c("Le pion est muselé par son propre roi : les Noirs n'ont plus de menace. Ce répit d'UN temps est tout ce que la vis produit — et tout ce qu'il faut.",
                              "The pawn is gagged by its own king: Black has no threat left. That ONE-tempo respite is all the screw produces — and all that is needed.")},
                {"san": "Kc4",
                 "comment": c("LE temps volé : le roi blanc fait un pas. Puis la vis recommence — échecs, roi devant le pion, un pas. Comptez les pas qu'il vous faut : c'est votre marge.",
                              "THE stolen tempo: the white king takes one step. Then the screw restarts — checks, king in front, one step. Count the steps you need: that is your margin."),
                 "critical": True},
                "Kc2", "Qe2", "Kc1",
                {"san": "Kc3",
                 "comment": c("Le roi entre SANS prendre le pion : d2 peut promouvoir, et alors ? Regardez la suite — la promotion ne sauve rien, et l'ignorer est le chemin le plus court.",
                              "The king walks in WITHOUT taking the pawn: yes, d2 may promote — so what? Watch what follows: promotion saves nothing, and ignoring it is the shortest road."),
                 "critical": True},
                {"san": "d1=N+",
                 "comment": c("Le CAVALIER du désespoir — la meilleure défense selon la table de finales, sérieusement : une dame naîtrait clouée morte (voir l'autre chapitre). Le cavalier, lui, donne échec… et prolonge de deux coups.",
                              "The desperado KNIGHT — genuinely the tablebase's best defence: a queen would be born dead (see the other chapter). The knight at least gives check… postponing matters by two moves.")},
                "Kb3",
                {"san": "Ne3", "comment": c("Le cavalier fuit en donnant… rien du tout.", "The knight flees, threatening… nothing at all.")},
                {"san": "Qd3", "comment": c("Clouage du fuyard sur place — et le filet se referme.",
                                            "The runaway is pinned mid-stride — and the net closes.")},
                "Nd1",
                {"san": "Qc2#",
                 "comment": c("Mat, cavalier au balcon. La vis sans fin, le roi qui entre, le désespoir réfuté : la méthode complète tient en douze coups.",
                              "Mate, knight watching from the balcony. The endless screw, the king walking in, the desperado refuted: the complete method in twelve moves."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "queen-promo", "title": c("Et s'il fait dame ?", "What if he queens?")},
            "moves": [
                "Qe5+", "Kf2", "Qd4+", "Ke2", "Qe4+", "Kf2", "Qd3", "Ke1", "Qe3+", "Kd1",
                "Kc4", "Kc2", "Qe2", "Kc1", "Kc3",
                {"san": "d1=Q",
                 "comment": c("La promotion « naturelle »… et la dame naît pour mourir : une case, un coup, un mat.",
                              "The “natural” promotion… and the queen is born to die: one square, one move, one mate.")},
                {"san": "Qb2#",
                 "comment": c("La dame toute neuve regarde, impuissante : b2 était le seul carré qui comptait. C'est pour CELA que le cavalier était la meilleure défense.",
                              "The brand-new queen watches, helpless: b2 was the only square that mattered. THAT is why the knight was the better defence."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "king-first", "title": c("Le roi d'abord ? Non.", "King first? No.")},
            "moves": [
                {"san": "Kc4", "role": "trap",
                 "comment": c("« Mon roi est à quatre pas, je fonce. » Un seul temps de trop : le pion couronne, et dame contre dame ne se gagne plus. TOUJOURS la vis d'abord — elle seule immobilise le pion.",
                              "“My king is four steps away, let's run.” One tempo too slow: the pawn queens, and queen versus queen is no longer a win. ALWAYS the screw first — only it freezes the pawn."),
                 "critical": True},
                {"san": "d1=Q",
                 "comment": c("Théoriquement nulle. Toute la finale s'est jouée sur le premier coup blanc.",
                              "A theoretical draw. The whole ending was decided by White's first move.")},
            ],
        },
    ],
}
