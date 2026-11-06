package com.chesslab.scanner

import chesskit.Piece
import com.chesslab.vision.SquareReading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pendant de `BoardConsistencyTests` (iOS), section recroisement : le second avis doute tout haut, ne réécrit jamais. */
class ScanCrossCheckTest {

    private fun emptyGrid() = Array(8) { Array(8) { SquareReading(null, null, 1.0) } }

    private fun piece(color: Piece.Color, kind: Piece.Kind, confidence: Double = 0.9) = SquareReading(kind, color, confidence)

    @Test fun agreementKeepsConfidence() {
        val yolo = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.knight) }
        val templates = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.knight) }
        assertTrue(ScanReading(yolo).crossChecked(ScanReading(templates)).grid[5][2].isConfident)
    }

    @Test fun aConfidentDisagreementIsFlaggedButOccupancyKept() {
        val yolo = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.knight) }
        val templates = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.bishop) }
        val out = ScanReading(yolo).crossChecked(ScanReading(templates)).grid[5][2]
        assertEquals("le verdict du détecteur est conservé", Piece.Kind.knight, out.piece)
        assertFalse("mais la divergence est signalée", out.isConfident)
        assertEquals(ScanReading.CROSS_CHECK_CONFIDENCE, out.confidence, 0.0)
    }

    @Test fun anUnsureSecondaryStaysSilent() {
        val yolo = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.knight) }
        val templates = emptyGrid().also { it[5][2] = piece(Piece.Color.white, Piece.Kind.bishop, 0.3) }
        assertTrue(ScanReading(yolo).crossChecked(ScanReading(templates)).grid[5][2].isConfident)
    }

    /** Le pire défaut d'un détecteur d'objets : une pièce MANQUÉE, rendue « vide, sûre ». */
    @Test fun aConfidentSecondaryPieceVetoesADetectorEmpty() {
        val templates = emptyGrid().also { it[2][6] = piece(Piece.Color.black, Piece.Kind.queen) }
        val out = ScanReading(emptyGrid()).crossChecked(ScanReading(templates)).grid[2][6]
        assertFalse("la case vide « sûre » du détecteur est mise en doute", out.isConfident)
        assertTrue("et reste vide : on ne réécrit pas", out.isEmpty)
    }

    @Test fun anEmptySquareReadWithLowConfidenceIsFlagged() {
        val grid = emptyGrid().also { it[0][0] = SquareReading(null, null, 0.3) }
        assertFalse(ScanReading(grid).lowConfidenceSquares(ScanRotation.none).isEmpty())
    }
}
