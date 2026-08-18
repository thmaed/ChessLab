# -*- coding: utf-8 -*-
"""Forteresse de Karstedt — fou et cavalier tiennent tête à la dame.

Sourcé Karstedt (1903) : la seule configuration connue où un roi, un fou
et un cavalier seuls (sans le moindre pion) tiennent la nulle contre une
dame. Le roi reste au coin h1/g1, le fou garde g2 (et donc le cavalier sur
e4), qui bouche la seule case par laquelle la dame pourrait s'infiltrer.
Racine à 5 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-karstedt-fortress",
    "name": "The Karstedt Fortress",
    "side": "white",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "8/8/8/1q2k3/4N3/8/6B1/7K w - - 0 1",
    "summary": c(
        "Un roi, un fou et un cavalier, sans un seul pion, tiennent la nulle contre une dame seule — la seule configuration connue de ce genre. La clé : le fou reste sur g2, où il garde à la fois le roi et le cavalier posté juste devant lui.",
        "A king, a bishop and a knight, without a single pawn, hold a draw against a lone queen — the only known configuration of its kind. The key: the bishop stays on g2, where it guards both the king and the knight posted just in front of it.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-fortress-holds", "title": c("Le fou ne bouge jamais de g2", "The bishop never leaves g2")},
            "moves": [
                {"san": "Kg1",
                 "comment": c("Le roi reste dans le coin, à l'abri — la dame a beau approcher, elle ne trouve jamais de prise.", "The king stays in the corner, sheltered — the queen can approach all it likes, it never finds a way in."),
                 "critical": True},
                "Qb1+",
                {"san": "Kh2",
                 "comment": c("Un simple pas de côté suffit à parer l'échec, sans jamais avoir à bouger le fou ni le cavalier. Nulle vérifiée : aucune tentative noire testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "A simple side-step is enough to parry the check, without ever needing to move the bishop or the knight. Verified draw: no Black try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "the-bishop-must-stay", "title": c("Le fou doit rester : bouger, c'est perdre le cavalier", "The bishop must stay: move it, and the knight falls")},
            "moves": [
                "Kg1",
                "Qb1+",
                {"san": "Bf1", "role": "trap",
                 "comment": c("Une case qui semble tout aussi sûre pour parer l'échec — le fou bloque la première rangée. Mais il abandonne du même coup la garde du cavalier sur e4.",
                              "A square that looks just as safe to parry the check — the bishop blocks the back rank. But it abandons the defence of the knight on e4 at the same time."),
                 "critical": True},
                {"san": "Qxe4",
                 "comment": c("La dame croque le cavalier gratuitement. Sans lui, il ne reste plus de forteresse — seuls le roi et le fou ne peuvent rien face à la dame.",
                              "The queen grabs the knight for free. Without it, there's no fortress left — king and bishop alone can do nothing against the queen."),
                 "critical": True},
            ],
        },
    ],
}
