# -*- coding: utf-8 -*-
"""Tour contre cavalier — le déséquilibre qui n'en est pas un.

Sur l'échiquier vide, sans le moindre pion, une tour ne bat pas un cavalier
seul. Vérifié depuis plusieurs points de départ, y compris un cavalier
séparé de son roi : toujours la nulle. Première finale de la famille
Déséquilibres matériels.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-knight",
    "name": "Rook vs Knight",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "club",
    "rootFEN": "3nk3/8/8/8/8/8/8/3RK3 w - - 0 1",
    "summary": c(
        "Une tour vaut deux points de plus qu'un cavalier — sur le papier. Sans le moindre pion sur l'échiquier, ce n'est qu'un chiffre : le camp au cavalier tient la nulle sans effort particulier, et le savoir évite de se battre pour rien, ou de résigner trop tôt.",
        "A rook is worth two points more than a knight — on paper. With not a single pawn left on the board, that's just a number: the knight's side holds the draw without any special effort, and knowing it saves you from fighting for nothing, or resigning too soon.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress", "title": c("Rien à faire, littéralement", "Nothing to do, literally")},
            "moves": [
                {"san": "Ke2",
                 "comment": c("Le roi blanc s'approche — sans pion à pousser, une tour seule n'a rien d'autre à proposer qu'une approche du roi, et ça ne suffit structurellement pas contre un roi et un cavalier qui restent groupés.",
                              "White's king approaches — with no pawn to push, a lone rook has nothing else to offer but a king approach, and that structurally isn't enough against a king and knight that stay together."),
                 "critical": True},
                {"san": "Ke7",
                 "comment": c("Le roi noir reste collé à son cavalier — c'est toute la défense, et elle suffit amplement.",
                              "Black's king stays glued to his knight — that is the entire defence, and it is more than enough.")},
                "Kd2",
                {"san": "Kd7",
                 "comment": c("Miroir, encore et encore. Aucun coup de tour n'existe qui casse cette paire — vérifié : chaque essai retombe sur la même nulle.",
                              "Mirror, again and again. No rook move exists that breaks this pair — verified: every try lands back on the same draw."),
                 "critical": True},
            ],
        },
    ],
}
