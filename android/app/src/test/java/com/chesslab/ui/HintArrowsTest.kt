package com.chesslab.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le barème des flèches d'indice, vérifié sur des valeurs écrites à la main.
 *
 * C'est la promesse faite à l'utilisateur : une à trois flèches, et leur teinte
 * dit leur force. Une fonction pure, donc vérifiable sans moteur ni émulateur.
 */
class HintArrowsTest {

    private fun build(vararg lignes: Pair<String, Double>) = HintArrowBuilder.build(
        lignes.mapIndexed { i, (lan, _) -> (i + 1) to lan }.toMap(),
        lignes.mapIndexed { i, (_, score) -> (i + 1) to score }.toMap(),
    )

    @Test fun `trois coups qui se valent donnent trois flèches`() {
        val arrows = build("e2e4" to 30.0, "d2d4" to 28.0, "g1f3" to 25.0)
        assertEquals(3, arrows.size)
        assertEquals("e4", arrows[0].to.notation)
        assertEquals("d4", arrows[1].to.notation)
        assertEquals("f3", arrows[2].to.notation)
    }

    @Test fun `la force décroît avec le rang, même à évaluation égale`() {
        val arrows = build("e2e4" to 30.0, "d2d4" to 30.0, "g1f3" to 30.0)
        assertTrue("les rangs doivent se distinguer", arrows[0].strength > arrows[1].strength)
        assertTrue("les rangs doivent se distinguer", arrows[1].strength > arrows[2].strength)
        assertEquals(1f, arrows[0].strength, 1e-6f)
    }

    @Test fun `un coup nettement inférieur n'a pas de flèche`() {
        // Plus de 120 centipions sous le meilleur : ce n'est plus une
        // suggestion, c'est une erreur qu'on proposerait.
        val arrows = build("e2e4" to 30.0, "d2d4" to 20.0, "a2a3" to -150.0)
        assertEquals(2, arrows.size)
    }

    @Test fun `une position à coup unique ne montre qu'une flèche`() {
        assertEquals(1, build("e2e4" to 30.0).size)
    }

    @Test fun `l'écart d'évaluation affaiblit la flèche en plus du rang`() {
        val serrees = build("e2e4" to 30.0, "d2d4" to 30.0)
        val distantes = build("e2e4" to 30.0, "d2d4" to -60.0)
        assertTrue(
            "un second choix plus faible doit être moins marqué",
            distantes[1].strength < serrees[1].strength,
        )
    }

    @Test fun `la teinte s'assombrit quand le coup se renforce`() {
        val fort = HintArrowBuilder.tint(1.0)
        val faible = HintArrowBuilder.tint(0.12)
        assertTrue("le meilleur coup doit être le plus sombre", fort.red < faible.red)
        // Une composante de couleur est stockée sur huit bits : 0,12 devient
        // 31/255. La tolérance est donc celle d'un pas de quantification.
        assertEquals(0.12f, fort.red, 1f / 255f)
    }

    @Test fun `un mat court prime un mat long`() {
        val court = HintArrowBuilder.score(null, 1)!!
        val long = HintArrowBuilder.score(null, 5)!!
        assertTrue("mat en 1 doit valoir plus que mat en 5", court > long)
        // Et un mat subi est au fond de l'échelle.
        assertTrue(HintArrowBuilder.score(null, -2)!! < HintArrowBuilder.score(900, null)!!)
    }

    @Test fun `sans meilleur coup, rien`() {
        assertEquals(emptyList<BoardArrow>(), HintArrowBuilder.build(emptyMap(), emptyMap()))
        assertEquals(
            emptyList<BoardArrow>(),
            HintArrowBuilder.build(mapOf(2 to "e2e4"), mapOf(2 to 30.0)),
        )
    }
}
