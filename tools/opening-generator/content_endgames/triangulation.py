# -*- coding: utf-8 -*-
"""La triangulation — perdre un temps exprès pour gagner le zugzwang.

Position sourcée sur Wikipédia (article « Triangulation »), rejouée coup par
coup sous l'oracle : le triangle Ke5-Kd4-Kd5 restitue EXACTEMENT la position
de départ, trait inversé — la preuve géométrique de la méthode.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-triangulation",
    "name": "Triangulation",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "8/1p1k4/1P6/2PK4/8/8/8/8 w - - 0 1",
    "summary": c(
        "Deux pions bloqués contre un, une position qui a l'air gagnée — et pourtant, avancer tout de suite ne fait QUE la nulle. La triangulation est l'art de perdre un temps par un détour à trois cases, pour retomber sur la même position avec l'adversaire au trait. Un aller-retour qui change tout.",
        "Two blocked pawns against one, a position that looks won — and yet pushing right away is only a draw. Triangulation is the art of losing a tempo through a three-square detour, landing back on the same position with the opponent to move. A round trip that changes everything.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le triangle qui rend le trait", "The triangle that hands over the move")},
            "moves": [
                {"san": "Ke5",
                 "comment": c("Ni un échec, ni une poussée : le roi part faire un détour. Patience — c'est tout le sujet du chapitre.",
                              "Neither a check nor a push: the king sets off on a detour. Patience — that is the whole chapter."),
                 "critical": True},
                {"san": "Kc6", "comment": c("Le roi noir garde son unique tâche : surveiller la case de percée c6/d6.",
                                            "The black king keeps his one job: watching the breakthrough squares c6/d6.")},
                {"san": "Kd4",
                 "comment": c("Deuxième sommet du triangle. Le roi blanc, lui, dispose de TROIS cases (d5-e5-d4) pour ce ballet ; le roi noir n'en a que deux (c6-d7) — c'est cette asymétrie qui va tout décider.",
                              "Second corner of the triangle. The white king has THREE squares (d5-e5-d4) for this dance; the black king has only two (c6-d7) — that asymmetry decides everything."),
                 "critical": True},
                "Kd7",
                {"san": "Kd5",
                 "comment": c("Retour au point de départ — comparez avec la position initiale : les pièces sont EXACTEMENT les mêmes. Seul le trait a changé de camp. Le roi blanc n'a rien gagné en case ; il a gagné un temps, ce qui revient au même.",
                              "Back to the start — compare with the very first diagram: the pieces are EXACTLY the same. Only the move has changed hands. The white king gained no square; he gained a tempo, which amounts to the same thing."),
                 "critical": True},
                {"san": "Kc8",
                 "comment": c("Le roi noir doit céder — il n'a plus de coup d'attente, contrairement au roi blanc trois coups plus tôt.",
                              "The black king must give way — he has no waiting move left, unlike the white king three moves earlier.")},
                {"san": "Ke6",
                 "comment": c("Et la percée commence, portée par le temps gagné dans le triangle.",
                              "And the breakthrough begins, carried by the tempo won inside the triangle.")},
                "Kd8", "Kd6", "Kc8", "Ke7", "Kb8", "Kd7", "Ka8",
                {"san": "c6",
                 "comment": c("Le pion avance enfin, ESCORTÉ — plus rien ne l'arrête. Deux pions liés et un roi devant : la conversion est désormais mécanique.",
                              "The pawn finally advances, ESCORTED — nothing stops it now. Two connected pawns with the king in front: the conversion is now mechanical."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "rushed", "title": c("La poussée pressée ne fait que nulle", "The hasty push only draws")},
            "moves": [
                {"san": "c6+", "role": "trap",
                 "comment": c("Le réflexe : « j'ai deux pions contre un, je pousse ». Et la moitié du point s'évapore : le roi noir file en c8, prend le pion qui se sacrifie, et rejoint l'autre à temps. La triangulation n'était pas une joliesse, c'était la SEULE méthode.",
                              "The reflex: “I have two pawns against one, I push.” And half the point evaporates: the black king dashes to c8, takes the pawn that sacrifices itself, and reaches the other one in time. Triangulation wasn't a nicety — it was the ONLY method."),
                 "critical": True},
                {"san": "Kc8",
                 "comment": c("La seule défense — et elle suffit amplement : bxc6+ puis le roi noir croque tout ce qui reste.",
                              "The only defence — and it is more than enough: bxc6+ and the black king mops up what's left.")},
            ],
        },
    ],
}
