package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** « Contre la montre » (17/11/2026). Pendant de `PuzzleRushRunTests` et des tests de tirage (iOS). */
class PuzzleRushTest {
    private val t0 = 1_000_000L

    @Test fun `on part 400 points sous la cote, jamais sous 600`() {
        assertEquals(1100, PuzzleRushRun.forPlayer(1500.0).startRating)
        assertEquals(600, PuzzleRushRun.forPlayer(800.0).startRating)
    }

    @Test fun `chaque réussite monte la cible, une erreur non`() {
        val run = PuzzleRushRun.forPlayer(1500.0)
            .recordSolved(1120).recordSolved(1190).recordError().recordSolved(1150)
        assertEquals(1100 + 3 * PuzzleRushRun.RATING_STEP, run.targetRating)
        assertEquals(1190, run.highestSolvedRating)
    }

    @Test fun `le temps s'arrête pendant la pause`() {
        var run = PuzzleRushRun.forPlayer(1500.0, durationMs = 180_000).start(t0)
        assertEquals(120_000, run.remainingMs(t0 + 60_000))
        run = run.pause(t0 + 60_000)
        assertEquals(120_000, run.remainingMs(t0 + 500_000))
        run = run.start(t0 + 500_000)
        assertEquals(90_000, run.remainingMs(t0 + 530_000))
        assertFalse(run.isOver(t0 + 530_000))
        assertTrue(run.isOver(t0 + 620_000))
        assertEquals(0, run.remainingMs(t0 + 9_999_999))
    }

    @Test fun `trois erreurs finissent la série`() {
        var run = PuzzleRushRun.forPlayer(1500.0).start(t0)
        run = run.recordError().recordError()
        assertFalse(run.isOver(t0))
        run = run.recordError().recordError()
        assertEquals(PuzzleRushRun.MAX_ERRORS, run.errors)
        assertTrue(run.isOver(t0))
    }

    private fun puzzle(id: String, rating: Int, plies: Int = 1, setup: String? = null) =
        Puzzle(id, "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1", List(plies) { "a1a8" }, "checkmate", rating, null, setup = setup)

    @Test fun `seuls les puzzles courts sans préparation entrent dans une série`() {
        assertTrue(PuzzleRushPool.isPlayable(puzzle("a", 1200, plies = 3)))
        assertFalse(PuzzleRushPool.isPlayable(puzzle("b", 1200, plies = 5)))
        assertFalse(PuzzleRushPool.isPlayable(puzzle("c", 1200, setup = "e2e4")))
    }

    @Test fun `le tirage vise la cible, ne ressert jamais, et s'élargit`() {
        val pool = PuzzleRushPool(listOf(puzzle("near", 2000), puzzle("far", 2350), puzzle("other", 1200)))
        assertEquals("near", pool.next(2000, emptySet(), Random(1))?.id)
        assertEquals("far", pool.next(2000, setOf("near"), Random(1))?.id)
        assertEquals("other", pool.next(2000, setOf("near", "far"), Random(1))?.id)
        assertNull(pool.next(2000, setOf("near", "far", "other"), Random(1)))
    }

    @Test fun `la solution se lit en coups numérotés`() {
        val p = Puzzle("x", "r5k1/1bp2pp1/p3p2p/1p2q3/4B3/2P5/PPQ2PPP/4R1K1 w - - 0 19",
            listOf("e4h7", "g8f8", "e1e5"), "tactic", 900, null)
        val sans = PuzzleRushSolution.sans(p)
        assertEquals(listOf("Bh7+", "Kf8", "Rxe5"), sans)
        assertEquals("19. Bh7+ Kf8 20. Rxe5", PuzzleRushSolution.numbered(p.fen, sans))
    }

    @Test fun `le chrono s'affiche en minutes et secondes`() {
        assertEquals("3:00", clock(180_000))
        assertEquals("0:06", clock(5_200))
        assertEquals("0:00", clock(0))
    }
}
