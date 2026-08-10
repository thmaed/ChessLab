# -*- coding: utf-8 -*-
"""Gambit Englund (1.d4 e5) — répertoire NOIR (piège)."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "englund-gambit",
    "name": "Englund Gambit",
    "side": "black",
    "level": "club",
    "eco": ["A40"],
    "summary": c(
        "Un pion sacrifié dès 1…e5 contre 1.d4. Objectivement suspect, mais le piège …Db4+ / …Dxb2 a fait tomber bien des Blancs pris au dépourvu.",
        "A pawn sacrificed with 1…e5 against 1.d4. Objectively suspect, but the …Qb4+ / …Qxb2 trap has felled many an unprepared White.",
    ),
    "lines": [
        {
            "chapter": {"id": "trap", "title": c("Le piège …Db4+", "The …Qb4+ trap")},
            "moves": [
                "d4",
                {"san": "e5", "eco": "Englund Gambit",
                 "comment": c("Le gambit Englund : on ouvre le jeu au prix d'un pion, en misant sur la surprise.",
                              "The Englund Gambit: opening the game for a pawn, banking on surprise.")},
                "dxe5", "Nc6", "Nf3",
                {"san": "Qe7", "critical": True,
                 "comment": c("Le coup-clé : la dame attaque e5 et prépare le fameux …Db4+.",
                              "The key move: the queen attacks e5 and sets up the famous …Qb4+.")},
                {"san": "Bf4", "role": "inaccuracy",
                 "comment": c("Un coup naturel qui tombe dans le piège. Mieux valait Cc3 ou Da4.",
                              "A natural move that walks into the trap. Nc3 or Qd4 were better.")},
                {"san": "Qb4+", "role": "trap", "critical": True,
                 "comment": c("L'échec à double tranchant : il attaque en même temps le roi et le pion b2.",
                              "The double-purpose check: it hits the king and the b2 pawn at once.")},
                "Bd2", "Qxb2", "Bc3", "Bb4",
                {"san": "Qd2", "comment": c("Les Noirs récupèrent le matériel à coups de tactique : …Fxc3 puis …Dc1+ règlent l'affaire.",
                                            "Black regains material with tactics: …Bxc3 then …Qc1+ settle matters.")},
            ],
        },
    ],
}
