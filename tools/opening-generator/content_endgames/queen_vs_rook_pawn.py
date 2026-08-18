# -*- coding: utf-8 -*-
"""Dame contre pion-tour en 7e — l'exception du coin.

Sourcé Wikipédia (« Queen versus pawn endgame ») : contrairement à un pion
central, un pion-tour (colonne a ou h) déjà en 2e rangée peut tenir la
nulle si le roi attaquant est trop loin — le roi défenseur trouve un
perpétuel abri entre les cases a1/b1/b2, la dame ne pouvant jamais l'en
déloger sans se faire prendre. Racine à 4 pièces, chaque coup blanc
tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-rook-pawn",
    "name": "Queen vs Rook's Pawn — the Corner Draw",
    "side": "black",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "3Q4/1K6/8/8/8/8/pk6/8 w - - 0 1",
    "summary": c(
        "Un pion central en 2e rangée perd toujours contre la dame seule. Un pion-tour, non — si le roi blanc est trop loin, le roi noir trouve un abri perpétuel dans le coin, entre a1, b1 et b2, que la dame ne perce jamais.",
        "A central pawn on the 2nd rank always loses to a lone queen. A rook's pawn doesn't — if White's king is too far away, Black's king finds permanent shelter in the corner, shuffling a1, b1 and b2, which the queen never breaks.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-corner-shuffle", "title": c("La navette du roi dans le coin", "The king's shuttle in the corner")},
            "moves": [
                {"san": "Qd2+", "comment": c("La dame vient donner l'échec pour repousser le roi noir — la manœuvre habituelle contre un pion central.", "The queen comes to check and push Black's king back — the usual method against a central pawn.")},
                {"san": "Kb1",
                 "comment": c("Le roi noir recule mais ne s'enferme pas encore tout à fait dans le coin. Depuis b1, il garde deux cases de repli.",
                              "Black's king retreats but doesn't yet lock itself fully into the corner. From b1, it keeps two squares to fall back on."),
                 "critical": True},
                {"san": "Qd1+", "comment": c("Nouvel échec, depuis l'autre côté.", "Another check, from the other side.")},
                {"san": "Kb2",
                 "comment": c("Et le roi revient sur b2 — exactement la position de départ, dame décalée d'une case. Rien n'a progressé.", "And the king comes back to b2 — exactly the starting position, queen shifted one square. Nothing has progressed."),
                 "critical": True},
                "Qd2+",
                {"san": "Kb1",
                 "comment": c("La boucle est bouclée : on retombe très exactement sur la position d'il y a deux coups. Le roi noir a une navette à deux cases (b1-b2) que la dame ne referme jamais toute seule, tant que son propre roi reste trop loin pour venir prêter main-forte.",
                              "The loop closes: we land right back on the position from two moves ago. Black's king has a two-square shuttle (b1-b2) that the queen never closes on its own, as long as its own king stays too far away to lend a hand."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "grab-the-pawn", "title": c("Prendre le pion avec échec ?", "Grab the pawn with check?")},
            "moves": [
                "Qd2+",
                "Kb1",
                {"san": "Qxa2+",
                 "comment": c("Tentant — le pion tombe, et c'est échec en prime. Mais la dame atterrit juste à côté du roi noir, sans que son propre roi (encore sur b7) ne la défende.",
                              "Tempting — the pawn falls, and it's check to boot. But the queen lands right next to Black's king, undefended by White's own king (still on b7)."),
                 "critical": True},
                {"san": "Kxa2",
                 "comment": c("Le roi noir croque la dame gratuitement. Plus rien sur l'échiquier que les deux rois — nulle, cette fois pour une tout autre raison que le pat du coin.",
                              "Black's king gobbles the queen for free. Nothing left on the board but the two kings — a draw, this time for a completely different reason than the corner stalemate."),
                 "critical": True},
            ],
        },
    ],
}
