package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le raccourcisseur de solutions : il coupe la variante du moteur là où la
 * tactique est RÉSOLUE, pas là où le moteur a cessé de calculer.
 */
class TrimmerTest {

    @Test fun `un mat coupe la solution au mat`() {
        // Tour en e8 : mat du couloir. Rien à jouer après.
        val trimmed = PuzzleSolutionTrimmer.trim(
            pv = listOf("e1e8", "g8h7", "e8e7"),
            startFen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1",
        )
        assertEquals(listOf("e1e8"), trimmed)
    }

    @Test fun `un gain net et stable coupe juste après`() {
        // Les Blancs prennent une tour libre en d8 ; les Noirs ne reprennent
        // pas. La solution tient en un coup.
        val trimmed = PuzzleSolutionTrimmer.trim(
            pv = listOf("d1d8", "g8h7", "d8a8"),
            startFen = "3r2k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
        )
        assertEquals(listOf("d1d8"), trimmed)
    }

    @Test fun `une solution se termine toujours sur le coup du résolveur`() {
        // Une suite tranquille, sans gain décisif : on tronque au plafond, mais
        // jamais sur une riposte adverse auto-jouée.
        val trimmed = PuzzleSolutionTrimmer.trim(
            pv = listOf("g1h1", "g8h8", "h1g1", "h8g8", "g1h1", "g8h8"),
            startFen = "6k1/5ppp/8/8/8/8/5PPP/6K1 w - - 0 1",
        )
        assertTrue("longueur = ${trimmed.size}", trimmed.size % 2 == 1)
    }

    @Test fun `une variante vide ne produit rien`() {
        assertEquals(
            emptyList<String>(),
            PuzzleSolutionTrimmer.trim(emptyList(), "6k1/8/8/8/8/8/8/6K1 w - - 0 1"),
        )
    }
}
