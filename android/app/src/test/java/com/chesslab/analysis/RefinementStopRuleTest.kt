package com.chesslab.analysis

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'arrêt anticipé d'une recherche d'affinage.
 *
 * Le critère est volontairement CONSERVATEUR : rater un arrêt possible coûte
 * quelques secondes, s'arrêter à tort coûte un verdict. Chaque test ci-dessous
 * vérifie qu'une des trois conditions manquantes suffit à refuser l'arrêt.
 */
class RefinementStopRuleTest {

    /** Trois profondeurs avec une éval stable et un verdict loin des seuils. */
    @Test fun `stable et loin des seuils, on s arrete`() {
        val rule = RefinementStopRule()
        assertFalse(rule.shouldStop(20, 2_000_000, 60.0, 10.0))
        assertFalse(rule.shouldStop(21, 2_000_000, 60.2, 10.0))
        assertTrue(rule.shouldStop(22, 2_000_000, 60.1, 10.0))
    }

    /** Sous le plancher de nœuds, on ne s'arrête sur aucune impression. */
    @Test fun `sous le plancher de noeuds, jamais`() {
        val rule = RefinementStopRule()
        rule.shouldStop(20, 900_000, 60.0, 10.0)
        rule.shouldStop(21, 900_000, 60.0, 10.0)
        assertFalse(rule.shouldStop(22, 900_000, 60.0, 10.0))
    }

    /** Une éval qui bouge encore remet le compteur à zéro. */
    @Test fun `une eval qui bouge remet le compteur a zero`() {
        val rule = RefinementStopRule()
        rule.shouldStop(20, 2_000_000, 60.0, 10.0)
        rule.shouldStop(21, 2_000_000, 60.1, 10.0)
        assertFalse(rule.shouldStop(22, 2_000_000, 65.0, 10.0))
        assertFalse(rule.shouldStop(23, 2_000_000, 65.1, 10.0))
        assertTrue(rule.shouldStop(24, 2_000_000, 65.0, 10.0))
    }

    /** Près d'une frontière, on continue : c'est là que le verdict se joue. */
    @Test fun `pres d une frontiere, on continue`() {
        val rule = RefinementStopRule()
        rule.shouldStop(20, 2_000_000, 60.0, 0.5)
        rule.shouldStop(21, 2_000_000, 60.0, 0.5)
        assertFalse(rule.shouldStop(22, 2_000_000, 60.0, 0.5))
    }

    /**
     * Une profondeur RÉPÉTÉE ne compte pas : seul un changement atteste que la
     * précédente est complète.
     */
    @Test fun `une profondeur repetee ne compte pas`() {
        val rule = RefinementStopRule()
        rule.shouldStop(20, 2_000_000, 60.0, 10.0)
        assertFalse(rule.shouldStop(20, 2_000_000, 60.0, 10.0))
        assertFalse(rule.shouldStop(20, 2_000_000, 60.0, 10.0))
        assertFalse(rule.shouldStop(21, 2_000_000, 60.0, 10.0))
        assertTrue(rule.shouldStop(22, 2_000_000, 60.0, 10.0))
    }

    /** Sans compteur de nœuds sur la ligne, pas d'arrêt. */
    @Test fun `sans noeuds annonces, jamais`() {
        val rule = RefinementStopRule()
        rule.shouldStop(20, null, 60.0, 10.0)
        rule.shouldStop(21, null, 60.0, 10.0)
        assertFalse(rule.shouldStop(22, null, 60.0, 10.0))
    }

    /**
     * Le plancher SUIT le budget : en surchauffe il tombe de moitié, comme les
     * nœuds demandés, sans quoi on ne s'arrêterait jamais avant la fin.
     */
    @Test fun `le plancher se regle`() {
        val rule = RefinementStopRule(nodesFloor = 500_000)
        rule.shouldStop(20, 600_000, 60.0, 10.0)
        rule.shouldStop(21, 600_000, 60.0, 10.0)
        assertTrue(rule.shouldStop(22, 600_000, 60.0, 10.0))
    }
}
