# -*- coding: utf-8 -*-
"""Tour contre pion — la tour ne gagne pas : le ROI gagne.

Racine d'une netteté rare (vérifiée tablebase) : UN seul coup gagne, et
c'est un coup de ROI. Les douze coups de tour — l'échec naturel compris, et
même « la tour derrière le pion passé » — ne font que nulle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-pawn",
    "name": "Rook vs Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "8/6K1/8/8/1kp5/8/8/7R w - - 0 1",
    "summary": c(
        "Une tour contre un pion qui court : gagné, non ? Tout dépend de VOTRE roi. Ici, un seul premier coup gagne — et ce n'est pas un coup de tour. La finale qui apprend une fois pour toutes que la tour arrête, mais ne capture pas.",
        "A rook against a running pawn: winning, surely? It all depends on YOUR king. Here exactly one first move wins — and it is not a rook move. The ending that teaches once and for all: the rook stops, it does not capture.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le roi d'abord — encore lui", "King first — him again")},
            "moves": [
                {"san": "Kf6",
                 "comment": c("Le SEUL coup gagnant de la position — et la tour n'y touche pas. Elle tient déjà la rangée h1 et coupera la promotion en c1 ; ce qui manque, c'est un roi pour CAPTURER. Douze coups de tour sont possibles : tous nuls.",
                              "The ONLY winning move in the position — and it doesn't touch the rook. She already owns the h1-rank and will cut the promotion on c1; what's missing is a king to CAPTURE. Twelve rook moves are available: all of them draw."),
                 "critical": True},
                {"san": "c3", "comment": c("Le pion court — que faire d'autre ?", "The pawn runs — what else?")},
                {"san": "Ke5",
                 "comment": c("La diagonale, comme dans l'étude de Réti : chaque pas approche À LA FOIS le pion et la case de promotion.",
                              "The diagonal, as in the Réti study: every step nears the pawn AND the promotion square at once.")},
                {"san": "Kc4", "comment": c("Le roi noir escorte son pion, épaule en avant.",
                                            "The black king escorts his pawn, shoulder first.")},
                {"san": "Ke4",
                 "comment": c("L'ÉPAULÉE en face : les deux rois se frôlent, et c'est le blanc qui a le pas — le roi noir ne peut pas à la fois protéger c3 et barrer e3-d3.",
                              "The counter-shoulder: the two kings brush past each other, and White has right of way — the black king cannot both guard c3 and bar e3-d3."),
                 "critical": True},
                "Kc5",
                {"san": "Kd3",
                 "comment": c("Le roi est passé DERRIÈRE l'escorte : le pion est condamné. La tour n'a toujours pas bougé — elle n'a rien eu à faire.",
                              "The king slipped BEHIND the escort: the pawn is doomed. The rook still hasn't moved — she never had to."),
                 "critical": True},
                "Kd5",
                {"san": "Kxc3",
                 "comment": c("Tour et roi contre roi : la suite exacte est le cours « Le mat à la tour ». Retenez d'ici une seule chose : la tour immobilise, le roi ramasse.",
                              "Rook and king versus king: the exact continuation is “The Rook Mate” course. Take one thing from here: the rook freezes, the king collects.")},
            ],
        },
        {
            "chapter": {"id": "escort", "title": c("L'escorte immédiate", "The immediate escort")},
            "moves": [
                "Kf6",
                {"san": "Kb3", "comment": c("Les Noirs préparent le couloir AVANT de pousser : même remède.",
                                            "Black prepares the corridor BEFORE pushing: same cure.")},
                {"san": "Ke5", "critical": True},
                "c3", "Kd4",
                {"san": "c2", "comment": c("À une case du but…", "One square from glory…")},
                {"san": "Kd3",
                 "comment": c("…et une case, c'est exactement ce que la tour surveille depuis h1 : c1 est pris, le pion n'avance plus, le roi blanc arrive.",
                              "…and one square is exactly what the rook has watched from h1 all along: c1 is covered, the pawn is frozen, the white king arrives.")},
                "Kb4",
                {"san": "Kxc2", "critical": True},
            ],
        },
        {
            "chapter": {"id": "check-trap", "title": c("L'échec qui rend service", "The check that does a favour")},
            "moves": [
                {"san": "Rb1+", "role": "trap",
                 "comment": c("Le réflexe : « échec ! ». Mais regardez où va le roi noir : DERRIÈRE son pion, exactement là où il rêvait d'aller. L'échec lui a offert le temps que votre roi n'avait pas à donner. Verdict tablebase : nulle.",
                              "The reflex: “check!”. But watch where the black king goes: BEHIND his pawn, exactly where he dreamt of standing. The check handed him the tempo your king could not spare. Tablebase verdict: draw."),
                 "critical": True},
                {"san": "Kc3",
                 "comment": c("Roi devant, pion derrière : le convoi est blindé. La tour finira par se vendre contre le pion — nulle.",
                              "King in front, pawn behind: the convoy is armoured. The rook will end up selling herself for the pawn — draw.")},
            ],
        },
        {
            "chapter": {"id": "behind-trap", "title": c("« Derrière le pion passé » ne suffit pas", "“Behind the passed pawn” is not enough")},
            "moves": [
                {"san": "Rc1", "role": "trap",
                 "comment": c("La règle célèbre — « la tour derrière le pion passé » — appliquée… et nulle quand même : la règle vaut pour les finales de TOURS, pas pour la course sèche. Ici la tour derrière n'attaque rien que le roi noir ne protège, et votre roi reste spectateur.",
                              "The famous rule — “rook behind the passed pawn” — duly applied… and still a draw: that rule is about ROOK endings, not the bare race. Here the rook behind attacks nothing the black king doesn't guard, and your own king stays a spectator."),
                 "critical": True},
                {"san": "Kb3",
                 "comment": c("L'escorte se forme, le pion avancera sous blindage : c3, c2, et la tour devra l'acheter. Un seul coup a jamais gagné ici : Kf6.",
                              "The escort forms, the pawn will advance under armour: c3, c2, and the rook will have to buy it. Only one move ever won here: Kf6.")},
            ],
        },
    ],
}
