package com.chesslab.engine

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Le bridage thermique : ce qu'on rabote, et de combien.
 *
 * Le TEMPS et les NŒUDS sont deux budgets distincts à dessein — appliquer une
 * réduction de temps à une recherche bornée en nœuds ferait se combattre les
 * deux limites, et la première atteinte gagnerait au hasard de la charge.
 */
class ThermalMonitorTest {

    @After fun cool() = ThermalMonitor.forceForTesting(false)

    @Test fun `au froid rien n est rabote`() {
        ThermalMonitor.forceForTesting(false)
        assertEquals(1_000, ThermalMonitor.movetimeMs(1_000))
        assertEquals(300_000L, ThermalMonitor.nodes(300_000))
        assertEquals(4, ThermalMonitor.threads(4))
        assertEquals(22, ThermalMonitor.liveDepth(22))
    }

    @Test fun `en surchauffe le temps et les noeuds tombent de moitie`() {
        ThermalMonitor.forceForTesting(true)
        assertEquals(500, ThermalMonitor.movetimeMs(1_000))
        assertEquals(150_000L, ThermalMonitor.nodes(300_000))
    }

    @Test fun `en surchauffe le moteur ne garde qu un fil`() {
        ThermalMonitor.forceForTesting(true)
        assertEquals(1, ThermalMonitor.threads(4))
    }

    /** Seize plis suffisent à des flèches justes, et ne coûtent pas la moitié. */
    @Test fun `la profondeur en continu est plafonnee et jamais rehaussee`() {
        ThermalMonitor.forceForTesting(true)
        assertEquals(16, ThermalMonitor.liveDepth(22))
        assertEquals(12, ThermalMonitor.liveDepth(12))
    }

    /** Un budget minuscule ne doit jamais tomber à zéro : `go movetime 0` ne cherche rien. */
    @Test fun `un budget minuscule reste jouable`() {
        ThermalMonitor.forceForTesting(true)
        assertEquals(1, ThermalMonitor.movetimeMs(1))
        assertEquals(1L, ThermalMonitor.nodes(1))
    }
}
