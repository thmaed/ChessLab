package com.chesslab.training

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * Vérifie les INVARIANTS de la planification, pas des valeurs en dur (qui
 * seraient fragiles) : monotonie des intervalles selon la note, croissance de
 * la stabilité au rappel, échec = rechute, propriétés de la courbe d'oubli.
 * Ce sont ces garanties qui protègent la mémorisation.
 *
 * Porté de `FSRSTests.swift`.
 */
class FsrsTest {
    private val fsrs = Fsrs()
    private val now = 1_700_000_000_000L
    private fun days(n: Double) = (n * Fsrs.DAY_MS).toLong()

    @Test fun `le premier intervalle croît avec la note`() {
        val again = fsrs.review(FsrsCard.new, FsrsRating.again, now)
        val hard = fsrs.review(FsrsCard.new, FsrsRating.hard, now)
        val good = fsrs.review(FsrsCard.new, FsrsRating.good, now)
        val easy = fsrs.review(FsrsCard.new, FsrsRating.easy, now)
        assertTrue(again.scheduledDays <= hard.scheduledDays)
        assertTrue(hard.scheduledDays <= good.scheduledDays)
        assertTrue(good.scheduledDays < easy.scheduledDays)
    }

    @Test fun `l'état d'une carte neuve suit la note`() {
        assertEquals(FsrsState.learning, fsrs.review(FsrsCard.new, FsrsRating.again, now).card.state)
        assertEquals(FsrsState.review, fsrs.review(FsrsCard.new, FsrsRating.good, now).card.state)
        assertEquals(1, fsrs.review(FsrsCard.new, FsrsRating.good, now).card.reps)
    }

    @Test fun `un rappel réussi augmente la stabilité`() {
        val first = fsrs.review(FsrsCard.new, FsrsRating.good, now).card
        val later = now + days(3.0)
        val second = fsrs.review(first, FsrsRating.good, later)
        assertTrue(second.card.stability > first.stability)
        assertEquals(2, second.card.reps)
        assertTrue((second.card.due ?: 0) > later)
    }

    @Test fun `un échec compte comme rechute`() {
        val card = fsrs.review(FsrsCard.new, FsrsRating.good, now).card
        val lapse = fsrs.review(card, FsrsRating.again, now + days(3.0))
        assertEquals(card.lapses + 1, lapse.card.lapses)
        assertEquals(FsrsState.relearning, lapse.card.state)
    }

    @Test fun `la rétrievabilité vaut 1 à la révision et 0,9 à la stabilité`() {
        val card = fsrs.review(FsrsCard.new, FsrsRating.good, now).card
        assertTrue(abs(fsrs.retrievability(card, now) - 1.0) < 1e-9)
        val atStability = now + days(card.stability)
        assertTrue(abs(fsrs.retrievability(card, atStability) - 0.9) < 1e-4)
        val farLater = now + days(card.stability * 5)
        assertTrue(fsrs.retrievability(card, farLater) < fsrs.retrievability(card, atStability))
    }

    @Test fun `une carte neuve n'a pas de rétrievabilité`() {
        assertEquals(0.0, fsrs.retrievability(FsrsCard.new, now), 0.0)
    }

    @Test fun `l'intervalle ne descend jamais sous un jour ni au-delà du plafond`() {
        assertEquals(1, fsrs.intervalDays(0.0001))
        assertEquals(36_500, fsrs.intervalDays(1e12))
    }

    @Test fun `la difficulté reste bornée même après cent échecs`() {
        var card = FsrsCard.new
        var t = now
        repeat(100) {
            card = fsrs.review(card, FsrsRating.again, t).card
            t += days(1.5)
            assertTrue("difficulté hors bornes : ${card.difficulty}", card.difficulty in 1.0..10.0)
            assertTrue("stabilité non finie", card.stability.isFinite() && card.stability > 0)
        }
    }

    @Test fun `cent réussites d'affilée ne débordent pas`() {
        var card = FsrsCard.new
        var t = now
        repeat(100) {
            card = fsrs.review(card, FsrsRating.easy, t).card
            t = card.due ?: (t + days(1.0))
            assertTrue(card.stability.isFinite())
            assertTrue(fsrs.intervalDays(card.stability) <= 36_500)
        }
    }
}
