# -*- coding: utf-8 -*-
"""Cases conjuguées — la case qui répond à la case, ou tout s'effondre.

Sourcé France-Échecs (article « Cases conjuguées ») : un exemple miniature
avec six paires de cases correspondantes, où le roi défenseur doit répondre
au bon endroit à CHAQUE coup du roi attaquant. Une seule case sur sept
répond correctement — toutes les autres perdent. Racine à 5 pièces, chaque
réponse noire tranchée par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-corresponding-squares",
    "name": "Corresponding Squares",
    "side": "black",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "8/8/1k6/p7/K7/P7/1P6/8 w - - 0 1",
    "summary": c(
        "L'opposition simple ne suffit plus ici : le roi noir doit répondre à CHAQUE coup du roi blanc par la case précise qui lui correspond — une sur sept. Toutes les autres perdent, certaines en plus de 40 coups sans que rien ne le laisse deviner sur l'échiquier.",
        "Simple opposition isn't enough here: Black's king must answer EVERY move of White's king with the one precise square that corresponds to it — one out of seven. All the others lose, some more than 40 moves later with nothing on the board to hint at it.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-right-square", "title": c("La bonne case, coup après coup", "The right square, move after move")},
            "moves": [
                {"san": "Kb3", "comment": c("Le roi blanc se met en route — vers quelle case le roi noir doit-il répondre ?", "White's king sets off — which square must Black's king answer with?")},
                {"san": "Kc5",
                 "comment": c("La seule case qui tienne. Sur les sept coups légaux disponibles ici, six perdent — certains en plus de quarante coups, sans qu'aucun indice visible ne le trahisse avant longtemps. C'est exactement ce que « case conjuguée » veut dire : b3 sur l'échiquier répond à c5, et à aucune autre case.",
                              "The only square that holds. Of the seven legal moves available here, six lose — some more than forty moves later, with no visible hint giving it away for a long time. This is exactly what \"corresponding square\" means: b3 on the board answers to c5, and to no other square."),
                 "critical": True},
                {"san": "Kc3", "comment": c("Le roi blanc continue sa manœuvre.", "White's king continues its manoeuvre.")},
                {"san": "Kd5",
                 "comment": c("Et le roi noir répond encore juste. La paire change (c3 répond maintenant à d5), mais le principe reste : une case, et une seule, préserve la nulle à chaque instant.",
                              "And Black's king answers correctly again. The pair changes (c3 now answers to d5), but the principle stays: one square, and only one, preserves the draw at each moment."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "one-square-off", "title": c("Une case à côté, et tout est perdu", "One square off, and it's all lost")},
            "moves": [
                "Kb3",
                {"san": "Kc6", "role": "trap",
                 "comment": c("Une case qui semble tout aussi raisonnable que c5 — même direction, même idée générale de rester proche. Et pourtant : elle perd.",
                              "A square that looks just as reasonable as c5 — same direction, same general idea of staying close. And yet: it loses."),
                 "critical": True},
                {"san": "Kc4",
                 "comment": c("Le roi blanc s'infiltre par la case que Kc6 laissait sans réponse — et rien ne l'arrête plus. La différence entre nulle et perte tenait à UNE case, invisible tant qu'on ne connaît pas la correspondance exacte.",
                              "White's king infiltrates through the square that Kc6 left unanswered — and nothing stops it from here. The difference between draw and loss came down to ONE square, invisible unless you know the exact correspondence."),
                 "critical": True},
            ],
        },
    ],
}
