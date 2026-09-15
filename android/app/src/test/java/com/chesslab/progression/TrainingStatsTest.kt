package com.chesslab.progression

import com.chesslab.training.FsrsRating
import com.chesslab.training.FsrsState
import com.chesslab.training.OpeningProgress
import com.chesslab.training.OpeningReviewLog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le bilan de la MÉMORISATION : ce qui est vu, acquis, à raffermir, dû.
 *
 * Le calcul est séparé de la lecture en base, donc vérifiable sur des valeurs
 * écrites à la main — c'est ce qu'on veut d'un chiffre qui sert à décider quoi
 * travailler. Les mêmes cas que `TrainingStatsTests.swift`.
 */
class TrainingStatsTest {

    private val now = 1_700_000_000_000L
    private val day = 86_400_000L

    private fun record(
        reps: Int, stability: Double, lapses: Int = 0,
        state: FsrsState = FsrsState.review, due: Long? = null,
    ) = OpeningProgress(
        fenKey = "k-$reps-$stability-$lapses-$state-$due",
        stability = stability, stateRaw = state.raw, reps = reps, lapses = lapses,
        dueAt = due?.let { now + it },
    )

    private fun log(rating: FsrsRating, daysAgo: Long) = OpeningReviewLog(
        fenKey = "k", ratingRaw = rating.raw, reviewedAt = now - daysAgo * day,
        elapsedDays = 0.0, scheduledDays = 0.0, stabilityAfter = 1.0,
    )

    @Test fun `une position jamais revisee ne compte pas comme vue`() {
        val stats = TrainingStats.compute(
            listOf(record(reps = 0, stability = 0.0, state = FsrsState.new)), emptyList(), now,
        )
        assertEquals(0, stats.studied)
        assertTrue(stats.isEmpty)
    }

    @Test fun `acquise au-dela d une semaine de stabilite`() {
        val stats = TrainingStats.compute(
            listOf(record(3, 8.0), record(2, 6.0)), emptyList(), now,
        )
        assertEquals(2, stats.studied)
        assertEquals(1, stats.solid)
    }

    @Test fun `difficile deja oubliee ou encore en apprentissage`() {
        val stats = TrainingStats.compute(
            listOf(
                record(4, 20.0, lapses = 1),
                record(1, 1.0, state = FsrsState.learning),
                record(5, 30.0),
            ),
            emptyList(), now,
        )
        assertEquals(2, stats.hard)
    }

    @Test fun `est due ce dont l echeance est passee`() {
        val stats = TrainingStats.compute(
            listOf(record(2, 3.0, due = -day), record(2, 3.0, due = day)), emptyList(), now,
        )
        assertEquals(1, stats.due)
    }

    @Test fun `la retention ne regarde que les trente derniers jours`() {
        val stats = TrainingStats.compute(
            emptyList(),
            listOf(
                log(FsrsRating.good, 1),
                log(FsrsRating.again, 2),
                log(FsrsRating.again, 60),   // hors fenêtre
            ),
            now,
        )
        assertEquals(0.5, stats.retention!!, 1e-9)
        assertEquals("50 %", stats.retentionLabel)
    }

    @Test fun `sans revision recente pas de taux invente`() {
        val stats = TrainingStats.compute(emptyList(), emptyList(), now)
        assertNull(stats.retention)
        assertEquals("—", stats.retentionLabel)
    }

    @Test fun `les revisions de la semaine se comptent sur sept jours`() {
        val stats = TrainingStats.compute(
            emptyList(), listOf(log(FsrsRating.good, 2), log(FsrsRating.good, 10)), now,
        )
        assertEquals(1, stats.reviewsThisWeek)
    }

    @Test fun `la prochaine echeance est la plus proche a venir`() {
        val stats = TrainingStats.compute(
            listOf(record(1, 1.0, due = 5 * day), record(1, 1.0, due = 3 * day)), emptyList(), now,
        )
        assertEquals(now + 3 * day, stats.nextDueAt)
    }
}
