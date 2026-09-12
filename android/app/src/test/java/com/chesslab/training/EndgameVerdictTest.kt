package com.chesslab.training

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'arbitrage de l'entraînement libre.
 *
 * Ce qui est vérifié ici est la RÈGLE, pas le moteur : « ce coup préserve-t-il
 * le verdict ? » et non « est-ce le meilleur coup ? ». C'est toute la
 * différence avec le mode guidé, et c'est une fonction pure.
 */
class EndgameVerdictTest {

    @Test fun `le seuil est celui d'iOS`() {
        assertEquals(EndgameVerdict.draw, EndgameVerdictRule.verdict(249))
        assertEquals(EndgameVerdict.win, EndgameVerdictRule.verdict(250))
        assertEquals(EndgameVerdict.draw, EndgameVerdictRule.verdict(-249))
        assertEquals(EndgameVerdict.loss, EndgameVerdictRule.verdict(-250))
        assertEquals(EndgameVerdict.draw, EndgameVerdictRule.verdict(0))
    }

    @Test fun `un verdict se retourne quand on change de camp`() {
        assertEquals(EndgameVerdict.loss, EndgameVerdict.win.flipped)
        assertEquals(EndgameVerdict.win, EndgameVerdict.loss.flipped)
        assertEquals(EndgameVerdict.draw, EndgameVerdict.draw.flipped)
    }

    @Test fun `lâcher le gain est une chute, le garder ne l'est pas`() {
        assertTrue(EndgameVerdictRule.isDegradation(EndgameVerdict.win, EndgameVerdict.draw))
        assertTrue(EndgameVerdictRule.isDegradation(EndgameVerdict.win, EndgameVerdict.loss))
        assertTrue(EndgameVerdictRule.isDegradation(EndgameVerdict.draw, EndgameVerdict.loss))

        assertFalse(EndgameVerdictRule.isDegradation(EndgameVerdict.win, EndgameVerdict.win))
        assertFalse(EndgameVerdictRule.isDegradation(EndgameVerdict.draw, EndgameVerdict.draw))
    }

    @Test fun `on ne reproche pas de faire MIEUX que le verdict de départ`() {
        // Défendre une position perdue et arracher la nulle n'est pas une
        // faute : c'est un exploit. Le mode ne doit pas le refuser.
        assertFalse(EndgameVerdictRule.isDegradation(EndgameVerdict.loss, EndgameVerdict.draw))
        assertFalse(EndgameVerdictRule.isDegradation(EndgameVerdict.draw, EndgameVerdict.win))
    }

    @Test fun `tout coup qui garde le gain est accepté, pas seulement le plus rapide`() {
        // La promesse du mode : on n'exige pas LE coup de la leçon. Deux coups
        // qui gardent le gain sont tous deux acceptés, quelle que soit leur
        // valeur exacte au-delà du seuil.
        listOf(300, 900, 5000).forEach { cp ->
            val obtenu = EndgameVerdictRule.verdict(cp)
            assertFalse(
                "un coup à $cp centipions ne devrait pas être refusé",
                EndgameVerdictRule.isDegradation(EndgameVerdict.win, obtenu),
            )
        }
    }
}
