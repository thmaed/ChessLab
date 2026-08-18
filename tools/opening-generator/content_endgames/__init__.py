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
from . import active_king, bishop_pair_mate, bishop_vs_knight_fortress, bishop_vs_knight_zugzwang, bahr_rule_flaw, bishop_vs_two_pawns, breakthrough, centurini_wrong_color, cochrane_defence, connected_passers_sixth_rank, connected_passers_vs_rook, corresponding_squares, domination, frontal_defence, grigoriev_king_race, horwitz_kling_flaw, karstedt_fortress, kingside_majority, knight_and_pawn, knight_two_wings, knight_vs_two_pawns, lucena, opposition, outside_passed_pawn, philidor, protected_passer, queen_mate, queen_vs_bishop_pawn, queen_vs_pawn, queen_vs_rook, queen_vs_rook_and_bishop, queen_vs_rook_and_knight, queen_vs_rook_pawn, queen_vs_rook_pawn_fortress, queen_vs_two_rooks, reti_study, right_capture, rook_and_pawn_vs_knight, rook_mate, rook_cutoff_tempo, rook_pawn_draw, rook_pawn_vs_rook_cutoff, rook_two_connected_pawns, rook_vs_bishop, rook_vs_bishop_safe_corner, rook_vs_knight, rook_vs_pawn, rook_vs_rook_and_bishop, rook_vs_rook_and_knight, rook_wrong_pawn_vs_bishop, saavedra, second_rank_defence, same_color_bishops, short_side_defence, square_rule, stalemate_resource, trebuchet, triangulation, two_knights_vs_pawn, two_weaknesses, vancura, vertical_cutoff, wrong_bishop

COURSES = [
    opposition.COURSE,
    bahr_rule_flaw.COURSE,
    outside_passed_pawn.COURSE,
    corresponding_squares.COURSE,
    grigoriev_king_race.COURSE,
    square_rule.COURSE,
    rook_pawn_draw.COURSE,
    rook_pawn_vs_rook_cutoff.COURSE,
    rook_two_connected_pawns.COURSE,
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
    second_rank_defence.COURSE,
    trebuchet.COURSE,
    short_side_defence.COURSE,
    frontal_defence.COURSE,
    queen_vs_rook.COURSE,
    queen_vs_rook_and_bishop.COURSE,
    queen_vs_rook_and_knight.COURSE,
    karstedt_fortress.COURSE,
    horwitz_kling_flaw.COURSE,
    queen_vs_rook_pawn.COURSE,
    queen_vs_rook_pawn_fortress.COURSE,
    queen_vs_two_rooks.COURSE,
    wrong_bishop.COURSE,
    vertical_cutoff.COURSE,
    triangulation.COURSE,
    knight_and_pawn.COURSE,
    connected_passers_vs_rook.COURSE,
    connected_passers_sixth_rank.COURSE,
    right_capture.COURSE,
    two_knights_vs_pawn.COURSE,
    protected_passer.COURSE,
    kingside_majority.COURSE,
    rook_vs_bishop.COURSE,
    rook_vs_bishop_safe_corner.COURSE,
    rook_cutoff_tempo.COURSE,
    rook_vs_knight.COURSE,
    knight_vs_two_pawns.COURSE,
    knight_two_wings.COURSE,
    rook_wrong_pawn_vs_bishop.COURSE,
    rook_and_pawn_vs_knight.COURSE,
    rook_vs_rook_and_bishop.COURSE,
    cochrane_defence.COURSE,
    rook_vs_rook_and_knight.COURSE,
    same_color_bishops.COURSE,
    centurini_wrong_color.COURSE,
    bishop_vs_two_pawns.COURSE,
    bishop_vs_knight_fortress.COURSE,
    bishop_vs_knight_zugzwang.COURSE,
    two_weaknesses.COURSE,
    domination.COURSE,
    stalemate_resource.COURSE,
    active_king.COURSE,
    bishop_pair_mate.COURSE,
]
