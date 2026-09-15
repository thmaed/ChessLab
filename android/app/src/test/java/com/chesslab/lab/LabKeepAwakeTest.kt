package com.chesslab.lab

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Deux réglages du laboratoire qui se DÉDUISENT plutôt que de se cocher, et
 * qui se trompaient en silence : la mise en veille, et l'avertissement sur un
 * temps de réflexion trop court.
 */
class LabKeepAwakeTest {

    /**
     * Au-delà d'une vingtaine de parties, l'appareil s'endormirait à coup sûr
     * avant la fin. En deçà, on ne prend pas la main sur un réglage système
     * que personne n'a demandé.
     */
    @Test fun `la veille suit la longueur tant qu'on n'y a pas touche`() {
        assertEquals(false, LabUiState(gameCount = 20).keepAwake)
        assertEquals(true, LabUiState(gameCount = 21).keepAwake)
    }

    /** Mais un choix explicite TIENT, même si la longueur change ensuite. */
    @Test fun `un choix explicite tient malgre la longueur`() {
        assertEquals(false, LabUiState(gameCount = 200, keepAwakeSetting = false).keepAwake)
        assertEquals(true, LabUiState(gameCount = 2, keepAwakeSetting = true).keepAwake)
    }

    /**
     * Le temps court bride surtout le camp FORT : l'écart mesuré serait plus
     * petit que l'écart affiché, et l'on conclurait de travers.
     */
    @Test fun `un camp fort et peu de temps declenchent l'avertissement`() {
        val state = LabUiState(
            sideA = LabSide(null, 2900.0), sideB = LabSide(null, 1500.0), movetimeMs = 200,
        )
        assertTrue(state.shortTimeWarning)
    }

    @Test fun `avec du temps il n'y a rien a avertir`() {
        val state = LabUiState(
            sideA = LabSide(null, 2900.0), sideB = LabSide(null, 1500.0), movetimeMs = 1_500,
        )
        assertEquals(false, state.shortTimeWarning)
    }

    /** Deux camps modestes ne sont pas bridés par le temps : rien à dire. */
    @Test fun `deux camps modestes ne declenchent rien`() {
        val state = LabUiState(
            sideA = LabSide(null, 1600.0), sideB = LabSide(null, 1500.0), movetimeMs = 100,
        )
        assertEquals(false, state.shortTimeWarning)
    }
}
