# -*- coding: utf-8 -*-
"""L'échelle de Lasker (Emanuel Lasker, 1890) — le roi et la tour descendent l'escalier.

Position exacte sourcée ARVES (« Ballet dancing », 1890, gain blanc) ; chaque
coup vérifié à la tablebase : 1.Kb8 est l'UNIQUE gain (toute autre idée,
Txh2 comprise, annule), et la descente historique est exactement la ligne
optimale de l'oracle, échec après échec, jusqu'à Txh2 et c8=D.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-lasker-ladder",
    "name": "Lasker's Ladder (1890)",
    "side": "white",
    "kind": "endgame",
    "family": "practical",
    "level": "advanced",
    "rootFEN": "2K5/2P4R/k7/8/8/8/2r4p/8 w - - 0 1",
    "summary": c(
        "Quatre ans avant son titre mondial, Emanuel Lasker compose ceci (1890) : un pion blanc prêt à couronner, un pion noir prêt à couronner, et une machine à gagner un temps. Roi et tour blancs descendent l'échiquier comme un escalier — et en bas, le pion h tombe avec la tour noire.",
        "Four years before his world title, Emanuel Lasker composed this (1890): a white pawn ready to queen, a black pawn ready to queen, and a tempo-winning machine. White's king and rook walk down the board like a staircase — and at the bottom, the h-pawn falls together with the black rook.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("L'escalier", "The staircase")},
            "moves": [
                {"san": "Kb8",
                 "comment": c("L'UNIQUE coup qui gagne — même Th6+ tout de suite n'obtient que la nulle. Le roi s'écarte de c8 : la promotion est une menace réelle, et la tour noire va devoir courir deux lièvres.",
                              "The ONLY winning move — even Rh6+ at once only draws. The king steps off c8: promotion becomes a real threat, and the black rook will have to chase two hares."),
                 "critical": True},
                {"san": "Rb2+",
                 "comment": c("Seule ressource : écarter le roi à coups d'échecs.",
                              "The only resource: drive the king away with checks.")},
                {"san": "Ka8",
                 "comment": c("Et de nouveau c8=D menace — la tour doit rentrer.",
                              "And again c8=Q is threatened — the rook must run back.")},
                {"san": "Rc2",
                 "comment": c("Forcé. Voyez le mécanisme : tant que la tour fait la navette b2-c2, la tour BLANCHE, elle, a le droit de descendre d'un étage — avec échec, donc gratuitement.",
                              "Forced. Now watch the mechanism: while the black rook shuttles b2-c2, the WHITE rook gets to walk down one floor — with check, hence for free.")},
                {"san": "Rh6+",
                 "comment": c("Premier étage. Le roi noir doit bouger, et l'échange complet (échec b2, retour c2) recommence un cran plus bas.",
                              "First floor down. The black king must move, and the whole exchange (check on b2, return to c2) restarts one notch lower."),
                 "critical": True},
                {"san": "Ka5"},
                {"san": "Kb7"},
                "Rb2+",
                {"san": "Ka7"},
                "Rc2",
                {"san": "Rh5+",
                 "comment": c("Deuxième étage. Comptez ce que les échecs noirs rapportent : rien — le roi blanc revient toujours ; et chaque cycle, la tour blanche gagne une rangée.",
                              "Second floor. Count what Black's checks achieve: nothing — the white king always comes back; and every cycle, the white rook gains one rank.")},
                {"san": "Ka4"},
                {"san": "Kb6"},
                "Rb2+",
                {"san": "Ka6"},
                "Rc2",
                {"san": "Rh4+"},
                {"san": "Ka3"},
                {"san": "Kb6",
                 "comment": c("Le roi repart au travail — remarquez qu'il choisit sa case selon la rangée de la tour noire : jamais en face d'un échec utile.",
                              "The king goes back to work — note how he picks his square by the black rook's rank: never in line with a useful check.")},
                "Rb2+",
                {"san": "Ka5"},
                "Rc2",
                {"san": "Rh3+",
                 "comment": c("Dernier étage utile : cet échec-ci pousse le roi noir SUR la deuxième rangée — celle de sa propre tour.",
                              "The last floor that matters: this check shoves the black king ONTO the second rank — his own rook's rank."),
                 "critical": True},
                {"san": "Kb2",
                 "comment": c("Où aller ? a4 et b4 sont pris par le roi blanc. Le roi rejoint sa tour… et devient son problème.",
                              "Where to go? a4 and b4 belong to the white king. The king joins his rook… and becomes its problem.")},
                {"san": "Rxh2",
                 "comment": c("La récolte. La tour c2 est attaquée et n'a plus de bonne case : rester, c'est subir Txc2+ suivi de c8=D+ ; s'échanger, c'est laisser couronner. Le pion h que Blanc a « négligé » douze coups durant tombe exactement quand sa chute gagne.",
                              "Harvest time. The c2-rook is attacked and out of squares: staying means Rxc2+ followed by c8=Q+; trading means letting the pawn queen. The h-pawn White “neglected” for twelve moves falls at exactly the moment its fall wins."),
                 "critical": True},
                {"san": "Rxh2"},
                {"san": "c8=Q",
                 "comment": c("Dame contre tour : gain connu — c'est le cours « Dame contre tour ». L'étude, elle, est finie : l'escalier a transformé deux pions face à face en une pointe de géométrie pure.",
                              "Queen against rook: a known win — that is the “Queen vs Rook” course. The study itself is over: the staircase turned two facing pawns into a point of pure geometry."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "grab-now", "title": c("Prendre h2 tout de suite", "Grabbing h2 at once")},
            "moves": [
                {"san": "Rxh2", "role": "trap",
                 "comment": c("Le pion noir allait à dame — le supprimer semble urgent. Mais regardez le roi blanc : il occupe c8, la case de SA promotion.",
                              "The black pawn was about to queen — removing it feels urgent. But look at the white king: he stands on c8, his OWN promotion square."),
                 "critical": True},
                {"san": "Rxh2"},
                {"san": "Kb8"},
                "Rb2+",
                {"san": "Ka8"},
                {"san": "Rc2",
                 "comment": c("Et plus rien : sans tour blanche, pas d'échecs descendants, donc pas de machine à temps. La tour noire fait la navette b2-c2 pour toujours ; le pion c ne couronnera jamais. Nulle.",
                              "And nothing left: without the white rook there are no descending checks, so no tempo machine. The black rook shuttles b2-c2 forever; the c-pawn will never queen. Draw.")},
            ],
        },
        {
            "chapter": {"id": "grab-early", "title": c("Prendre h2 un instant trop tôt", "Grabbing h2 one instant too soon")},
            "moves": [
                "Kb8", "Rb2+", "Ka8", "Rc2",
                {"san": "Rxh2", "role": "trap",
                 "comment": c("Cette fois le roi a quitté c8 — alors, mûr, le pion h ? Non : la tour blanche quittait la SEPTIÈME rangée, et elle y avait un second métier.",
                              "This time the king has left c8 — so, ripe for the taking? No: the white rook is leaving the SEVENTH rank, where it held a second job."),
                 "critical": True},
                {"san": "Rxc7",
                 "comment": c("Le voilà, le second métier : h7 gardait c7. Le pion tombe, tour contre tour, nulle. (Surtout pas 5…Txh2?? 6.c8=D+ et la dame gagne.) La descente n'était pas un ornement : chaque échec de Th6+ à Th3+ gardait c7 défendu À DISTANCE.",
                              "There it is: h7 was guarding c7. The pawn falls, rook versus rook, draw. (Certainly not 5…Rxh2?? 6.c8=Q+ and the queen wins.) The staircase was no ornament: every check from Rh6+ to Rh3+ kept c7 defended AT A DISTANCE.")},
            ],
        },
    ],
}
