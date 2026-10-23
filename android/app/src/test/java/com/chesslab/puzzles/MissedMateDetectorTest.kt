package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Les règles pures de la recherche des mats manqués. Pendant de `MissedMateDetectorTests`. */
class MissedMateDetectorTest {

    /** Mat en deux du couloir, tours doublées : 1.Te8+ Txe8 2.Txe8#. */
    private val doubledRooks = "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    @Test fun `garde la ligne entière jusqu'au mat`() {
        assertEquals(
            listOf("e3e8", "a8e8", "e1e8"),
            MissedMateDetector.solution(listOf("e3e8", "a8e8", "e1e8"), doubledRooks),
        )
    }

    @Test fun `coupe au mat quand la variante du moteur continue`() {
        assertEquals(
            listOf("a1a8"),
            MissedMateDetector.solution(listOf("a1a8", "g8h8", "a8b8"), "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1"),
        )
    }

    @Test fun `refuse une ligne qui ne mate pas`() {
        assertNull(MissedMateDetector.solution(listOf("e3e7", "a8a1"), doubledRooks))
    }

    @Test fun `refuse une ligne illégale`() {
        assertNull(MissedMateDetector.solution(listOf("e3e9"), doubledRooks))
        assertNull(MissedMateDetector.solution(listOf("a8a1"), doubledRooks))
    }

    @Test fun `refuse une ligne jouée par le mauvais camp`() {
        assertNull(MissedMateDetector.solution(listOf("a1a8"), "6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1"))
    }

    @Test fun `refuse un mat au-delà de la limite`() {
        val shuffle = listOf("e3e4", "a8a7", "e4e3", "a7a8", "e3e4", "a8a7", "e4e3", "a7a8", "e3e8", "a8e8", "e1e8")
        assertNull(MissedMateDetector.solution(shuffle, doubledRooks))
    }

    @Test fun `seules les positions décisives sont cherchées`() {
        assertTrue(MissedMateDetector.mightHoldMate(99.9))
        assertTrue(MissedMateDetector.mightHoldMate(97.0))
        assertFalse(MissedMateDetector.mightHoldMate(90.0))
    }

    @Test fun `lit le numéro du coup dans la FEN`() {
        assertEquals(23, MissedMateDetector.moveNumber(doubledRooks))
        assertEquals(1, MissedMateDetector.moveNumber("8/8/8/8"))
    }
}
