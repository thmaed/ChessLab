package com.chesslab.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le partage de la largeur entre l'échiquier et le panneau, en paysage.
 * Pendant de `PlayLayoutProportionsTests.swift`.
 *
 * Android partageait à parts ÉGALES : sur une tablette de 10 pouces,
 * l'échiquier tombait à 618 dp quand 736 lui revenaient.
 */
class BoardLayoutTest {

    /** Ce que donnait l'ancien partage, pour comparer. */
    private fun halfSplitBoard(width: Float, height: Float, gap: Float = 12f) =
        minOf(height, (width - gap) / 2f)

    /** Tablette 10" en paysage : l'échiquier prend son carré, le panneau son plafond. */
    @Test fun uneTabletteDonneSonCarreALEchiquier() {
        val (w, h) = 1248f to 736f
        assertEquals(420f, BoardLayout.panelWidth(w, h), 0.01f)
        assertEquals(736f, BoardLayout.boardSide(w, h), 0.01f)
        assertEquals(618f, halfSplitBoard(w, h), 0.01f)
    }

    /** Tablette 7" : le panneau prend exactement ce qui reste à côté du carré. */
    @Test fun uneTabletteMoyenneNeGaspilleRien() {
        val (w, h) = 928f to 536f
        val panel = BoardLayout.panelWidth(w, h)
        assertEquals(380f, panel, 0.01f)
        assertEquals(536f, BoardLayout.boardSide(w, h), 0.01f)
        assertTrue(BoardLayout.boardSide(w, h) > halfSplitBoard(w, h))
    }

    /**
     * Le garde-fou propre à Android : un téléphone en paysage ou une fenêtre
     * partagée. Le plancher de 340 ne dépasse jamais la moitié de la largeur —
     * l'échiquier n'y est jamais plus petit qu'avec l'ancien partage égal.
     */
    @Test fun uneFenetreEtroiteNeFaitJamaisPireQueLAncienPartage() {
        for ((w, h) in listOf(768f to 300f, 568f to 336f, 500f to 380f, 860f to 360f)) {
            assertTrue(
                "${w}×$h : ${BoardLayout.boardSide(w, h)} contre ${halfSplitBoard(w, h)}",
                BoardLayout.boardSide(w, h) >= halfSplitBoard(w, h) - 0.01f,
            )
        }
    }

    /** Le plafond : une très grande fenêtre n'éparpille pas les commandes. */
    @Test fun lePanneauNeDepassePasSonPlafond() {
        assertEquals(BoardLayout.PANEL_MAX, BoardLayout.panelWidth(2400f, 1000f), 0.01f)
    }

    /** Et jamais plus large que la place elle-même. */
    @Test fun lePanneauNeDepassePasLaFenetre() {
        val panel = BoardLayout.panelWidth(200f, 150f)
        assertTrue(panel <= 200f - 12f)
        assertTrue(BoardLayout.boardSide(200f, 150f) >= 0f)
    }
}
