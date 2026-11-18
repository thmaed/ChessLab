package com.chesslab.maia

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Pendant d'`OpponentTraitsTests` (iOS) : les jauges se lisent dans les réglages des personnages. */
class OpponentTraitsTest {
    private fun t(id: String) = OpponentTraits.of(OpponentGallery.byId(id)!!)

    /** La table EXACTE, la même qu'iOS (`theWholeTableMatchesAndroid`) : une divergence se voit ici. */
    @Test fun `la table des jauges est celle d'iOS`() {
        val expected = mapOf(
            "maia" to listOf(3, 3, 3, 3), "lea" to listOf(5, 3, 1, 3), "theo" to listOf(5, 2, 1, 4),
            "sacha" to listOf(4, 2, 3, 4), "pablo" to listOf(5, 1, 3, 5), "marc" to listOf(1, 5, 3, 1),
            "nadia" to listOf(2, 4, 5, 1), "yuri" to listOf(1, 4, 4, 2), "ines" to listOf(3, 4, 3, 2),
        )
        for ((id, values) in expected) {
            val got = t(id)
            assertEquals(values, listOf(got.attack, got.solidity, got.trades, got.unpredictability), id)
        }
    }

    @Test fun `chaque personnage se lit comme sa phrase`() {
        assertEquals(5, t("lea").attack, "Lena attaque")
        assertEquals(5, t("marc").solidity, "Nils est solide")
        assertEquals(5, t("pablo").unpredictability, "Pablo est imprévisible")
        assertEquals(5, t("nadia").trades, "Nadia échange les dames")
        assertTrue(t("theo").solidity < t("lea").solidity, "Milo néglige roque et développement, pas Lena")
        assertTrue(t("pablo").attack > t("sacha").attack, "Pablo fonce, Sacha tend des pièges")
    }

    @Test fun `chaque note est entre 1 et 5`() {
        OpponentGallery.all.forEach { p ->
            val x = OpponentTraits.of(p)
            listOf(x.attack, x.solidity, x.trades, x.unpredictability).forEach { assertTrue(it in 1..5, p.id) }
        }
    }
}
