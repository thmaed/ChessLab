# -*- coding: utf-8 -*-
"""Les cours de FINALES rédigés à la main — pendant de `content/`.

Même contrat que les ouvertures (COURSE par module, lignes SAN annotées),
plus trois champs : `kind: "endgame"`, `family` (pawns|rooks|queens|minor|
mates|practical) et `rootFEN` (position de départ arbitraire).

Discipline d'écriture, gravée après l'épisode de la Teichmann : CHAQUE ligne
est dérivée sous l'oracle (`verify_line.py`) avant d'entrer ici, et
`audit_endgames.py` prouve ensuite que chaque coup enseigné préserve son
verdict théorique. Une ligne de finale écrite de mémoire est une ligne fausse
qui n'a pas encore été vérifiée.
"""
from . import breakthrough, lucena, opposition, philidor, queen_mate, queen_vs_bishop_pawn, queen_vs_pawn, reti_study, rook_mate, rook_pawn_draw, rook_vs_pawn, square_rule

COURSES = [
    opposition.COURSE,
    square_rule.COURSE,
    rook_pawn_draw.COURSE,
    lucena.COURSE,
    philidor.COURSE,
    rook_vs_pawn.COURSE,
    queen_vs_pawn.COURSE,
    queen_vs_bishop_pawn.COURSE,
    rook_mate.COURSE,
    queen_mate.COURSE,
    breakthrough.COURSE,
    reti_study.COURSE,
]
