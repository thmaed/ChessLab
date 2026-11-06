package com.chesslab.vision

import chesskit.Piece
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Portage des cas de `YOLOBoardClassifierTests.swift` : la projection des
 * boîtes sur la grille, la seule partie du scanner qui peut casser en silence.
 */
class BoardReaderTest {

    /** Une boîte centrée sur la case (ligne, colonne), de la taille d'une case. */
    private fun box(row: Int, column: Int, kind: Piece.Kind, color: Piece.Color, confidence: Double = 0.9): Detection {
        val cell = 1.0 / 8
        return Detection(
            color, kind, confidence,
            left = column * cell, top = row * cell,
            right = (column + 1) * cell, bottom = (row + 1) * cell,
        )
    }

    @Test fun eachPieceLandsOnItsOwnSquare() {
        val grid = BoardReader.grid(listOf(
            box(0, 0, Piece.Kind.rook, Piece.Color.black),
            box(0, 4, Piece.Kind.king, Piece.Color.black),
            box(6, 4, Piece.Kind.pawn, Piece.Color.white),
        ))
        assertEquals(Piece.Kind.rook, grid[0][0].piece)
        assertEquals(Piece.Color.black, grid[0][0].color)
        assertEquals(Piece.Kind.king, grid[0][4].piece)
        assertEquals(Piece.Kind.pawn, grid[6][4].piece)
        assertTrue(grid[4][4].isEmpty)
    }

    @Test fun aTallPieceIsAssignedByItsBaseNotItsTop() {
        // une dame dont la boîte déborde d'une demi-case vers le HAUT
        val cell = 1.0 / 8
        val tall = Detection(
            Piece.Color.white, Piece.Kind.queen, 0.9,
            left = 3 * cell, top = 3 * cell - cell / 2,
            right = 4 * cell, bottom = 4 * cell,
        )
        val grid = BoardReader.grid(listOf(tall))
        assertEquals(Piece.Kind.queen, grid[3][3].piece, "d5 : ligne 3, colonne 3")
        assertTrue(grid[2][3].isEmpty, "la case au-dessus reste vide")
    }

    @Test fun twoDetectionsOnOneSquareKeepTheMoreConfident() {
        val grid = BoardReader.grid(listOf(
            box(5, 2, Piece.Kind.bishop, Piece.Color.white, confidence = 0.4),
            box(5, 2, Piece.Kind.knight, Piece.Color.white, confidence = 0.95),
        ))
        assertEquals(Piece.Kind.knight, grid[5][2].piece)
        assertEquals(0.95, grid[5][2].confidence)
    }

    /** Le détecteur lit ses pièces justes à 0,95 et plus : 0,80 est douteux. */
    @Test fun aPieceBelowTheDetectorsDoubtLineIsFlagged() {
        val grid = BoardReader.grid(listOf(
            box(0, 0, Piece.Kind.rook, Piece.Color.white, confidence = 0.80),
            box(0, 1, Piece.Kind.rook, Piece.Color.white, confidence = 0.90),
        ))
        assertTrue(grid[0][0].confidence < 0.55, "0,80 est sous la ligne de doute du détecteur")
        assertTrue(grid[0][1].confidence >= 0.55, "0,90 est au-dessus : aucune fausse alerte")
    }

    @Test fun doubtCalibrationNeverReordersConfidences() {
        val samples = (30..99).map { BoardReader.calibrated(it / 100.0) }
        assertTrue(samples.zipWithNext().all { (a, b) -> a <= b }, "la calibration reste croissante")
        assertEquals(0.95, BoardReader.calibrated(0.95))
    }

    @Test fun emptySquaresAreAConfidentAbsence() {
        val grid = BoardReader.grid(emptyList())
        assertTrue(grid.all { row -> row.all { it.isEmpty } })
        assertEquals(BoardReader.EMPTY_CONFIDENCE, grid[0][0].confidence)
    }

    @Test fun theStartingPositionRoundTripsToItsFen() {
        val back = listOf(
            Piece.Kind.rook, Piece.Kind.knight, Piece.Kind.bishop, Piece.Kind.queen,
            Piece.Kind.king, Piece.Kind.bishop, Piece.Kind.knight, Piece.Kind.rook,
        )
        val detections = buildList {
            back.forEachIndexed { column, kind -> add(box(0, column, kind, Piece.Color.black)) }
            for (column in 0 until 8) add(box(1, column, Piece.Kind.pawn, Piece.Color.black))
            for (column in 0 until 8) add(box(6, column, Piece.Kind.pawn, Piece.Color.white))
            back.forEachIndexed { column, kind -> add(box(7, column, kind, Piece.Color.white)) }
        }
        assertEquals(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR",
            BoardReader.placement(BoardReader.grid(detections)),
        )
    }

    // --- Deuxième hypothèse (pendant de ScanReviewTests, iOS) ---

    @Test fun theDetectorsOtherClassesBecomeAlternatives() {
        val alt = listOf(PieceChoice(Piece.Color.white, Piece.Kind.bishop))
        val d = box(2, 2, Piece.Kind.knight, Piece.Color.white, 0.6).copy(alternatives = alt)
        assertEquals(alt, BoardReader.grid(listOf(d))[2][2].alternatives)
    }

    @Test fun aLosingDetectionOnTheSameSquareIsTheFirstAlternative() {
        val winner = box(2, 2, Piece.Kind.knight, Piece.Color.white, 0.9)
        val loser = box(2, 2, Piece.Kind.bishop, Piece.Color.white, 0.5)
        val reading = BoardReader.grid(listOf(winner, loser))[2][2]
        assertEquals(Piece.Kind.knight, reading.piece)
        assertEquals(listOf(PieceChoice(Piece.Color.white, Piece.Kind.bishop)), reading.alternatives)
    }

    @Test fun theMainPieceIsNeverItsOwnAlternative() {
        val a = box(2, 2, Piece.Kind.knight, Piece.Color.white, 0.9)
        val b = box(2, 2, Piece.Kind.knight, Piece.Color.white, 0.5)
        assertTrue(BoardReader.grid(listOf(a, b))[2][2].alternatives.isEmpty())
    }
}
