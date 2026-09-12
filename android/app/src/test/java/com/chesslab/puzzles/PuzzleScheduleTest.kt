package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le calendrier de révision des puzzles, à la SM-2.
 *
 * Pourquoi SM-2 ici et FSRS pour les ouvertures : ce n'est pas une
 * incohérence, c'est le choix d'iOS. Une position d'ouverture se révise des
 * dizaines de fois et FSRS tire parti de cet historique ; un puzzle se résout
 * une fois, et le revoir sert à vérifier qu'on n'a pas oublié le motif.
 */
class PuzzleScheduleTest {

    private val neuf = PuzzleProgress(externalId = "p1")

    @Test fun `les trois premières réussites suivent 1 puis 6 puis l'espacement`() {
        val un = PuzzleSchedule.next(neuf, success = true)
        assertEquals(1, un.intervalDays)
        assertEquals(1, un.repetitions)

        val deux = PuzzleSchedule.next(un, success = true)
        assertEquals(6, deux.intervalDays)

        val trois = PuzzleSchedule.next(deux, success = true)
        assertTrue("le troisième intervalle doit dépasser six jours : ${trois.intervalDays}", trois.intervalDays > 6)
    }

    @Test fun `un échec ramène à demain et remet le compteur à zéro`() {
        var p = neuf
        repeat(4) { p = PuzzleSchedule.next(p, success = true) }
        assertTrue("l'intervalle devrait être long : ${p.intervalDays}", p.intervalDays > 6)

        val rate = PuzzleSchedule.next(p, success = false)
        assertEquals(1, rate.intervalDays)
        assertEquals(0, rate.repetitions)
        assertEquals(1, rate.failureCount)
    }

    @Test fun `la facilité ne descend jamais sous le plancher`() {
        var p = neuf
        repeat(30) { p = PuzzleSchedule.next(p, success = false) }
        assertTrue("plancher franchi : ${p.easinessFactor}", p.easinessFactor >= 1.3)
    }

    @Test fun `la facilité monte avec les réussites`() {
        val un = PuzzleSchedule.next(neuf, success = true)
        assertTrue("la réussite devrait faciliter : ${un.easinessFactor}", un.easinessFactor > neuf.easinessFactor)
    }

    @Test fun `les compteurs distinguent réussites et échecs`() {
        var p = neuf
        p = PuzzleSchedule.next(p, success = true)
        p = PuzzleSchedule.next(p, success = false)
        p = PuzzleSchedule.next(p, success = true)
        assertEquals(2, p.successCount)
        assertEquals(1, p.failureCount)
    }

    @Test fun `la date de révision suit l'intervalle`() {
        val un = PuzzleSchedule.next(neuf, success = true)
        val now = 1_700_000_000_000L
        assertEquals(now + PuzzleSchedule.DAY_MS, PuzzleSchedule.dueAt(un, now))
    }
}

/** Les paliers de difficulté couvrent toute l'échelle, sans trou ni chevauchement. */
class DifficultyTierTest {

    @Test fun `chaque cote tombe dans un palier et un seul`() {
        listOf(0, 800, 1199, 1200, 1599, 1600, 1999, 2000, 3500).forEach { cote ->
            val paliers = DifficultyTier.entries.filter { cote in it.range }
            assertEquals("cote $cote → $paliers", 1, paliers.size)
        }
    }

    @Test fun `les bornes sont celles d'iOS`() {
        assertEquals(DifficultyTier.beginner, DifficultyTier.forRating(1199))
        assertEquals(DifficultyTier.intermediate, DifficultyTier.forRating(1200))
        assertEquals(DifficultyTier.advanced, DifficultyTier.forRating(1600))
        assertEquals(DifficultyTier.expert, DifficultyTier.forRating(2000))
    }

    @Test fun `un filtre vide ne filtre rien`() {
        assertTrue(PuzzleFilter().isEmpty)
        assertEquals(0..4000, PuzzleFilter().ratings)
        assertTrue(!PuzzleFilter(phase = GamePhase.endgame).isEmpty)
    }
}
