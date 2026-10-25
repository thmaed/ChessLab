package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.pow
import kotlin.random.Random

/** La cote de puzzle personnelle. Pendant de `PuzzleRatingTests` (iOS). */
class PuzzleRatingTest {

    @Test fun `on part de 1500 avec une grande incertitude`() {
        val r = PuzzleRating()
        assertEquals(1500, r.displayed)
        assertEquals(350.0, r.deviation, 0.0)
        assertTrue(!r.isSettled)
    }

    @Test fun `réussir un puzzle plus dur monte davantage la cote`() {
        val hard = PuzzleRating().record(true, 1900)
        val easy = PuzzleRating().record(true, 1100)
        assertTrue(hard.rating > easy.rating)
        assertTrue(easy.rating > 1500)
    }

    @Test fun `rater baisse la cote`() {
        assertTrue(PuzzleRating().record(false, 1500).rating < 1500)
    }

    @Test fun `l'incertitude diminue mais jamais sous le plancher`() {
        var r = PuzzleRating()
        repeat(300) { r = r.record(true, 1500) }
        assertTrue(r.deviation < 350)
        assertTrue(r.deviation >= PuzzleRating.MIN_DEVIATION)
        assertTrue(r.isSettled)
    }

    @Test fun `converge vers le niveau où l'on réussit la moitié`() {
        var r = PuzzleRating()
        val random = Random(3)
        repeat(600) {
            val puzzle = random.nextInt(1300, 2101)
            val p = 1 / (1 + 10.0.pow((puzzle - 1700) / 400.0))
            r = r.record(random.nextDouble() < p, puzzle)
        }
        assertTrue("cote obtenue : ${r.rating}", abs(r.rating - 1700) < 120)
    }

    @Test fun `la fenêtre suit la cote et s'élargit avec l'incertitude`() {
        var r = PuzzleRating()
        val wide = r.window
        repeat(200) { r = r.record(true, 1500) }
        val narrow = r.window
        assertTrue(wide.count() > narrow.count())
        assertTrue(r.displayed in narrow)
        assertTrue(narrow.count() >= 199)
    }

    @Test fun `le filtre À mon niveau exclut les puzzles maison, qui n'ont pas de cote`() {
        val filter = PuzzleFilter(ratingWindow = 1400..1600)
        val own = Puzzle("o", "8/8/8/8/8/8/8/K6k w - - 0 1", listOf("a1a2"), "tactic", 0, null)
        val library = own.copy(id = "l", rating = 1500)
        assertTrue(!PuzzleAnswer.accepts(own, filter, isOwn = true))
        assertTrue(PuzzleAnswer.accepts(library, filter, isOwn = false))
        assertTrue(!PuzzleAnswer.accepts(library.copy(rating = 1800), filter, isOwn = false))
        assertTrue(!filter.isEmpty)
    }

    @Test fun `reussi avec indice la cote ne monte jamais et perd quelques points`() {
        val settled = PuzzleRating(rating = 1500.0, deviation = 60.0, count = 40)
        val plain = settled.record(solved = true, puzzleRating = 1500)
        val hinted = settled.record(solved = true, puzzleRating = 1500, usedHint = true)
        val failed = settled.record(solved = false, puzzleRating = 1500)
        assertTrue(plain.rating > 1500)
        assertTrue(hinted.rating < 1500)
        assertTrue(hinted.rating > failed.rating)
        assertTrue(1500 - hinted.rating < 6)
        assertTrue(settled.record(solved = true, puzzleRating = 2100, usedHint = true).rating <= 1500.0001)
    }
}
