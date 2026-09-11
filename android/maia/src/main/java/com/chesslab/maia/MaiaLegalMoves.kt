package com.chesslab.maia

import chesskit.Board
import chesskit.Piece

/**
 * Traduction Kotlin de `MaiaLegalMoves.swift`.
 *
 * Énumère les coups légaux du camp au trait et les projette dans le
 * vocabulaire de Maia. `Board.legalMoves` rend les arrivées d'une pièce sans
 * tenir compte du trait : on filtre donc par couleur. Une arrivée de pion sur
 * la dernière rangée compte pour QUATRE coups, comme dans le masque de
 * référence.
 */
object MaiaLegalMoves {
    fun moves(board: Board): List<MaiaMove> {
        val position = board.position
        val mover = position.sideToMove
        val mirror = mover == Piece.Color.black
        val lastRank = if (mover == Piece.Color.white) 8 else 1
        val result = mutableListOf<MaiaMove>()

        for (piece in position.pieces) {
            if (piece.color != mover) continue
            for (target in board.legalMoves(forPieceAt = piece.square)) {
                val prefix = piece.square.notation + target.notation
                if (piece.kind == Piece.Kind.pawn && target.rank.value == lastRank) {
                    for (kind in MaiaMoveTable.promotionKinds) {
                        val index = MaiaMoveTable.index(piece.square, target, kind, mirror) ?: continue
                        result += MaiaMove(prefix + MaiaMoveTable.promotionLetter(kind), index)
                    }
                } else {
                    val index = MaiaMoveTable.index(piece.square, target, null, mirror) ?: continue
                    result += MaiaMove(prefix, index)
                }
            }
        }
        return result
    }
}
