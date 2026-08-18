# -*- coding: utf-8 -*-
"""Deux pions contre un, même aile — le piège n'est pas où on l'attend.

Surprise vérifiée à l'oracle : garder les tours sur l'échiquier ne fait que
la NULLE. Le seul chemin vers le gain passe par l'échange — la majorité de
pions ne parle qu'une fois les tours parties.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-kingside-majority",
    "name": "Kingside Pawn Majority",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "advanced",
    "rootFEN": "4r1k1/6p1/8/8/8/8/5PP1/4R1K1 w - - 0 1",
    "summary": c(
        "Un pion de plus à l'aile roi, tours encore sur l'échiquier : la tentation est de manœuvrer, de gagner du terrain pièce en main. Et pourtant la seule voie vers le point complet est de TOUT ÉCHANGER — la majorité ne parle qu'en finale de pions pure.",
        "An extra kingside pawn, rooks still on the board: the temptation is to manoeuvre, to gain ground piece in hand. And yet the only road to the full point is to TRADE EVERYTHING — the majority only speaks once it's a pure pawn ending.",
    ),
    "lines": [
        {
            "chapter": {"id": "trade", "title": c("Échanger pour laisser parler le pion", "Trade to let the pawn speak")},
            "moves": [
                {"san": "Rxe8+",
                 "comment": c("Le seul coup qui gagne — et il consiste à donner tout de suite ce qu'on pourrait garder. Une fois les tours parties, plus aucune ressource tactique ne peut sauver le camp en infériorité : il ne reste qu'un décompte de cases.",
                              "The only move that wins — and it consists of giving up right away what could be kept. Once the rooks are gone, no tactical resource can save the side down a pawn: only square-counting remains."),
                 "critical": True},
                {"san": "Kf7",
                 "comment": c("Course de rois désormais — exactement le terrain où un pion de plus se convertit proprement.",
                              "A king race now — exactly the terrain where an extra pawn converts cleanly.")},
                "Re2", "Kf6", "Kh2", "Kf5", "Kh3", "Kf4", "Kh4", "Kf5", "g3", "Kf6", "f3", "Kf5",
                {"san": "Kh5",
                 "comment": c("Le roi blanc prend l'opposition décisive pendant que le roi noir était occupé ailleurs — la préparation g3/f3 vient de payer.",
                              "The white king takes the decisive opposition while Black's king was busy elsewhere — the g3/f3 preparation just paid off.")},
                {"san": "g6+",
                 "comment": c("Percée. À partir d'ici, c'est le cours « La percée » qui prend le relais — le pion supplémentaire fabrique un passé que le roi noir ne peut plus rattraper.",
                              "Breakthrough. From here, the “Breakthrough” course takes over — the extra pawn manufactures a passer Black's king can no longer catch."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "keep-rooks", "title": c("Garder les tours ? Seulement la nulle", "Keep the rooks? Only a draw")},
            "moves": [
                {"san": "Ra1", "role": "trap",
                 "comment": c("Le réflexe : manœuvrer, activer la tour, ne rien précipiter. Et le résultat en pâtit : SANS l'échange, la tour noire trouve toujours assez d'activité et d'échecs pour tenir — la majorité de pions ne suffit pas à elle seule tant que les pièces lourdes compliquent le jeu.",
                              "The reflex: manoeuvre, activate the rook, rush nothing. And the result suffers for it: WITHOUT the trade, Black's rook always finds enough activity and checks to hold — the pawn majority alone isn't enough while heavy pieces complicate matters."),
                 "critical": True},
                {"san": "g6",
                 "comment": c("Les Noirs répondent par une activité de tour qui neutralise tout — comptez les tentatives blanches : aucune n'a jamais fait mieux que match nul depuis ce carrefour.",
                              "Black answers with rook activity that neutralises everything — count White's tries from this crossroads: none ever did better than a draw.")},
            ],
        },
    ],
}
