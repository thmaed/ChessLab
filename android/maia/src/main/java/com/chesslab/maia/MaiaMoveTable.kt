package com.chesslab.maia

import chesskit.Piece
import chesskit.Square

/**
 * Un coup dans le repère de Maia : celui du CAMP AU TRAIT, plateau retourné
 * quand les Noirs jouent. [uci] est le coup RÉEL, tel que le plateau
 * l'attend ; [index] sa case dans le vecteur de 4 352 logits du modèle.
 */
data class MaiaMove(val uci: String, val index: Int)

/**
 * Traduction Kotlin de `MaiaMoveTable.swift`.
 *
 * Vocabulaire de sortie de Maia-3 : 4 096 paires de cases (origine × arrivée,
 * numérotées rangée par rangée depuis a1) suivies de 256 promotions (colonne
 * d'origine × colonne d'arrivée × dame/tour/fou/cavalier), toujours de la 7e
 * vers la 8e rangée puisque le plateau est retourné pour les Noirs.
 *
 * Réplique de `get_all_possible_moves()` et `mirror_move()` du dépôt
 * `CSSLab/maia3`.
 */
object MaiaMoveTable {
    const val PAIR_COUNT = 64 * 64
    const val PROMOTION_COUNT = 8 * 8 * 4
    const val VOCABULARY_SIZE = PAIR_COUNT + PROMOTION_COUNT

    /** L'ordre des promotions dans le vocabulaire. */
    val promotionKinds = listOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight)

    /** Numéro 0..63 d'une case, rangée par rangée depuis a1 — le repère de python-chess. */
    fun squareIndex(square: Square): Int = (square.rank.value - 1) * 8 + (square.file.number - 1)

    /** La case vue depuis l'autre camp : même colonne, rangée renversée. */
    fun mirrored(square: Square): Square = Square(square.file, Square.Rank(9 - square.rank.value))

    /**
     * L'indice du coup `from → to` dans le repère du camp au trait. [mirror]
     * vaut vrai quand les Noirs jouent : le coup est d'abord renversé, comme
     * le plateau l'a été.
     *
     * `null` pour une promotion qui ne part pas de la 7e vers la 8e rangée
     * après renversement — impossible pour un coup légal, gardé par sécurité.
     */
    fun index(from: Square, to: Square, promotion: Piece.Kind?, mirror: Boolean): Int? {
        val start = if (mirror) mirrored(from) else from
        val end = if (mirror) mirrored(to) else to

        if (promotion != null) {
            if (start.rank.value != 7 || end.rank.value != 8) return null
            val kindIndex = promotionKinds.indexOf(promotion)
            if (kindIndex < 0) return null
            return PAIR_COUNT + ((start.file.number - 1) * 8 + (end.file.number - 1)) * 4 + kindIndex
        }
        return squareIndex(start) * 64 + squareIndex(end)
    }

    fun promotionLetter(kind: Piece.Kind): String = when (kind) {
        Piece.Kind.queen -> "q"
        Piece.Kind.rook -> "r"
        Piece.Kind.bishop -> "b"
        Piece.Kind.knight -> "n"
        else -> ""
    }
}
