# -*- coding: utf-8 -*-
"""Tour et mauvais pion-tour contre fou — la forteresse résiste même à la tour.

Sourcé Fine & Benko (« Basic Chess Endings », position de Berger), via
Wikipédia (« Wrong rook pawn ») : le mauvais pion-tour (couleur de
promotion opposée à celle du fou adverse) ferme une forteresse si solide
que même une tour entière de matériel en plus ne suffit pas à la percer.
Racine à 5 pièces, chaque tentative blanche tranchée par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-wrong-pawn-vs-bishop",
    "name": "Rook and Wrong Rook's Pawn vs Bishop",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "7k/6R1/5K2/7P/8/8/8/1b6 w - - 0 1",
    "summary": c(
        "Une tour entière de plus, et pourtant : le pion h est le mauvais pion-tour pour ce fou, et le roi noir tient le coin de promotion. La forteresse déjà vue contre le fou seul résiste identique face à la tour — matériel en plus, résultat inchangé.",
        "A whole extra rook, and yet: the h-pawn is the wrong rook's pawn for this bishop, and Black's king holds the promotion corner. The fortress already seen against the lone bishop resists the exact same way against the rook — extra material, same result.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress-holds", "title": c("La forteresse tient, tour ou pas", "The fortress holds, rook or no rook")},
            "moves": [
                {"san": "Ke5",
                 "comment": c("Le roi blanc cherche du mouvement — la tour, elle, n'a nulle part où s'infiltrer tant que le roi noir garde h8.", "White's king looks for activity — the rook, meanwhile, has nowhere to infiltrate as long as Black's king holds h8."),
                 "critical": True},
                {"san": "Bd3",
                 "comment": c("Le fou se repositionne sans jamais avoir besoin de bouger le roi. Nulle vérifiée : depuis ce carrefour, aucune tentative blanche testée par l'oracle n'a jamais progressé.",
                              "The bishop repositions without ever needing to move its king. Verified draw: from this crossroads, no White try the oracle tested ever made progress."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "give-up-the-rook", "title": c("Céder la tour ne change rien", "Giving up the rook changes nothing")},
            "moves": [
                {"san": "Rh7+",
                 "comment": c("Provocation : la tour s'offre sur h7, où ni le roi (trop loin) ni le pion (qui ne capture que vers g6) ne la défendent.",
                              "A provocation: the rook offers itself on h7, where neither the king (too far) nor the pawn (which only captures toward g6) defends it."),
                 "critical": True},
                {"san": "Kxh7",
                 "comment": c("Le roi noir la prend gratuitement — et la position retombe très exactement sur la forteresse du mauvais fou déjà connue : roi et fou seuls contre roi et pion-tour. Céder la tour entière ne change rien au verdict : c'était déjà nulle sans elle.",
                              "Black's king takes it for free — and the position lands exactly on the already-known wrong-bishop fortress: lone king and bishop against king and rook's pawn. Giving up the entire rook changes nothing about the verdict: it was already a draw without it."),
                 "critical": True},
            ],
        },
    ],
}
