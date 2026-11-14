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

    // Espagnol et allemand (2.3) — pendant de SpanishGermanSupportTests.swift.

    private fun es(san: String) = SanFormatter.display(san, PieceNotation.spanish)
    private fun de(san: String) = SanFormatter.display(san, PieceNotation.german)

    @Test fun `espagnol - R D T A C`() {
        assertEquals("Rb1", es("Kb1")); assertEquals("Dxd5+", es("Qxd5+")); assertEquals("Ta1", es("Ra1"))
        assertEquals("Ab5", es("Bb5")); assertEquals("Cf3", es("Nf3")); assertEquals("exd8=D#", es("exd8=Q#"))
        assertEquals("a8=C", es("a8=N")); assertEquals("O-O", es("O-O")); assertEquals("bxc3", es("bxc3"))
    }

    @Test fun `allemand - K D T L S`() {
        assertEquals("Kb1", de("Kb1")); assertEquals("Dxd5+", de("Qxd5+")); assertEquals("Ta1", de("Ra1"))
        assertEquals("Lb5", de("Bb5")); assertEquals("Sf3", de("Nf3")); assertEquals("a8=S", de("a8=N"))
        assertEquals("O-O-O", de("O-O-O")); assertEquals("bxc3", de("bxc3"))
    }

    @Test fun `une suite entiere se convertit en une seule passe`() {
        val line = listOf("Nf3", "Nc6", "Bb5", "a6", "Bxc6", "dxc6", "O-O", "Qd6", "Re1", "Kd8")
        assertEquals(
            listOf("Sf3", "Sc6", "Lb5", "a6", "Lxc6", "dxc6", "O-O", "Dd6", "Te1", "Kd8"),
            SanFormatter.display(line, PieceNotation.german),
        )
        assertEquals(
            listOf("Cf3", "Cc6", "Ab5", "a6", "Axc6", "dxc6", "O-O", "Dd6", "Te1", "Rd8"),
            SanFormatter.display(line, PieceNotation.spanish),
        )
    }

    @Test fun `la notation par defaut suit la langue`() {
        assertEquals(PieceNotation.spanish, PieceNotation.defaultFor("es"))
        assertEquals(PieceNotation.german, PieceNotation.defaultFor("de"))
        assertEquals(PieceNotation.french, PieceNotation.defaultFor("fr"))
        assertEquals(PieceNotation.english, PieceNotation.defaultFor("en"))
    }

    // Italien (2.3) — mêmes lettres que l'espagnol : Re, Donna, Torre, Alfiere, Cavallo.
    private fun it(san: String) = SanFormatter.display(san, PieceNotation.italian)

    @Test fun `italien - R D T A C`() {
        assertEquals("Rb1", it("Kb1")); assertEquals("Dxd5+", it("Qxd5+")); assertEquals("Ta1", it("Ra1"))
        assertEquals("Ab5", it("Bb5")); assertEquals("Cf3", it("Nf3")); assertEquals("a8=C", it("a8=N"))
        assertEquals("O-O-O", it("O-O-O"))
        assertEquals(PieceNotation.italian, PieceNotation.defaultFor("it"))
    }
}
