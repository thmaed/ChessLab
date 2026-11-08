package com.chesslab.lab

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** L'abandon et la nulle par accord, au point de vue des Blancs. Pendant des seuils d'iOS. */
class AgreedOutcomeTest {
    private fun of(evals: List<Int>, plies: Int = 80, resign: Boolean = true, draw: Boolean = true) =
        AgreedOutcome.of(evals, plies, resign, draw)

    @Test fun `les Blancs menent de huit pions pendant six demi-coups, ils gagnent`() {
        assertEquals("1-0", of(List(6) { 900 }))
    }

    @Test fun `les Noirs menent, 0-1 quel que soit le camp au trait`() {
        assertEquals("0-1", of(List(6) { -900 }))
    }

    @Test fun `un seul demi-coup en dessous du seuil suffit a continuer`() {
        assertNull(of(listOf(900, 900, 900, 700, 900, 900)))
    }

    @Test fun `des scores de signe alternant (point de vue du camp au trait) ne declenchent rien`() {
        // Le défaut de la revue : une partie gagnée par les Blancs vue du camp au trait alterne +900 / −900.
        assertNull(of(listOf(900, -900, 900, -900, 900, -900)))
    }

    @Test fun `la nulle par accord demande soixante demi-coups et dix scores a zero`() {
        assertEquals("1/2-1/2", of(List(10) { 5 }, plies = 60))
        assertNull(of(List(10) { 5 }, plies = 59))
        assertNull(of(List(9) { 5 }, plies = 80))
        assertNull(of(List(10) { 40 }, plies = 80))
    }

    @Test fun `les reglages desactives gardent la partie ouverte`() {
        assertNull(of(List(6) { 900 }, resign = false))
        assertNull(of(List(10) { 0 }, draw = false))
    }
}
