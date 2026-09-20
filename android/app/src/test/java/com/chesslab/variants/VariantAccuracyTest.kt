package com.chesslab.variants

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La précision par camp de l'analyse des variantes.
 *
 * Trois choses à tenir, et ce sont les trois que le portage pouvait rater :
 * le POINT DE VUE (une perte se juge pour celui qui vient de jouer, pas pour
 * les Blancs), le fait qu'un camp ne paie QUE ses propres coups, et le refus
 * de publier un chiffre quand la passe d'évaluation a un trou — un décalage
 * d'un demi-coup attribuerait chaque faute à l'adversaire.
 */
class VariantAccuracyTest {

    /** Une partie plate : personne ne perd rien, donc personne n'est pris en faute. */
    @Test
    fun `sans perte, les deux camps sont proches de la perfection`() {
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { 50.0 },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNotNull(result.white)
        assertNotNull(result.black)
        assertTrue("Blancs ${result.white}", result.white!! > 95)
        assertTrue("Noirs ${result.black}", result.black!! > 95)
    }

    /**
     * Une seule gaffe, et elle est NOIRE : le deuxième demi-coup fait tomber
     * la probabilité des Noirs de 50 à 10. Seuls les Noirs doivent payer.
     */
    @Test
    fun `la gaffe est portée au camp qui l'a jouée`() {
        // ply 0 : Blancs jouent (50 → 50). ply 1 : Noirs jouent (50 → 90 POV
        // Blancs, soit 50 → 10 de leur point de vue). Puis plus rien ne bouge.
        val percents = listOf(50.0, 50.0, 90.0, 90.0, 90.0, 90.0, 90.0)
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { percents.getOrNull(it) },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNotNull(result.white)
        assertNotNull(result.black)
        assertTrue("Blancs ${result.white}", result.white!! > 95)
        assertTrue("Noirs ${result.black}", result.black!! < 70)
        assertTrue(result.white!! > result.black!!)
    }

    /** La même chute, mais c'est un coup BLANC : le verdict s'inverse. */
    @Test
    fun `le point de vue suit le trait, pas les Blancs`() {
        // ply 0 : Blancs jouent et font tomber leur propre probabilité.
        val percents = listOf(50.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { percents.getOrNull(it) },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertTrue("Blancs ${result.white}", result.white!! < 70)
        assertTrue("Noirs ${result.black}", result.black!! > 95)
    }

    /**
     * Un TROU dans la passe fait sauter le coup concerné, et LUI SEUL : il ne
     * compte pour personne, ni à charge ni à décharge, et les autres coups
     * gardent leur verdict.
     *
     * C'est le piège du portage : si les trois séries ne sautaient pas le même
     * coup, toutes les fautes suivantes changeraient de camp. Ici la gaffe
     * noire tombe dans le trou — les Noirs restent donc innocents, et c'est
     * bien le signe que rien n'a glissé d'un cran.
     */
    @Test
    fun `une position non évaluée ne fait sauter que son coup`() {
        // ply 2 : les Blancs jouent, rien ne bouge. ply 3 : les Noirs
        // s'effondreraient — mais la position 4 n'est pas évaluée.
        val percents = mapOf(0 to 50.0, 1 to 50.0, 2 to 50.0, 3 to 50.0, 5 to 95.0, 6 to 95.0)
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { percents[it] },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNotNull(result.white)
        assertNotNull(result.black)
        assertTrue("Noirs ${result.black}", result.black!! > 95)
    }

    /** Aucune position évaluée : rien à dire, et surtout pas « 100 % ». */
    @Test
    fun `une passe qui n'a rien évalué fait taire le calcul`() {
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { null },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNull(result.white)
        assertNull(result.black)
        assertTrue(result.isEmpty)
    }

    /** Un seul demi-coup joué : les Noirs n'ont encore rien à défendre. */
    @Test
    fun `un camp qui n'a pas joué n'a pas de précision`() {
        val result = VariantAccuracy.byColor(
            plyCount = 1,
            winPercentWhite = { 50.0 },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNotNull(result.white)
        assertNull(result.black)
    }

    /** Rien de joué : rien à dire, et surtout pas « 100 % ». */
    @Test
    fun `une partie vide ne produit aucun chiffre`() {
        val result = VariantAccuracy.byColor(0, { 50.0 }, { true })
        assertTrue(result.isEmpty)
    }

    /**
     * La passe AVANCE : la précision se complète avec elle au lieu
     * d'apparaître d'un coup à la fin. Sur les quatre premiers demi-coups
     * connus d'une partie qui en compte six, le calcul rend déjà un chiffre.
     */
    @Test
    fun `la précision se complète au fil de la passe`() {
        val connus = 4
        val result = VariantAccuracy.byColor(
            plyCount = 6,
            winPercentWhite = { if (it <= connus) 50.0 else null },
            whiteMovesAt = { it % 2 == 0 },
        )
        assertNotNull(result.white)
        assertNotNull(result.black)
    }

    /** Les Blancs jouent les demi-coups pairs : deux camps, pas un seul. */
    @Test
    fun `les deux camps sont distingués`() {
        val percents = listOf(50.0, 50.0, 50.0, 20.0, 20.0)
        val result = VariantAccuracy.byColor(
            plyCount = 4,
            winPercentWhite = { percents.getOrNull(it) },
            // ply 2 : Blancs jouent et perdent 30 points.
            whiteMovesAt = { it % 2 == 0 },
        )
        assertEquals(true, result.white!! < result.black!!)
    }
}
