package com.chesslab.vision

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Pendant de `BoardGridFinderTests` et `BoardGridEdgeBiasTests` (iOS) : la
 * découpe ne doit PAS croire au cadrage. Les plateaux sont synthétiques — un
 * damier de luminance avec, comme sur une vraie capture, des disques de
 * « pièces » sur les rangées de départ, qui sont ce qui tire la grille de
 * côté quand le profil est mal bâti.
 */
class BoardGridFinderTest {

    /**
     * Un plateau de 800 px dont l'angle haut-gauche est en ([originX], [originY])
     * dans une toile de [canvas] px, fond [background].
     */
    private fun board(canvas: Int = 800, originX: Int = 0, originY: Int = 0, background: Double = 0.12): DoubleArray {
        val lum = DoubleArray(canvas * canvas) { background }
        for (y in 0 until canvas) for (x in 0 until canvas) {
            val bx = x - originX; val by = y - originY
            if (bx !in 0 until 800 || by !in 0 until 800) continue
            val file = bx / 100; val rank = by / 100
            var v = if ((file + rank) % 2 == 0) 0.90 else 0.45
            if (rank <= 1 || rank >= 6) {
                // Un disque de pièce au centre de la case.
                val d = hypot(bx - (file * 100 + 50.0), by - (rank * 100 + 50.0))
                if (d < 32) v = if (rank <= 1) 0.15 else 0.97
            }
            lum[y * canvas + x] = v
        }
        return lum
    }

    private fun maxDeviation(found: DoubleArray, start: Double, step: Double, range: IntRange = 0..8) =
        range.maxOf { abs(found[it] - (start + it * step)) }

    @Test fun aPerfectlyCroppedBoardKeepsItsUniformGrid() {
        val grid = BoardGridFinder.grid(board(), 800)
        assertTrue(maxDeviation(grid.columns, 0.0, 100.0) < 2.5)
        assertTrue(maxDeviation(grid.rows, 0.0, 100.0) < 2.5)
    }

    @Test fun anOversizedCropIsRealignedOnTheBoardLines() {
        val inset = 14
        val grid = BoardGridFinder.grid(board(canvas = 828, originX = inset, originY = inset), 828)
        assertTrue(maxDeviation(grid.columns, inset.toDouble(), 100.0) < 2.5, "colonnes")
        assertTrue(maxDeviation(grid.rows, inset.toDouble(), 100.0) < 2.5, "lignes")
    }

    /** Cadrage trop serré : les deux lignes extrêmes sortent de l'image ; seules les 7 intérieures comptent. */
    @Test fun aTightCropStillCutsTheInteriorLinesWithinTwoPixels() {
        val crop = 6
        val full = board()
        val side = 800 - 2 * crop
        val cropped = DoubleArray(side * side) { full[(it / side + crop) * 800 + it % side + crop] }
        val grid = BoardGridFinder.grid(cropped, side)
        assertTrue(maxDeviation(grid.columns, -crop.toDouble(), 100.0, 1..7) < 2)
        assertTrue(maxDeviation(grid.rows, -crop.toDouble(), 100.0, 1..7) < 2)
    }

    @Test fun aFlatImageFallsBackOnTheUniformGrid() {
        val flat = DoubleArray(400 * 400) { 0.5 }
        assertEquals(BoardGridFinder.Grid.uniform(400, 400), BoardGridFinder.grid(flat, 400))
    }

    @Test fun aTooSmallImageFallsBackOnTheUniformGrid() {
        val tiny = DoubleArray(32 * 32) { (it % 7) / 7.0 }
        assertEquals(BoardGridFinder.Grid.uniform(32, 32), BoardGridFinder.grid(tiny, 32))
    }

    @Test fun theMedianOfAnEvenSampleIsTheMeanOfItsTwoMiddleValues() {
        assertEquals(2.5, BoardGridFinder.median(doubleArrayOf(4.0, 1.0, 3.0, 2.0)))
        assertEquals(3.0, BoardGridFinder.median(doubleArrayOf(9.0, 3.0, 1.0)))
        assertEquals(0.0, BoardGridFinder.median(doubleArrayOf()))
    }
}
