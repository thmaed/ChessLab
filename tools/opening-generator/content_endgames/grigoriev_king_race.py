# -*- coding: utf-8 -*-
"""Étude de Grigoriev — le seul coup de roi qui gagne, prix de La Stratégie.

Sourcé Grigoriev (étude primée à « La Stratégie »), via l'analyse d'Elkies
(« Endgame Explorations 9 »). Quatre coups blancs semblent également
raisonnables à la racine — pousser le pion e, ou ranger le roi sur g2/h2.
Un seul gagne. Racine à 5 pièces, dtm 61 : la plus longue technique
vérifiée du module. Chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-grigoriev-king-race",
    "name": "Grigoriev's Study — the Only King Move",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "8/8/8/3k3p/7P/7K/4P3/8 w - - 0 1",
    "summary": c(
        "Un pion e, un pion h de chaque côté, et quatre coups blancs qui se ressemblent tous. Un seul gagne — les trois autres, y compris pousser le pion, ne font que la nulle. La technique qui suit est la plus longue du module : 61 coups jusqu'à la conversion.",
        "One e-pawn, one h-pawn each, and four White tries that all look alike. Only one wins — the other three, including pushing the pawn, only draw. The technique that follows is the longest in the whole module: 61 moves to conversion.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-only-move", "title": c("Le seul coup qui gagne", "The only move that wins")},
            "moves": [
                {"san": "Kg3",
                 "comment": c("Le seul des quatre essais qui gagne. Pousser tout de suite (e3, e4+) ou ranger le roi sur g2/h2 semblent tout aussi actifs — et pourtant chacun ne fait que la nulle. Le plan, une fois lancé : avancer le pion e, l'abandonner au bon moment, puis foncer avec le roi empêcher le roi noir de rejoindre le coin h8, sa case de nulle.",
                              "The only one of four tries that wins. Pushing right away (e3, e4+) or tucking the king on g2/h2 look just as active — and yet each one only draws. The plan, once launched: advance the e-pawn, abandon it at the right moment, then race the king to keep Black's king away from h8, its drawing corner."),
                 "critical": True},
                {"san": "Ke4", "comment": c("Le roi noir avance aussi — il n'a rien de mieux à proposer.", "Black's king advances too — it has nothing better to offer.")},
                {"san": "Kg2",
                 "comment": c("Le roi blanc continue sa route vers l'aile dame, où sa présence va compter bien plus que celle du pion h.", "White's king continues its route toward the queenside, where its presence will matter far more than the h-pawn's."),
                 "critical": True},
                "Ke3",
                {"san": "Kf1",
                 "comment": c("Toujours la même idée : le roi progresse pendant que le roi noir n'a que des cases d'attente à offrir.", "Same idea throughout: the king makes progress while Black's king only has waiting moves to offer."),
                 "critical": True},
                "Ke4",
            ],
        },
        {
            "chapter": {"id": "push-too-early", "title": c("Pousser le pion tout de suite ?", "Pushing the pawn right away?")},
            "moves": [
                {"san": "e4+", "role": "trap",
                 "comment": c("Semble logique : créer un pion passé sans attendre. Mais avec échec, le roi noir capture aussitôt, et il ne reste plus la moindre trace de la marche de roi qui faisait tout le travail.",
                              "Seems logical: create a passed pawn without waiting. But with check, Black's king captures it at once, and not a trace remains of the king march that was doing all the work."),
                 "critical": True},
                {"san": "Kxe4",
                 "comment": c("Le pion tombe, et avec lui toute chance de gain — la position retombe à plat sur la nulle. Le roi devait ouvrir la route avant que le pion n'avance, jamais l'inverse.",
                              "The pawn falls, and with it every winning chance — the position flattens straight into a draw. The king had to clear the road before the pawn advanced, never the other way round."),
                 "critical": True},
            ],
        },
    ],
}
