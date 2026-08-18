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
from . import breakthrough, connected_passers_vs_rook, kingside_majority, knight_and_pawn, lucena, opposition, philidor, protected_passer, queen_mate, queen_vs_bishop_pawn, queen_vs_pawn, queen_vs_rook, reti_study, rook_mate, rook_pawn_draw, rook_vs_pawn, saavedra, short_side_defence, square_rule, trebuchet, triangulation, vancura, vertical_cutoff, wrong_bishop

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
    vancura.COURSE,
    saavedra.COURSE,
    trebuchet.COURSE,
    short_side_defence.COURSE,
    queen_vs_rook.COURSE,
    wrong_bishop.COURSE,
    vertical_cutoff.COURSE,
    triangulation.COURSE,
    knight_and_pawn.COURSE,
    connected_passers_vs_rook.COURSE,
    protected_passer.COURSE,
    kingside_majority.COURSE,
]
