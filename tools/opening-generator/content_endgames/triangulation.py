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
                 "comment": c("Le pion avance enfin, ESCORTÉ. Le cours s'arrêtait ici — trop tôt : « la conversion est mécanique » est facile à écrire, et l'élève ne l'a jamais vue. La voici, jusqu'au mat.",
                              "The pawn finally advances, ESCORTED. The course used to stop here — too early: “the conversion is mechanical” is easy to write, and the student never saw it. Here it is, all the way to mate."),
                 "critical": True},
                {"san": "bxc6",
                 "comment": c("La prise est forcée ou presque : sur 16…Rb8, 17.c7+ Ra8 18.c8=D est mat immédiat (voir le chapitre suivant).",
                              "The capture is all but forced: on 16…Kb8, 17.c7+ Ka8 18.c8=Q is mate at once (see the next chapter).")},
                {"san": "Kc7",
                 "comment": c("Et non 17.bxc6, qui ne mène nulle part : le pion c6 noir n'a aucune importance, seul compte le pion b. Le roi blanc se place pour l'escorter.",
                              "And not 17.bxc6, which leads nowhere: Black's c6 pawn is irrelevant, only the b-pawn matters. White's king steps up to escort it."),
                 "critical": True},
                {"san": "c5", "comment": c("Le pion noir court — trois cases de retard, il n'arrivera jamais.",
                                            "The black pawn runs — three squares behind, it will never arrive.")},
                "b7+", "Ka7",
                {"san": "b8=Q+",
                 "comment": c("À dame avec échec, ce qui interdit toute résistance.",
                              "Queening with check, which rules out any resistance."),
                 "critical": True},
                "Ka6",
                {"san": "Qb6#",
                 "comment": c("Mat. Voilà ce que valait le triangle Rd5-Re5-Rd4 : un temps, et ce temps-là valait la partie entière.",
                              "Mate. That is what the triangle Kd5-Ke5-Kd4 was worth: one tempo, and that tempo was worth the whole game."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "mate-in-the-corner", "title": c("L'autre défense : mat en deux coups", "The other defence: mate in two")},
            "moves": [
                "Ke5", "Kc6", "Kd4", "Kd7", "Kd5", "Kc8", "Ke6", "Kd8", "Kd6", "Kc8",
                "Ke7", "Kb8", "Kd7", "Ka8", "c6",
                {"san": "Kb8",
                 "comment": c("Le roi noir refuse la prise — et c'est pire. Le pion c est maintenant soutenu par son voisin, et la case c7 est un échec.",
                              "Black's king declines the capture — and it is worse. The c-pawn is now backed by its neighbour, and c7 comes with check."),
                 "critical": True},
                {"san": "c7+", "comment": c("Échec, et le roi n'a que le coin.", "Check, and the king has only the corner.")},
                "Ka8",
                {"san": "c8=Q#",
                 "comment": c("Mat. Deux pions liés escortés par leur roi contre un roi acculé : il n'y a jamais eu de défense, seulement deux façons de perdre.",
                              "Mate. Two connected pawns escorted by their king against a cornered king: there never was a defence, only two ways to lose."),
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
