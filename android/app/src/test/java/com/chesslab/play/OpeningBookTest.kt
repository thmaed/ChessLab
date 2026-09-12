package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/**
 * Le tirage dans le livre d'ouvertures. Fonction pure : ni plateau, ni fichier.
 */
class OpeningBookTest {

    private fun node(san: String, weight: Int, main: Boolean = true, children: List<BookNode> = emptyList()) =
        BookNode(san, weight, main, children)

    private val livre = listOf(
        node("e4", 60, children = listOf(
            node("e5", 50, children = listOf(node("Nf3", 100))),
            node("c5", 50, main = false),
        )),
        node("d4", 40, main = false),
    )

    @Test fun `le livre descend l'arbre avec les coups joués`() {
        assertEquals("Nf3", OpeningBookPicker.pick(livre, listOf("e4", "e5"), BookWidth.includeSidelines))
    }

    @Test fun `hors de l'arbre, le livre se tait`() {
        // À charge du moteur de prendre le relais : c'est le contrat.
        assertNull(OpeningBookPicker.pick(livre, listOf("a3"), BookWidth.includeSidelines))
        assertNull(OpeningBookPicker.pick(livre, listOf("e4", "e5", "Nf3", "Nc6"), BookWidth.includeSidelines))
    }

    @Test fun `les lignes principales seules excluent les secondaires`() {
        // d4 est marquée secondaire : en lignes principales, seul e4 reste.
        repeat(20) {
            assertEquals("e4", OpeningBookPicker.pick(livre, emptyList(), BookWidth.mainLinesOnly))
        }
        // Et après e4, c5 est secondaire : seul e5 reste.
        repeat(20) {
            assertEquals("e5", OpeningBookPicker.pick(livre, listOf("e4"), BookWidth.mainLinesOnly))
        }
    }

    @Test fun `le tirage suit les poids`() {
        // 60 contre 40 : on veut voir les deux, et e4 plus souvent.
        val counts = HashMap<String, Int>()
        val random = Random(20260912)
        repeat(2000) {
            val san = OpeningBookPicker.pick(livre, emptyList(), BookWidth.includeSidelines, random)!!
            counts[san] = (counts[san] ?: 0) + 1
        }
        assertEquals(setOf("e4", "d4"), counts.keys)
        assertTrue("e4 devrait sortir plus souvent : $counts", counts["e4"]!! > counts["d4"]!!)
        // Grossièrement 60/40 : on tolère large, c'est un tirage.
        val part = counts["e4"]!!.toDouble() / 2000
        assertTrue("proportion inattendue : $part", part in 0.52..0.68)
    }

    @Test fun `un livre vide ne propose rien`() {
        assertNull(OpeningBookPicker.pick(emptyList(), emptyList(), BookWidth.includeSidelines))
    }

    @Test fun `des poids nuls ne bloquent pas le tirage`() {
        val plat = listOf(node("e4", 0), node("d4", 0))
        assertEquals("e4", OpeningBookPicker.pick(plat, emptyList(), BookWidth.includeSidelines))
    }
}
