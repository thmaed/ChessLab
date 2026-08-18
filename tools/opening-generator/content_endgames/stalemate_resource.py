# -*- coding: utf-8 -*-
"""Le pat comme ressource — le dernier tour de la tour perdue.

Position construite et vérifiée depuis zéro (aucune étude recopiée) : une
finale Dame contre Tour où les Noirs, objectivement perdus depuis
longtemps, tendent un piège à la partie ADVERSE. Volontairement distincte
de la position de Saavedra (sous-promotion d'un pion en tour, déjà dans le
catalogue) et de « Tour contre Fou — le bon coin » (forteresse à boucle,
déjà dans le catalogue) : ici il n'y a ni pion ni fou, seulement une dame
qui doit résister à l'envie de croquer ce qui semble gratuit. Racine à 4
pièces, chaque coup tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-theme-stalemate-resource",
    "name": "Stalemate as a Resource — the Rook's Last Trick",
    "side": "black",
    "kind": "endgame",
    "family": "themes",
    "level": "advanced",
    "rootFEN": "5K1k/Q7/8/8/8/8/1r6/8 b - - 0 1",
    "summary": c(
        "Les Noirs n'ont plus qu'un roi et une tour contre un roi et une dame : objectivement, c'est perdu depuis longtemps, rien ne peut changer ce verdict. Mais le PAT est une ressource pratique — la dernière carte d'un camp qui n'en a plus aucune autre.",
        "Black has nothing left but a king and a rook against a king and a queen: objectively, this has been lost for a long time, nothing can change that verdict. But STALEMATE is a practical resource — the last card for a side that has no other left.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-only-resource", "title": c("Le seul espoir : forcer la maladresse", "The only hope: force the blunder")},
            "moves": [
                {"san": "Rb7",
                 "comment": c("Objectivement la partie est perdue depuis longtemps — dame contre tour, aucun coup ne changera plus le verdict. Mais la tour attaque la dame, et pose aux Blancs une question qu'il faut résoudre avec précision.",
                              "Objectively the game has been lost for a long time — queen versus rook, no move will ever change that verdict. But the rook attacks the queen, and hands White a question that must be answered precisely."),
                 "critical": True},
                {"san": "Qxb7", "role": "trap",
                 "comment": c("La dame croque la tour — le réflexe le plus naturel du monde, matériellement gratuit. Et pourtant : la dame verrouille toute la 7e rangée (g7 ET h7 d'un seul coup), le roi blanc tient g8, et le roi noir n'est PAS en échec. PAT. Toute la leçon tient dans cette seule case : une position perdue depuis des heures qui redevient nulle parce que la dernière pièce noire est tombée sans échec et sans souffle.",
                              "The queen gobbles the rook — the most natural reflex in the world, materially free. And yet: the queen locks down the entire 7th rank (g7 AND h7 in one move), White's king holds g8, and Black's king is NOT in check. STALEMATE. The whole lesson lives in this one square: a position lost for hours that turns back into a draw because the last black piece fell with no check and no room to breathe."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "correct-technique", "title": c("La bonne défense : refuser le cadeau", "The correct defence: refuse the gift")},
            "moves": [
                "Rb7",
                {"san": "Qa6",
                 "comment": c("La seule chose que les Blancs doivent faire : NE PAS reprendre la tour depuis cette case-là. N'importe quelle case qui laisse la dame active hors de la 7e rangée gagne normalement — le piège n'existe que pour celui qui se précipite.",
                              "The only thing White must do: NOT recapture the rook from that particular square. Any square that keeps the queen active off the 7th rank wins normally — the trap only exists for whoever rushes in."),
                 "critical": True},
                {"san": "Rb8+",
                 "comment": c("La tour continue de harceler — c'est tout ce qui reste au camp perdant. Aucun de ces échecs ne mène nulle part : le roi blanc a toute la place du monde pour s'en écarter.",
                              "The rook keeps harassing — it's all the losing side has left. None of these checks lead anywhere: White's king has all the room in the world to step aside.")},
                {"san": "Ke7",
                 "comment": c("Et la conversion continue, exactement comme si la tour noire n'avait jamais rien tenté.",
                              "And the conversion carries on, exactly as if Black's rook had never tried anything at all.")},
            ],
        },
    ],
}
