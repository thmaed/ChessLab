package com.chesslab.variants

import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.math.abs

/**
 * La notation d'un coup de Duck Chess. Pendant de `DuckChessSAN.swift`.
 *
 * Proche du SAN ordinaire, à une différence près, et c'est elle qui dit la
 * variante : ni « + » ni « # », puisqu'il n'y a ni échec ni mat — le canard
 * peut boucher la seule case qui sauvait le roi, et la partie se gagne en
 * PRENANT le roi. Cette prise-là se marque « ++ », convention lisible pour le
 * coup qui termine la partie.
 */
object DuckChessSan {

    fun build(
        move: DuckChessRules.Move,
        position: Position,
        legalMoves: List<DuckChessRules.Move>,
        capturesKing: Boolean,
    ): String {
        val piece = position.piece(move.from) ?: return move.uci
        val suffix = if (capturesKing) "++" else ""

        if (piece.kind == Piece.Kind.king && abs(move.to.file.number - move.from.file.number) == 2) {
            return (if (move.to.file.number > move.from.file.number) "O-O" else "O-O-O") + suffix
        }

        val occupied = position.piece(move.to) != null
        val enPassant = piece.kind == Piece.Kind.pawn && move.from.file != move.to.file && !occupied
        val capture = occupied || enPassant

        val body = StringBuilder()
        if (piece.kind == Piece.Kind.pawn) {
            if (capture) body.append(move.from.file.letter).append("x")
            body.append(move.to.notation)
            move.promotion?.let { body.append("=").append(it.notation) }
        } else {
            body.append(piece.kind.notation)
            body.append(disambiguation(piece, move, legalMoves, position))
            if (capture) body.append("x")
            body.append(move.to.notation)
        }
        return body.toString() + suffix
    }

    private fun disambiguation(
        piece: Piece,
        move: DuckChessRules.Move,
        legalMoves: List<DuckChessRules.Move>,
        position: Position,
    ): String {
        val others = legalMoves.mapNotNull { candidate ->
            if (candidate.from == move.from || candidate.to != move.to) return@mapNotNull null
            val other = position.piece(candidate.from) ?: return@mapNotNull null
            if (other.kind != piece.kind || other.color != piece.color) return@mapNotNull null
            candidate.from
        }
        if (others.isEmpty()) return ""
        if (others.none { it.file == move.from.file }) return move.from.file.letter
        if (others.none { it.rank == move.from.rank }) return move.from.rank.value.toString()
        return move.from.notation
    }
}
