# -*- coding: utf-8 -*-
"""La défense Cochrane — clouer le fou pour tenir la nulle.

Sourcé John Cochrane : contre tour et fou, la tour défenseur cloue le fou
adverse contre son propre roi, sur une colonne centrale, avec au moins
deux colonnes d'écart entre les rois. Tant que le clouage tient, rien ne
passe. Racine à 5 pièces, chaque choix noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-cochrane-defence",
    "name": "The Cochrane Defence",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "8/8/1k1K4/3B4/R7/8/8/3r4 w - - 0 1",
    "summary": c(
        "Tour et fou contre tour seule — en général gagnant, sauf ici : la tour noire cloue le fou blanc contre son propre roi sur la colonne d, avec les rois à bonne distance. Tant que le clouage tient, la position ne bouge pas d'un pouce.",
        "Rook and bishop versus a lone rook — usually winning, except here: Black's rook pins White's bishop against its own king on the d-file, with the kings a healthy distance apart. As long as the pin holds, the position doesn't budge an inch.",
    ),
    "lines": [
        {
            "chapter": {"id": "keep-the-pin", "title": c("Le clouage tient, quoi qu'il arrive", "The pin holds, whatever happens")},
            "moves": [
                {"san": "Ra1", "comment": c("La tour blanche cherche de l'activité ailleurs — le fou, lui, ne peut toujours pas bouger sans abandonner son roi à un échec.", "White's rook looks for activity elsewhere — the bishop still can't move without leaving its king in check.")},
                {"san": "Rd3",
                 "comment": c("La tour noire reste sur la colonne d : c'est elle qui fait tout le travail. Elle pourrait même croquer la tour blanche pour simplifier — tour contre fou seul est déjà nul, comme vu ailleurs — mais rien ne presse. Nulle vérifiée : aucune tentative blanche testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Black's rook stays on the d-file: it's doing all the work. It could even grab White's rook to simplify — rook versus lone bishop is already a draw, as seen elsewhere — but there's no hurry. Verified draw: no White try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "release-the-pin", "title": c("Lâcher le clouage, perdre la tour", "Releasing the pin loses the rook")},
            "moves": [
                "Ra1",
                {"san": "Rb1", "role": "trap",
                 "comment": c("Semble actif — aller chercher la tour blanche sur la première rangée. Mais quitter la colonne d libère le fou, qui n'est plus cloué à rien.",
                              "Looks active — go hunt White's rook on the back rank. But leaving the d-file frees the bishop, which is no longer pinned to anything."),
                 "critical": True},
                {"san": "Rxb1+",
                 "comment": c("La tour blanche croque la tour noire avec échec — gratuitement. Sans le clouage, il ne restait plus la moindre raison de laisser la tour noire s'aventurer sur la première rangée.",
                              "White's rook grabs Black's rook with check — for free. Without the pin, there was no reason left to let Black's rook wander onto the back rank."),
                 "critical": True},
            ],
        },
    ],
}
