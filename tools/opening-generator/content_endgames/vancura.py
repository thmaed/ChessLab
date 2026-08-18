# -*- coding: utf-8 -*-
"""La position de Vančura (1924) — LA nulle contre le pion-tour.

Position et méthode recoupées sur Wikipédia (Josef Vančura, 1898-1921,
publication posthume 1924), chaque coup vérifié à la tablebase.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-vancura",
    "name": "The Vancura Position",
    "side": "black",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "R7/6k1/P4r2/8/2K5/8/8/8 w - - 0 1",
    "summary": c(
        "Pion-tour en sixième rangée, tour adverse DEVANT son pion : la position que tout joueur de tournoi finit par défendre. Vančura a montré en 1924 d'où la tour tient la nulle — de côté, jamais derrière. Une méthode contre-intuitive et éternelle.",
        "Rook's pawn on the sixth, enemy rook IN FRONT of its own pawn: the position every tournament player ends up defending. Vančura showed in 1924 where the rook holds the draw — from the side, never from behind. Counter-intuitive, and eternal.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La tour de flanc", "The rook on the flank")},
            "moves": [
                {"san": "Kb5",
                 "comment": c("Le roi blanc vient défendre son pion pour libérer sa tour — le SEUL plan gagnant. Regardez la tour f6 le recevoir.",
                              "The white king comes to shepherd the pawn and free his rook — the ONLY winning plan. Watch the f6-rook greet him.")},
                {"san": "Rf5+",
                 "comment": c("L'échec DE CÔTÉ, marque de fabrique de Vančura : la tour frappe depuis la 6e rangée où elle atteint AUSSI le pion. Le roi blanc n'a aucun abri sur ces rangées-là.",
                              "The SIDEWAYS check, Vančura's trademark: the rook strikes from the rank where it ALSO hits the pawn. The white king has no shelter on those ranks."),
                 "critical": True},
                "Kc6",
                {"san": "Rf6+", "comment": c("Et retour sur la rangée du pion. Le manège peut durer mille ans.",
                                             "And back to the pawn's rank. This carousel can spin for a thousand years.")},
                "Kd5",
                {"san": "Rf5+"},
                "Ke6",
                {"san": "Rf6+",
                 "comment": c("Surtout ne pas prendre a6 — voir le chapitre du pion empoisonné.",
                              "Above all, don't take a6 — see the poisoned-pawn chapter."),
                 "critical": True},
                "Ke5",
                {"san": "Rb6",
                 "comment": c("Le roi blanc a fui les échecs vers le centre ? La tour reste sur SA rangée et continue de fixer le pion : tant qu'il est attaqué, la tour a8 est de garde et le pion cloué sur place.",
                              "The white king fled the checks toward the centre? The rook keeps ITS rank and keeps hitting the pawn: while it hangs, the a8-rook stands sentry and the pawn is nailed down."),
                 "critical": True},
                "Kd5",
                {"san": "Rf6",
                 "comment": c("Balancier b6-f6 : toujours la 6e, toujours le pion en joue. Rien n'avance, rien n'avancera — c'est la nulle de Vančura.",
                              "The b6-f6 pendulum: always the sixth, always the pawn at gunpoint. Nothing progresses, nothing ever will — Vančura's draw.")},
            ],
        },
        {
            "chapter": {"id": "check-first", "title": c("Le roi reste en face", "The king stays across")},
            "moves": [
                {"san": "Ra7+",
                 "comment": c("L'autre essai : chasser le roi noir avant tout.", "The other try: evict the black king first.")},
                {"san": "Kg6",
                 "comment": c("Une case suffit — mais pas n'importe laquelle : le roi noir reste À L'OPPOSÉ du pion, hors du chemin de sa propre tour. Les cases f7/g8 se feraient prendre de vitesse.",
                              "One square is enough — but not any square: the black king stays OPPOSITE the pawn, out of his own rook's line. f7 or g8 would be outrun."),
                 "critical": True},
                {"san": "Ra8", "comment": c("Retour à la garde — sinon le pion tombait.",
                                            "Back to sentry duty — else the pawn dropped.")},
                {"san": "Kg7",
                 "comment": c("Et le roi noir reprend son poste. Deux cases pour un demi-point : g7, g6.",
                              "And the black king resumes his post. Two squares for half a point: g7 and g6.")},
            ],
        },
        {
            "chapter": {"id": "poisoned", "title": c("Le pion empoisonné", "The poisoned pawn")},
            "moves": [
                {"san": "Kb5"},
                {"san": "Rf5+"},
                {"san": "Kc6"},
                {"san": "Rf6+"},
                {"san": "Kd5"},
                {"san": "Rxa6", "role": "trap",
                 "comment": c("Le pion se donne ENFIN ?... et la tour a8 le reprend d'équerre : Txa6, et vous voilà dans « Le mat à la tour » — du mauvais côté. La tour de flanc devait FIXER le pion, jamais le manger.",
                              "The pawn finally drops?… and the a8-rook recaptures on the square: Rxa6, and you are inside “The Rook Mate” — on the wrong end. The flank rook was meant to PIN the pawn down, never to eat it."),
                 "critical": True},
                {"san": "Rxa6"},
            ],
        },
        {
            "chapter": {"id": "wander", "title": c("Le roi qui abandonne son poste", "The king who deserts his post")},
            "moves": [
                {"san": "Kb5"},
                {"san": "Kf7", "role": "trap",
                 "comment": c("« Mon roi va aider »… et tout s'écroule : a7 ! passe aussitôt — le roi noir s'est mis dans les pattes de sa propre tour, qui n'a plus ni échecs utiles ni rangée sûre. Le roi de Vančura ne QUITTE JAMAIS g6-g7.",
                              "“My king will help”… and everything collapses: a7! races through at once — the black king has stepped into his own rook's path, leaving it neither useful checks nor a safe rank. Vančura's king NEVER leaves g6-g7."),
                 "critical": True},
                {"san": "a7",
                 "comment": c("Le pion n'attendait que ça : en 7e, il change la géométrie — la tour de flanc ne l'atteint plus, la tour a8 est libérée.",
                              "The pawn asked for nothing more: on the 7th it changes the geometry — the flank rook no longer reaches it, the a8-rook is free.")},
            ],
        },
    ],
}
