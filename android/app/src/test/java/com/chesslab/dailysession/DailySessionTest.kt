package com.chesslab.dailysession

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/** A5 — la série de jours et le plan de la séance. Pendant de `DailySessionTests.swift`. */
class DailySessionTest {

    private val paris = ZoneId.of("Europe/Paris")

    private fun at(day: Int, month: Int = 10, hour: Int = 12): Long =
        LocalDate.of(2026, month, day).atTime(hour, 0).atZone(paris).toInstant().toEpochMilli()

    private fun days(vararg numbers: Int): Set<String> = numbers.map { TrainingStreak.key(at(it), paris) }.toSet()

    @Test fun `jours consecutifs jusqu'a aujourd'hui`() {
        assertEquals(5, TrainingStreak.current(days(20, 21, 22, 23, 24), at(24), paris))
        assertEquals(1, TrainingStreak.current(days(22, 24), at(24), paris))
    }

    @Test fun `une serie vit jusqu'a la fin de la journee`() {
        assertEquals(3, TrainingStreak.current(days(21, 22, 23), at(24), paris))
        assertEquals(0, TrainingStreak.current(days(21, 22, 23), at(25), paris))
        assertEquals(0, TrainingStreak.current(emptySet(), at(24), paris))
    }

    @Test fun `la serie traverse les fins de mois`() {
        val set = setOf(TrainingStreak.key(at(31, 10), paris), TrainingStreak.key(at(1, 11), paris))
        assertEquals(2, TrainingStreak.current(set, at(1, 11), paris))
    }

    @Test fun `le plan ordonne les etapes et compte ce qui reste`() {
        val plan = DailySessionBuilder.plan(12, 0, 2, "eg-lucena", false, 4, false)
        assertEquals(
            listOf(
                DailySessionStep.Kind.openings, DailySessionStep.Kind.missedPuzzles,
                DailySessionStep.Kind.ownPuzzles, DailySessionStep.Kind.endgame,
            ),
            plan.steps.map { it.kind },
        )
        assertEquals(
            listOf(DailySessionStep.Kind.openings, DailySessionStep.Kind.ownPuzzles, DailySessionStep.Kind.endgame),
            plan.pending.map { it.kind },
        )
        assertEquals("eg-lucena", plan.steps.last().courseId)
        assertFalse(plan.isComplete)
        assertEquals(4, plan.streak)
    }

    @Test fun `une seance reste courte`() {
        fun remaining(cap: Int) = DailySessionBuilder.plan(80, 28, 7, null, false, 0, false, openingsCap = cap).steps.map { it.remaining }
        assertEquals(listOf(5, 5, 5), DailySessionBuilder.plan(80, 28, 7, null, false, 0, false).steps.map { it.remaining })
        assertEquals(listOf(2, 5, 5), remaining(2))
        assertEquals(listOf(8, 5, 5), remaining(8))
    }

    @Test fun `tout est fait quand il n'y a plus rien a revoir et que la finale est ouverte`() {
        assertTrue(DailySessionBuilder.plan(0, 0, 0, "eg-lucena", true, 1, true).isComplete)
        val none = DailySessionBuilder.plan(0, 0, 0, null, false, 0, false)
        assertEquals(3, none.steps.size)
        assertTrue(none.isComplete)
    }

    @Test fun `la finale du jour tourne une par jour`() {
        val ids = listOf("a", "b", "c")
        val picks = (24..27).map { DailySessionBuilder.endgameCourseId(ids, at(it), paris) }
        assertEquals(setOf("a", "b", "c"), picks.take(3).toSet())
        assertEquals(picks[0], picks[3])
        assertEquals(
            DailySessionBuilder.endgameCourseId(ids, at(24, hour = 1), paris),
            DailySessionBuilder.endgameCourseId(ids, at(24, hour = 23), paris),
        )
        assertNull(DailySessionBuilder.endgameCourseId(emptyList(), at(24), paris))
    }

    @Test fun `le plafond atteint l'etape des ouvertures est faite meme s'il reste des positions dues`() {
        fun remaining(done: Int, due: Int) =
            DailySessionBuilder.plan(due, 0, 0, null, false, 0, false, openingsCap = 5, openingsDoneToday = done).steps.first().remaining
        assertEquals(5, remaining(0, 12))
        assertEquals(2, remaining(3, 12))
        assertEquals(0, remaining(5, 12))
        assertEquals(1, remaining(2, 1))
    }

    // Un cycle Woodpecker en cours (suggestion d'Olivier, 2.1). Pendant des tests de `DailySessionTests.swift`.

    private fun planWith(woodpecker: WoodpeckerSessionInfo?) =
        DailySessionBuilder.plan(0, 0, 0, "eg-lucena", false, 0, false, woodpecker = woodpecker)

    @Test fun `un cycle Woodpecker en cours devient une etape avant la finale`() {
        val plan = planWith(WoodpeckerSessionInfo("p1", cycle = 2, puzzlesLeft = 340, practicedToday = false))
        assertEquals(
            listOf(
                DailySessionStep.Kind.openings, DailySessionStep.Kind.missedPuzzles, DailySessionStep.Kind.ownPuzzles,
                DailySessionStep.Kind.woodpecker, DailySessionStep.Kind.endgame,
            ),
            plan.steps.map { it.kind },
        )
        val step = plan.steps.first { it.kind == DailySessionStep.Kind.woodpecker }
        assertEquals(340, step.remaining)
        assertEquals("p1", step.programId)
        assertEquals(2, step.cycleNumber)
        assertEquals(listOf(DailySessionStep.Kind.woodpecker, DailySessionStep.Kind.endgame), plan.pending.map { it.kind })
    }

    @Test fun `travailler son cycle aujourd'hui rend l'etape faite`() {
        val plan = planWith(WoodpeckerSessionInfo("p1", 1, 340, practicedToday = true))
        assertTrue(plan.steps.first { it.kind == DailySessionStep.Kind.woodpecker }.isDone)
        assertEquals(listOf(DailySessionStep.Kind.endgame), plan.pending.map { it.kind })
    }

    @Test fun `sans cycle en cours ou cycle boucle pas d'etape Woodpecker`() {
        assertFalse(planWith(null).steps.any { it.kind == DailySessionStep.Kind.woodpecker })
        assertFalse(planWith(WoodpeckerSessionInfo("p1", 3, 0, false)).steps.any { it.kind == DailySessionStep.Kind.woodpecker })
    }
}
