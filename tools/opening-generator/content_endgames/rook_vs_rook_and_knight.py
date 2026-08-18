# -*- coding: utf-8 -*-
"""Tour et cavalier contre tour — le cavalier en plus ne suffit pas.

Contrepartie du fou : là où tour et fou l'emportent en général sur une
tour seule (sous réserve d'exceptions, voir la position de Szén), tour et
cavalier ne l'emportent PAS en général. Le cavalier manque de la portée
nécessaire pour aider sa tour à construire un filet de mat contre une
défense correcte. Vérifié depuis une position neutre : tous les essais
blancs testés par l'oracle retombent sur la nulle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-rook-and-knight",
    "name": "Rook vs Rook and Knight",
    "side": "black",
    "kind": "endgame",
    "family": "imbalances",
    "level": "club",
    "rootFEN": "1r6/8/4k3/8/4K3/2N5/8/4R3 w - - 0 1",
    "summary": c(
        "Miroir de « tour et fou contre tour » : ici, le cavalier en plus ne change presque jamais le verdict. Depuis une position neutre, chaque tentative blanche testée par l'oracle retombe sur la nulle — y compris céder le cavalier lui-même.",
        "The mirror of \"rook and bishop versus rook\": here, the extra knight almost never changes the verdict. From a neutral position, every White try the oracle tested lands back on a draw — including giving the knight away outright.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-knight-changes-nothing", "title": c("Le cavalier ne change rien, même perdu", "The knight changes nothing, even lost")},
            "moves": [
                {"san": "Na4",
                 "comment": c("Le cavalier cherche de l'activité — sans qu'il y ait de plan qui transforme réellement la position en gain. Depuis la racine, les vingt coups blancs légaux retombent tous sur la même nulle.",
                              "The knight looks for activity — without there being a plan that actually turns the position into a win. From the start, all twenty legal White moves land on the exact same draw."),
                 "critical": True},
                {"san": "Rb4+", "comment": c("Échec, et la tour noire attaque le cavalier au passage.", "Check, and Black's rook attacks the knight along the way.")},
                {"san": "Ke3",
                 "comment": c("Le roi blanc se met à l'abri sans défendre le cavalier — ce n'est pas la peine : sa perte ne change rien au résultat.",
                              "White's king tucks away without defending the knight — no need to: losing it changes nothing about the result."),
                 "critical": True},
                {"san": "Rxa4",
                 "comment": c("Les noirs prennent le cavalier gratuitement — et la position, déjà nulle avant, reste exactement nulle : tour contre tour, sans rien à convertir de part ni d'autre.",
                              "Black wins the knight for free — and the position, already a draw before, stays exactly a draw: rook against rook, nothing left to convert for either side."),
                 "critical": True},
            ],
        },
    ],
}
