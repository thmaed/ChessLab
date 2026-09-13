package com.chesslab.scanner

import chesskit.Piece
import chesskit.Square
import com.chesslab.vision.BoardReader
import com.chesslab.vision.SquareReading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La lecture d'un scan, sans image : rotation, FEN, cases douteuses,
 * orientation devinée. Ce sont les règles de `BoardScanReading`, reprises.
 */
class ScanReadingTest {

    /** Une grille depuis un placement FEN, ligne 0 en haut, confiance donnée aux pièces. */
    private fun grid(placement: String, confidence: Double = 0.9): Array<Array<SquareReading>> {
        val rows = placement.split("/")
        require(rows.size == 8)
        return Array(8) { r ->
            val cells = ArrayList<SquareReading>()
            for (c in rows[r]) {
                if (c.isDigit()) repeat(c - '0') { cells += SquareReading(null, null, BoardReader.EMPTY_CONFIDENCE) }
                else cells += SquareReading(kind(c), if (c.isUpperCase()) Piece.Color.white else Piece.Color.black, confidence)
            }
            require(cells.size == 8)
            cells.toTypedArray()
        }
    }

    private fun kind(c: Char) = when (c.lowercaseChar()) {
        'p' -> Piece.Kind.pawn; 'n' -> Piece.Kind.knight; 'b' -> Piece.Kind.bishop
        'r' -> Piece.Kind.rook; 'q' -> Piece.Kind.queen; else -> Piece.Kind.king
    }

    private val standard = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"

    @Test fun `un demi-tour envoie le coin haut-gauche en bas a droite`() {
        val g = grid("k7/8/8/8/8/8/8/7K")
        val turned = ScanReading.rotated180(g)
        assertEquals(Piece.Kind.king, turned[7][7].piece)
        assertEquals(Piece.Color.black, turned[7][7].color)
        assertEquals(Piece.Color.white, turned[0][0].color)
    }

    @Test fun `la FEN de la position de depart, roques deduits`() {
        val reading = ScanReading(grid(standard))
        assertEquals("$standard w KQkq - 0 1", reading.fen(ScanRotation.none, Piece.Color.white))
        assertEquals("$standard b KQkq - 0 1", reading.fen(ScanRotation.none, Piece.Color.black))
    }

    @Test fun `les roques ne sont jamais inventes`() {
        // Roi blanc sorti de e1 : plus aucun droit blanc, les noirs gardent les leurs.
        val reading = ScanReading(grid("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR"))
        assertTrue(reading.fen(ScanRotation.none, Piece.Color.white).contains(" kq "))
    }

    @Test fun `une case douteuse est signalee, une case vide jamais`() {
        val g = grid("8/8/8/8/8/8/8/8")
        g[0][0] = SquareReading(Piece.Kind.rook, Piece.Color.black, 0.3)
        g[7][7] = SquareReading(Piece.Kind.king, Piece.Color.white, 0.95)
        val low = ScanReading(g).lowConfidenceSquares(ScanRotation.none)
        assertEquals(setOf(Square("a8")), low)
    }

    @Test fun `l'orientation devinee est celle qui donne une position legale`() {
        // Le diagramme est à l'envers : les Blancs en haut. Lus tels quels,
        // les pions sont sur la 1re et la 8e rangée — impossible.
        val upsideDown = "RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr"
        val reading = ScanReading(grid(upsideDown))
        assertEquals(ScanRotation.half, reading.suggestedRotation())
        assertEquals("$standard w KQkq - 0 1", reading.fen(ScanRotation.half, Piece.Color.white))
        assertEquals(ScanRotation.none, ScanReading(grid(standard)).suggestedRotation())
    }

    @Test fun `sans orientation legale, les pions departagent`() {
        // Deux rois seuls, et un pion blanc : à l'endroit il est sur la 2e
        // rangée (bon signe), à l'envers sur la 7e. Aucune des deux n'est
        // illégale, la plus plausible l'emporte.
        val reading = ScanReading(grid("4k3/8/8/8/8/8/P7/4K3"))
        assertEquals(ScanRotation.none, reading.suggestedRotation())
    }

    @Test fun `le compte des pieces ignore les cases vides`() {
        assertEquals(32, ScanReading(grid(standard)).pieceCount)
        assertFalse(SquareReading(null, null, BoardReader.EMPTY_CONFIDENCE).let { !it.isConfident })
    }
}
