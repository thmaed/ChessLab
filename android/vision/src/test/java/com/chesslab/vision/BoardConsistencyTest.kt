package com.chesslab.vision

import chesskit.Piece
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Pendant de `BoardConsistencyTests` (iOS) : les lectures impossibles aux échecs sont signalées, jamais corrigées. */
class BoardConsistencyTest {

    private fun emptyGrid() = Array(8) { Array(8) { SquareReading(null, null, 1.0) } }

    private fun piece(color: Piece.Color, kind: Piece.Kind, confidence: Double = 0.9) = SquareReading(kind, color, confidence)

    private fun Array<Array<SquareReading>>.put(row: Int, column: Int, reading: SquareReading) { this[row][column] = reading }

    /** Deux rois, chacun sa couleur, des pions sur leur rangée : rien à redire. */
    @Test fun aLegalPositionFlagsNothing() {
        val grid = emptyGrid()
        grid.put(0, 4, piece(Piece.Color.black, Piece.Kind.king))
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        grid.put(1, 0, piece(Piece.Color.black, Piece.Kind.pawn))
        grid.put(6, 0, piece(Piece.Color.white, Piece.Kind.pawn))
        assertTrue(BoardConsistency.suspectCells(grid).isEmpty())
    }

    @Test fun aPawnOnTheBackRankIsFlagged() {
        val grid = emptyGrid()
        grid.put(0, 4, piece(Piece.Color.black, Piece.Kind.king))
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        grid.put(0, 0, piece(Piece.Color.white, Piece.Kind.pawn))
        grid.put(7, 3, piece(Piece.Color.black, Piece.Kind.pawn))
        val suspects = BoardConsistency.suspectCells(grid)
        assertTrue(BoardConsistency.Cell(0, 0) in suspects)
        assertTrue(BoardConsistency.Cell(7, 3) in suspects)
    }

    @Test fun duplicateKingsAreBothFlagged() {
        val grid = emptyGrid()
        grid.put(0, 4, piece(Piece.Color.black, Piece.Kind.king))
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        grid.put(7, 6, piece(Piece.Color.white, Piece.Kind.king))
        val suspects = BoardConsistency.suspectCells(grid)
        assertTrue(BoardConsistency.Cell(7, 4) in suspects)
        assertTrue(BoardConsistency.Cell(7, 6) in suspects)
    }

    @Test fun aMissingKingFlagsTheSameColorQueens() {
        val grid = emptyGrid()
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        grid.put(0, 3, piece(Piece.Color.black, Piece.Kind.queen))
        assertTrue(BoardConsistency.Cell(0, 3) in BoardConsistency.suspectCells(grid))
    }

    @Test fun moreThanEightPawnsFlagsTheLeastConfident() {
        val grid = emptyGrid()
        grid.put(0, 4, piece(Piece.Color.black, Piece.Kind.king))
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        // 9 pions blancs : la confiance baisse à mesure qu'on les pose.
        val cells = listOf(6 to 0, 6 to 1, 6 to 2, 6 to 3, 6 to 4, 6 to 5, 6 to 6, 6 to 7, 5 to 0)
        cells.forEachIndexed { i, (r, c) -> grid.put(r, c, piece(Piece.Color.white, Piece.Kind.pawn, 0.99 - i * 0.01)) }
        val suspects = BoardConsistency.suspectCells(grid)
        assertTrue(BoardConsistency.Cell(5, 0) in suspects, "9e posé, confiance la plus basse")
        assertFalse(BoardConsistency.Cell(6, 0) in suspects, "1er posé, confiance la plus haute")
    }

    @Test fun reconciledLowersConfidenceButKeepsOccupancy() {
        val grid = emptyGrid()
        grid.put(7, 4, piece(Piece.Color.white, Piece.Kind.king))
        grid.put(0, 4, piece(Piece.Color.black, Piece.Kind.king))
        grid.put(0, 0, piece(Piece.Color.white, Piece.Kind.pawn, 0.95))
        val out = BoardConsistency.reconciled(grid)
        assertEquals(Piece.Kind.pawn, out[0][0].piece, "l'occupation est conservée")
        assertEquals(Piece.Color.white, out[0][0].color)
        assertEquals(BoardConsistency.VIOLATION_CONFIDENCE, out[0][0].confidence, "mais la case est désormais signalée")
        assertEquals(0.95, out[7][4].confidence.coerceAtLeast(0.0).let { if (out[7][4].piece != null) 0.95 else it })
    }
}
