package com.chesslab.play

import chesskit.Board
import chesskit.Move
import chesskit.Piece

/**
 * Les prises de chaque camp et le différentiel de matériel.
 *
 * Porté de `CapturedMaterial.swift`. Le DIFFÉRENTIEL se calcule sur la
 * position réelle et non sur la liste des prises : une promotion change le
 * matériel sans qu'aucune pièce ait été capturée, et compter les prises
 * donnerait alors un avantage faux.
 */
data class CapturedMaterial(
    /** Pièces noires prises par les Blancs, de la plus forte à la plus faible. */
    val byWhite: List<Piece.Kind> = emptyList(),
    val byBlack: List<Piece.Kind> = emptyList(),
    /** > 0 = avantage aux Blancs. */
    val diff: Int = 0,
) {
    fun captures(color: Piece.Color): List<Piece.Kind> =
        if (color == Piece.Color.white) byWhite else byBlack

    fun advantage(color: Piece.Color): Int = if (color == Piece.Color.white) diff else -diff

    companion object {
        fun value(kind: Piece.Kind): Int = when (kind) {
            Piece.Kind.queen -> 9
            Piece.Kind.rook -> 5
            Piece.Kind.bishop -> 3
            Piece.Kind.knight -> 3
            Piece.Kind.pawn -> 1
            Piece.Kind.king -> 0
        }

        fun from(moves: List<Move>, board: Board): CapturedMaterial {
            val white = ArrayList<Piece.Kind>()
            val black = ArrayList<Piece.Kind>()
            for (move in moves) {
                val result = move.result
                if (result is Move.Result.Capture) {
                    if (result.piece.color == Piece.Color.black) white += result.piece.kind
                    else black += result.piece.kind
                }
            }
            val byValue = compareByDescending<Piece.Kind> { value(it) }
            var whiteValue = 0
            var blackValue = 0
            for (piece in board.position.pieces) {
                if (piece.color == Piece.Color.white) whiteValue += value(piece.kind)
                else blackValue += value(piece.kind)
            }
            return CapturedMaterial(
                white.sortedWith(byValue), black.sortedWith(byValue), whiteValue - blackValue,
            )
        }
    }
}
