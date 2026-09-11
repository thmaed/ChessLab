package com.chesslab.maia

import chesskit.Piece
import chesskit.Position

/**
 * Traduction Kotlin de `MaiaEncoder.swift`.
 *
 * Transforme les dernières positions d'une partie en tenseur `64 × 97`, une
 * ligne par case. Réplique de `tokenize_board()` et `get_historical_tokens()`
 * du dépôt `CSSLab/maia3` :
 *
 *  - **Une position = 12 plans par case** : pion, cavalier, fou, tour, dame,
 *    roi du camp AU TRAIT (plans 0-5), puis les mêmes pour l'adversaire
 *    (6-11). Ni roque ni prise en passant : le modèle les infère de
 *    l'historique.
 *  - **Le plateau est retourné quand les Noirs jouent**, position par
 *    position : dans l'historique, les orientations alternent donc d'un
 *    demi-coup à l'autre. C'est le code de référence, pas une simplification.
 *  - **Historique de 8 positions**, de la plus ancienne aux colonnes 0-11 à la
 *    courante aux colonnes 84-95 ; s'il en manque, la plus ancienne connue est
 *    répétée en tête. La 97e colonne (temps de réflexion) reste à zéro.
 */
object MaiaEncoder {
    const val HISTORY_LENGTH = 8
    const val PLANES_PER_POSITION = 12
    const val FEATURES_PER_SQUARE = HISTORY_LENGTH * PLANES_PER_POSITION + 1   // 97
    const val SQUARE_COUNT = 64

    /** Le numéro de plan d'une pièce, dans le repère du camp au trait. */
    fun plane(piece: Piece, sideToMove: Piece.Color): Int {
        val kindOffset = when (piece.kind) {
            Piece.Kind.pawn -> 0
            Piece.Kind.knight -> 1
            Piece.Kind.bishop -> 2
            Piece.Kind.rook -> 3
            Piece.Kind.queen -> 4
            Piece.Kind.king -> 5
        }
        return kindOffset + if (piece.color == sideToMove) 0 else 6
    }

    /** Les 64 × 12 bits d'UNE position, un masque de 12 bits par case. */
    fun planes(position: Position): IntArray {
        val squares = IntArray(SQUARE_COUNT)
        val mirror = position.sideToMove == Piece.Color.black
        for (piece in position.pieces) {
            val square = if (mirror) MaiaMoveTable.mirrored(piece.square) else piece.square
            squares[MaiaMoveTable.squareIndex(square)] =
                squares[MaiaMoveTable.squareIndex(square)] or (1 shl plane(piece, position.sideToMove))
        }
        return squares
    }

    /**
     * Le tenseur d'entrée `64 × 97`, ligne par ligne.
     *
     * [history] va de la plus ancienne position à la COURANTE (dernier
     * élément = position à jouer). Seules les huit dernières comptent ; une
     * liste vide rend un tenseur nul.
     */
    fun tokens(history: List<Position>): FloatArray {
        val tensor = FloatArray(SQUARE_COUNT * FEATURES_PER_SQUARE)
        if (history.isEmpty()) return tensor

        val recent = history.takeLast(HISTORY_LENGTH)
        val padding = HISTORY_LENGTH - recent.size
        val planesByPosition = recent.map { planes(it) }

        for (slot in 0 until HISTORY_LENGTH) {
            // les fentes manquantes en tête répètent la plus ancienne connue
            val source = if (slot < padding) planesByPosition[0] else planesByPosition[slot - padding]
            val columnBase = slot * PLANES_PER_POSITION
            for (square in 0 until SQUARE_COUNT) {
                val mask = source[square]
                if (mask == 0) continue
                val rowBase = square * FEATURES_PER_SQUARE + columnBase
                for (plane in 0 until PLANES_PER_POSITION) {
                    if (mask and (1 shl plane) != 0) tensor[rowBase + plane] = 1f
                }
            }
        }
        return tensor
    }
}
