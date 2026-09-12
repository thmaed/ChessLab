package com.chesslab.ui

import com.chesslab.settings.PieceNotation
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * La notation française. Un piège, et un seul : la conversion doit se faire en
 * UNE passe.
 */
class SanFormatterTest {

    private fun fr(san: String) = SanFormatter.display(san, PieceNotation.french)
    private fun en(san: String) = SanFormatter.display(san, PieceNotation.english)

    @Test fun `les cinq pièces changent de lettre`() {
        assertEquals("Cf3", fr("Nf3"))
        assertEquals("Dxd5", fr("Qxd5"))
        assertEquals("Tae1", fr("Rae1"))
        assertEquals("Fb5+", fr("Bb5+"))
        assertEquals("Rg1", fr("Kg1"))
    }

    @Test fun `le roi ne devient pas une tour`() {
        // Le piège : « R → T » puis « K → R » retraduirait les T fraîchement
        // écrits. Un roi et une tour dans le même coup le prouvent.
        assertEquals("Tad1", fr("Rad1"))
        assertEquals("Rf1", fr("Kf1"))
        // Et les deux d'affilée, sur une suite.
        assertEquals(listOf("Tad1", "Rf1"), SanFormatter.display(listOf("Rad1", "Kf1"), PieceNotation.french))
    }

    @Test fun `les colonnes minuscules ne bougent pas`() {
        // « b » est la colonne b, jamais le fou. « e4 » non plus n'a rien à voir.
        assertEquals("bxc6", fr("bxc6"))
        assertEquals("e4", fr("e4"))
        assertEquals("axb5", fr("axb5"))
    }

    @Test fun `le roque et les marqueurs traversent intacts`() {
        assertEquals("O-O", fr("O-O"))
        assertEquals("O-O-O+", fr("O-O-O+"))
        assertEquals("Dh5#", fr("Qh5#"))
    }

    @Test fun `la promotion suit, et c'est voulu`() {
        assertEquals("e8=D+", fr("e8=Q+"))
        assertEquals("a1=C", fr("a1=N"))
    }

    @Test fun `en anglais, rien ne change`() {
        listOf("Nf3", "Qxd5", "Rae1", "Bb5+", "Kg1", "O-O", "e8=Q").forEach {
            assertEquals(it, en(it))
        }
    }
}
