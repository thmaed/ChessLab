# -*- coding: utf-8 -*-
"""La coupure verticale — quand le pion n'a même plus besoin d'escorte.

Ligne DTM-optimale (tablebase) : deux colonnes de coupure suffisent à ce que
le roi noir n'existe simplement plus pour la suite de la partie.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-vertical-cutoff",
    "name": "The Vertical Cut-Off",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "8/8/8/6k1/3P4/8/8/2K2R2 w - - 0 1",
    "summary": c(
        "La tour ne défend pas le pion — elle bannit le roi adverse de toute la moitié de l'échiquier. Coupé par deux colonnes, ce roi ne reverra plus jamais la partie : le pion peut marcher seul.",
        "The rook isn't defending the pawn — it is banishing the enemy king from half the board. Cut off by two files, that king never rejoins the game: the pawn can walk home alone.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Un roi banni n'existe plus", "A banished king no longer exists")},
            "moves": [
                {"san": "d5",
                 "comment": c("La tour tient déjà la colonne f : deux colonnes entières (f et g-h derrière le roi noir) où il ne peut plus mettre un pied. Le pion avance donc SEUL — inutile d'attendre le roi blanc.",
                              "The rook already owns the f-file: two whole files (f, plus g-h behind the black king) he can never set foot on. So the pawn advances ALONE — no need to wait for the white king."),
                 "critical": True},
                {"san": "Kg4",
                 "comment": c("Le roi noir se rapproche… de rien du tout. La coupure n'est pas une question de distance mais de MUR : deux colonnes de tour, infranchissables.",
                              "The black king edges closer… to nothing at all. The cut-off isn't about distance but about a WALL: two rook-files, impassable.")},
                "d6", "Kg3", "d7",
                {"san": "Kg2",
                 "comment": c("Le roi noir arrive enfin près du mur — bien trop tard, et de toute façon incapable de le traverser.",
                              "The black king finally reaches the wall — far too late, and unable to cross it regardless.")},
                {"san": "Rf7",
                 "comment": c("La tour libère la colonne f — elle n'en a plus besoin, le pion est à un pas de la dame et le roi noir, banni depuis le premier coup, ne peut toujours rien y faire.",
                              "The rook gives up the f-file — no longer needed, the pawn is one step from queening and the black king, banished since move one, still can't do a thing about it."),
                 "critical": True},
                "Kg1", "d8=Q", "Kh1",
                {"san": "Rg7",
                 "comment": c("La tour referme le filet — plus une case pour le roi noir.",
                              "The rook closes the net — not a square left for the black king.")},
                "Kh2",
                {"san": "Qh8#",
                 "comment": c("Mat. Le roi noir n'a jamais participé à la partie après le premier coup : c'est tout le sens d'une coupure de deux colonnes.",
                              "Mate. The black king never took part in the game after move one: that is the entire meaning of a two-file cut-off."),
                 "critical": True},
            ],
        },
    ],
}
