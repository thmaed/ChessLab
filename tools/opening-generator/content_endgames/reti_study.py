# -*- coding: utf-8 -*-
"""L'étude de Réti (1921) — le roi qui court deux lièvres à la fois.

La plus célèbre étude de finale de l'histoire, quatre pièces, et l'air d'une
position perdue d'avance. Chaque branche vérifiée à la tablebase : Kg7 est
l'UNIQUE coup qui tient, tout le reste perd.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-reti",
    "name": "The Réti Study",
    "side": "white",
    "kind": "endgame",
    "family": "practical",
    "level": "advanced",
    "rootFEN": "7K/8/k1P5/7p/8/8/8/8 w - - 0 1",
    "summary": c(
        "Le pion noir file, votre roi est à des kilomètres du carré, votre propre pion va tomber : perdu ? Réti, 1921 : nulle — par un chemin qui poursuit DEUX buts à la fois. L'étude qui a appris au monde que la diagonale ne coûte rien.",
        "The black pawn is racing, your king is miles outside the square, your own pawn is about to fall: lost? Réti, 1921: draw — via a path chasing TWO goals at once. The study that taught the world the diagonal costs nothing.",
    ),
    "lines": [
        {
            "chapter": {"id": "fork", "title": c("La diagonale aux deux lièvres", "The two-hare diagonal")},
            "moves": [
                {"san": "Kg7",
                 "comment": c("L'UNIQUE coup qui tient — et le plus invraisemblable de l'échiquier : le roi est HORS du carré du pion h et le restera encore un coup. Mais la diagonale g7-f6-e5 vise DEUX cibles : la case h1 derrière le pion noir, et la case c7 devant le sien. Deux menaces à moitié valent une entière.",
                              "The ONLY move that holds — and the most implausible on the board: the king stands OUTSIDE the h-pawn's square and will stay outside for one more move. But the g7-f6-e5 diagonal aims at TWO targets: h1 behind the black pawn, and c7 in front of his own. Two half-threats make a whole one."),
                 "critical": True},
                "h4",
                {"san": "Kf6",
                 "comment": c("Toujours hors du carré, toujours sur la diagonale à double sens. Les Noirs doivent enfin choisir : courir, ou arrêter le pion c.",
                              "Still outside the square, still on the two-way diagonal. Black must finally choose: keep running, or stop the c-pawn.")},
                {"san": "Kb6",
                 "comment": c("Les Noirs s'occupent du pion c — que faire d'autre ? S'ils poussent (h3), voyez l'autre chapitre : le roi blanc pousse le SIEN.",
                              "Black attends to the c-pawn — what else? If he pushes (h3) instead, see the other chapter: the white king pushes HIS OWN.")},
                {"san": "Ke5",
                 "comment": c("LE point de l'étude. De e5, le roi menace ENFIN les deux à la fois : Kf4 attrape le pion h, Kd6 escorte le pion c à dame. Les Noirs n'ont qu'un coup pour parer chaque menace — et il en faudrait deux.",
                              "THE point of the study. From e5 the king AT LAST threatens both at once: Kf4 catches the h-pawn, Kd6 walks the c-pawn home. Black has one move to parry each threat — and would need two."),
                 "critical": True},
                {"san": "Kxc6",
                 "comment": c("Prendre le pion règle un lièvre… et libère l'autre : le roi blanc, lui, est maintenant DANS le carré. La géométrie a rattrapé trois temps de retard.",
                              "Taking the pawn settles one hare… and frees the other: the white king is now INSIDE the square. Geometry has clawed back three tempi.")},
                {"san": "Kf4", "critical": True},
                "h3", "Kg3", "h2",
                {"san": "Kxh2",
                 "comment": c("Nulle sèche. Repartez du diagramme initial et comptez : ce roi était à QUATRE cases hors du carré. La ligne droite l'aurait perdu ; la diagonale l'a sauvé.",
                              "Stone-cold draw. Go back to the first diagram and count: this king stood FOUR squares outside the square. The straight line would have lost; the diagonal saved him.")},
            ],
        },
        {
            "chapter": {"id": "race", "title": c("Si le pion fonce : dame contre dame", "If the pawn runs: queen for queen")},
            "moves": [
                "Kg7", "h4", "Kf6", "Kb6", "Ke5",
                {"san": "h3", "comment": c("Les Noirs jouent la course pure. Alors le roi blanc change de lièvre :",
                                           "Black plays the pure race. So the white king swaps hares:")},
                {"san": "Kd6",
                 "comment": c("…et escorte SON pion. Chaque camp promeut — comptez les temps : ensemble, à un coup près.",
                              "…and escorts HIS pawn. Both sides promote — count the tempi: together, to the move."),
                 "critical": True},
                "h2", "c7", "Kb7", "Kd7", "h1=Q",
                {"san": "c8=Q+",
                 "comment": c("Dame contre dame, et même avec échec. L'étude est nulle de bout en bout — à condition d'avoir vu, au premier coup, que g7 menait aux deux buts.",
                              "Queen for queen, with check no less. The study is a draw from end to end — provided you saw, on move one, that g7 led to both goals."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "straight", "title": c("La ligne droite perd", "The straight line loses")},
            "moves": [
                {"san": "c7", "role": "trap",
                 "comment": c("« Poussons, il faudra bien qu'il s'en occupe. » Il s'en occupe en UN coup — et la course reprend avec un pion blanc en moins.",
                              "“Push — he'll have to deal with it.” He deals with it in ONE move — and the race resumes, minus a white pawn."),
                 "critical": True},
                {"san": "Kb7",
                 "comment": c("Le pion c est mort ; comptez maintenant le carré du pion h depuis h8 : le roi blanc n'y entrera jamais.",
                              "The c-pawn is dead; now draw the h-pawn's square from h8: the white king will never get in.")},
                "Kg7", "Kxc7", "Kg6", "h4", "Kg5", "h3", "Kg4", "h2", "Kg3",
                {"san": "h1=Q",
                 "comment": c("La dame sort à UNE case du roi — l'histoire de toute la finale : un seul temps, toujours le même, celui du premier coup.",
                              "The queen appears ONE square from the king — the story of the whole ending: a single tempo, always the same one, from move one.")},
            ],
        },
    ],
}
