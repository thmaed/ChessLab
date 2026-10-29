package com.chesslab.review

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** La règle de l'invitation à laisser un avis. Pendant de `ReviewPromptTests` (iOS). */
class ReviewPromptPolicyTest {
    private val now = 1_800_000_000_000L
    private val day = 24L * 60 * 60 * 1000
    private val ready = ReviewPromptPolicy(positiveMoments = 2, trainingDays = 3)

    @Test fun `invite une fois les seuils atteints`() {
        assertTrue(ready.shouldAsk("2.1", now))
    }

    @Test fun `attend assez de réussites et de jours`() {
        assertFalse(ready.copy(positiveMoments = 1).shouldAsk("2.1", now))
        assertFalse(ready.copy(trainingDays = 2).shouldAsk("2.1", now))
    }

    @Test fun `jamais deux fois pour la même version`() {
        assertFalse(ready.copy(lastAskedVersion = "2.1", lastAskedAt = now - 400 * day).shouldAsk("2.1", now))
    }

    @Test fun `une nouvelle version attend encore cent vingt jours`() {
        assertFalse(ready.copy(lastAskedVersion = "2.0", lastAskedAt = now - 30 * day).shouldAsk("2.1", now))
        assertTrue(ready.copy(lastAskedVersion = "2.0", lastAskedAt = now - 121 * day).shouldAsk("2.1", now))
    }
}
