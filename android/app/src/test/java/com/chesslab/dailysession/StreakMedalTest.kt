package com.chesslab.dailysession

import com.chesslab.puzzles.CycleComparison
import com.chesslab.puzzles.WoodpeckerPlan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pendant de `StreakMedalTests` (iOS). */
class StreakMedalTest {

    @Test fun paliersEtMedaille() {
        assertNull(StreakMedal.earned(2))
        assertEquals(StreakMedal.bronze, StreakMedal.earned(3))
        assertEquals(StreakMedal.silver, StreakMedal.earned(29))
        assertEquals(StreakMedal.gold, StreakMedal.earned(30))
        assertEquals(StreakMedal.diamond, StreakMedal.earned(400))
        assertEquals(StreakMedal.gold, StreakMedal.next(7))
        assertNull(StreakMedal.next(365))
        assertTrue(StreakMedal.isMilestone(100))
        assertFalse(StreakMedal.isMilestone(8))
    }

    private fun cycle(solved: Int, seconds: Double) = WoodpeckerPlan.Cycle(
        number = 1, order = (0 until 10).toList(),
        attempts = (0 until 10).map { WoodpeckerPlan.Attempt(it < solved, seconds / 10) },
        startedAt = 0L,
    )

    @Test fun comparaisonDeCycles() {
        val c = CycleComparison.of(cycle(8, 200.0), cycle(9, 100.0))
        assertTrue(c.isProgress)
        assertEquals(1.0, c.previousTime, 1e-9)
        assertEquals(0.5, c.currentTime, 1e-3)
        assertEquals(100.0, c.secondsSaved, 1e-9)
        assertFalse(CycleComparison.of(cycle(9, 100.0), cycle(7, 80.0)).isProgress)
    }
}
