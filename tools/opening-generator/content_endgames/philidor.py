# -*- coding: utf-8 -*-
"""La position de Philidor — LA nulle des finales de tours.

Dérivée sous l'oracle. Au passage, la tablebase a nuancé un dogme de manuel :
dans CETTE position, même la tour passive tient après e6 — on ne l'enseigne
donc pas comme perdante (l'audit l'aurait refusé). La méthode de Philidor
reste la seule qui tient PARTOUT, c'est comme ça qu'elle est présentée.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-philidor",
    "name": "The Philidor Position",
    "side": "black",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "1r2k3/R7/8/3KP3/8/8/8/8 b - - 0 1",
    "summary": c(
        "Un pion de moins en finale de tours ? Philidor a montré en 1749 que la nulle se JOUE, en deux temps : la tour barre le sixième rang, puis — dès que le pion y met le pied — file derrière donner des échecs sans fin. La défense la plus rentable des échecs.",
        "A pawn down in a rook ending? Philidor showed in 1749 that the draw is PLAYED, in two steps: the rook bars the sixth rank, then — the moment the pawn steps onto it — swings behind for endless checks. The best-paying defence in chess.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le barrage, puis les échecs", "The barrier, then the checks")},
            "moves": [
                {"san": "Rb6",
                 "comment": c("Le BARRAGE : la tour s'installe sur le rang que le roi blanc doit traverser, et le lui interdit tout entier. Tant que le pion n'a pas avancé, il n'existe AUCUN moyen de forcer le passage.",
                              "The BARRIER: the rook camps on the very rank the white king must cross, and denies all of it. Until the pawn advances, there is NO way through."),
                 "critical": True},
                {"san": "e6",
                 "comment": c("Le seul essai : pousser le pion pour rendre le sixième rang au roi. Mais ce pion vient de perdre sa dernière ombre — plus rien n'abritera le roi blanc des échecs.",
                              "The only try: push the pawn to give the sixth rank back to the king. But that pawn just lost its last shadow — nothing will shelter the white king from checks now.")},
                {"san": "Rb1",
                 "comment": c("Le PIVOT, tout Philidor tient dans ce coup : mission du barrage terminée, la tour file À L'AUTRE BOUT pour mitrailler par derrière. Ni avant ni après : exactement quand le pion touche le sixième rang.",
                              "The PIVOT — all of Philidor lives in this move: the barrier's job done, the rook races to THE FAR END to strafe from behind. Not sooner, not later: exactly when the pawn touches the sixth rank."),
                 "critical": True},
                "Kd6",
                {"san": "Rd1+", "comment": c("Et ça commence. Comptez les abris possibles du roi blanc : il n'y en a pas.",
                                             "And so it begins. Count the white king's shelters: there are none.")},
                "Ke5",
                {"san": "Re1+", "comment": c("La tour écheque à DISTANCE MAXIMALE : huit rangées d'écart, le roi ne peut jamais l'approcher pour la chasser.",
                                             "The rook checks from MAXIMUM range: eight ranks away, the king can never walk over to shoo it.")},
                "Kf6",
                {"san": "Rf1+",
                 "comment": c("Perpétuel. Le roi blanc peut errer où il veut : sans abri, chaque case ne vaut qu'un échec de plus. La nulle est un fait, plus une espérance.",
                              "Perpetual. The white king may wander where he likes: with no shelter, every square is worth exactly one more check. The draw is a fact now, not a hope."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "barrier-holds", "title": c("Le barrage tient tout seul", "The barrier holds by itself")},
            "moves": [
                "Rb6",
                {"san": "Ra8+", "comment": c("Chasser le roi noir ? Il n'a besoin que de deux cases.",
                                             "Chase the black king? He only needs two squares.")},
                {"san": "Ke7",
                 "comment": c("Le roi reste au contact de la case de promotion — jamais plus loin que la rangée voisine.",
                              "The king stays in touch with the promotion square — never further than the next rank.")},
                {"san": "Ra7+", "comment": c("Et rien de mieux : le sixième rang reste infranchissable, la position se répète.",
                                             "And nothing better exists: the sixth rank stays sealed, the position repeats.")},
                {"san": "Ke8",
                 "comment": c("Retour exact au point de départ. C'est toute la beauté du barrage : il n'exige RIEN, que de la patience.",
                              "Back exactly where we started. That is the barrier's beauty: it demands NOTHING but patience.")},
            ],
        },
        {
            "chapter": {"id": "trade-trap", "title": c("L'échange qui perd tout", "The trade that loses everything")},
            "moves": [
                {"san": "Rb7", "role": "trap",
                 "comment": c("« J'échange les tours et je souffle. » Regardez la finale de pions AVANT d'échanger : le roi blanc est DEVANT son pion — c'est un gain de manuel pour lui (cours « L'opposition »). L'échange des tours est la DERNIÈRE décision d'une finale de tours : après, il n'y a plus de défense.",
                              "“Trade rooks and breathe.” Look at the pawn ending BEFORE trading: the white king stands IN FRONT of his pawn — a textbook win for him (see “The Opposition”). Trading rooks is the LAST decision of a rook ending: after it, there is no defence left."),
                 "critical": True},
                {"san": "Rxb7",
                 "comment": c("Il ne reste qu'un cours d'opposition — dans le mauvais rôle.",
                              "All that remains is an opposition lesson — on the wrong side of it.")},
            ],
        },
        {
            "chapter": {"id": "greed-trap", "title": c("Prendre le pion trop tôt", "Grabbing the pawn too soon")},
            "moves": [
                "Rb6", "e6",
                {"san": "Rxe6", "role": "trap",
                 "comment": c("Le pion se donne ? Non : il se VEND. Le roi blanc le couvrait — la tour noire vient de se vendre pour un pion.",
                              "Is the pawn free? No: it is BAIT. The white king covered it — the black rook just sold itself for a pawn."),
                 "critical": True},
                {"san": "Kxe6",
                 "comment": c("Tour contre pion. Le reste est le cours « Le mat à la tour », joué contre vous.",
                              "Rook for pawn. The rest is “The Rook Mate” course, played against you.")},
            ],
        },
    ],
}
