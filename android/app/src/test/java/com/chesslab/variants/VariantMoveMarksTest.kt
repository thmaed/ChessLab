package com.chesslab.variants

import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Les cases à surligner pour un coup de variante.
 *
 * Le défaut que ce test empêche de revenir : au Crazyhouse, le moteur répond
 * `P@e4` pour poser une pièce de sa réserve. Découpé comme un coup ordinaire,
 * cela donne `P@` et `e4` — et `Square("P@")` ne proteste pas, il retombe
 * silencieusement sur `a1`. L'app surlignait `a1` → `e4` à chaque parachutage
 * de l'adversaire, à l'écran de jeu comme dans la revue d'après-partie.
 *
 * C'est le genre de faute que rien ne signale : pas d'exception, pas de
 * journal, juste une case allumée qui n'a rien à voir.
 */
class VariantMoveMarksTest {

    @Test fun `un coup ordinaire garde son départ et son arrivée`() {
        assertEquals(Square("e2") to Square("e4"), VariantMoveMarks.of("e2e4"))
    }

    @Test fun `une promotion aussi, malgré sa cinquième lettre`() {
        assertEquals(Square("e7") to Square("e8"), VariantMoveMarks.of("e7e8q"))
    }

    @Test fun `un parachutage n'a PAS de case de départ`() {
        // La faute d'origine rendait `a1 to e4`.
        assertEquals(Square("e4") to Square("e4"), VariantMoveMarks.of("P@e4"))
    }

    @Test fun `toutes les pièces se parachutent`() {
        for (lettre in listOf("P", "N", "B", "R", "Q")) {
            val cible = Square("d5")
            assertEquals("$lettre@d5", cible to cible, VariantMoveMarks.of("$lettre@d5"))
        }
    }

    /** Un coup trop court ne surligne rien plutôt que de surligner faux. */
    @Test fun `une réponse tronquée ne rend rien`() {
        assertNull(VariantMoveMarks.of(""))
        assertNull(VariantMoveMarks.of("e2"))
        assertNull(VariantMoveMarks.of("e2e"))
    }
}
