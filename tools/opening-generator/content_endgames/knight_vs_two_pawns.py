# -*- coding: utf-8 -*-
"""Cavalier contre deux pions séparés — un seul cavalier, deux ailes à la fois.

Même position, un seul rang de différence (5e contre 6e) — vérifié : le
cavalier tient depuis le centre à distance raisonnable, mais s'effondre dès
que les DEUX pions atteignent la 6e ensemble.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-knight-vs-two-pawns",
    "name": "Knight vs Two Separated Pawns",
    "side": "white",
    "kind": "endgame",
    "family": "knights",
    "level": "advanced",
    "rootFEN": "4k3/8/P6P/8/3n4/8/8/4K3 w - - 0 1",
    "summary": c(
        "Un cavalier peut bloquer un pion isolé pour toujours — mais il n'existe qu'en un seul endroit à la fois. Deux pions passés aux deux extrémités de l'échiquier lui posent une question à laquelle il n'a pas de réponse, à condition qu'ils soient assez avancés.",
        "A knight can blockade a single pawn forever — but it exists in only one place at a time. Two passed pawns at opposite ends of the board ask it a question it has no answer to, provided they're far enough advanced.",
    ),
    "lines": [
        {
            "chapter": {"id": "sixth-rank", "title": c("La 6e rangée des deux côtés : trop tard", "The 6th rank on both sides: too late")},
            "moves": [
                {"san": "a7",
                 "comment": c("Un seul des deux pions avance — mais le cavalier ne peut faire face qu'à UNE menace à la fois, et l'autre pion, resté en h6, attend son tour sans que rien ne le gêne. Un rang plus tôt (5e rangée au lieu de 6e), la MÊME position tient : le cavalier, posté au centre, a alors le temps de courir d'une aile à l'autre. Le rang seul décide.",
                              "Only one of the two pawns advances — but the knight can only face ONE threat at a time, and the other pawn, still on h6, waits its turn with nothing in its way. One rank earlier (5th instead of 6th), the SAME position holds: the centrally-posted knight then has time to gallop from wing to wing. The rank alone decides."),
                 "critical": True},
                {"san": "Nf3+",
                 "comment": c("Le cavalier tente d'intercepter en chemin — mais il ne peut être qu'à un endroit, et il en manque toujours un.",
                              "The knight tries to intercept along the way — but he can only be in one place, and there's always one pawn too many.")},
                "Kf2",
                {"san": "Ne5",
                 "comment": c("Trop tard pour arrêter le premier pion, et le second (h6) n'a toujours personne devant lui.",
                              "Too late to stop the first pawn, and the second (h6) still has nobody in front of it.")},
                {"san": "a8=Q+",
                 "comment": c("Une dame surgit avec échec — et il reste ENCORE un pion h6 libre, poussé par un roi qui n'a jamais eu besoin de choisir son camp.",
                              "A queen appears with check — and there's STILL a free h6 pawn, pushed by a king who never had to pick a side."),
                 "critical": True},
            ],
        },
    ],
}
