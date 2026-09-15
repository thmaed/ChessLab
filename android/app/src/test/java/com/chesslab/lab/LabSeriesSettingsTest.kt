package com.chesslab.lab

import com.chesslab.play.BookWidth
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les réglages d'une série, écrits puis relus.
 *
 * L'enjeu n'est pas l'encodage — c'est qu'une série de cent parties tourne un
 * quart d'heure, et qu'un fichier mal relu la jette sans rien dire. La
 * relecture doit donc SURVIVRE à un fichier écrit par une version antérieure,
 * champ manquant compris.
 */
class LabSeriesSettingsTest {

    @Test fun `des reglages se relisent tels qu'ils ont ete ecrits`() {
        val settings = LabSeriesSettings(
            sideAProfileId = "lea", sideBProfileId = null,
            sideALevel = 2200.0, sideBLevel = 1900.0,
            movetimeMs = 450, gameCount = 60,
            alternateColors = false, resignationEnabled = false,
            drawAgreementEnabled = false, liveVisualization = false,
            bookA = false, bookB = true, bookWidth = BookWidth.mainLinesOnly,
            keepAwakeSetting = true, startFen = "8/8/8/8/8/8/8/K6k w - - 0 1",
        )
        assertEquals(settings, LabSeriesSettings.fromJson(settings.toJson()))
    }

    @Test fun `un champ absent ne fait pas tomber les autres`() {
        val decoded = LabSeriesSettings.fromJson(JSONObject("""{"gameCount":150,"movetimeMs":900}"""))
        assertEquals(150, decoded.gameCount)
        assertEquals(900, decoded.movetimeMs)
        // Les autres gardent leur valeur d'usine, et le livre reste allumé.
        assertTrue(decoded.bookA)
        assertEquals(BookWidth.includeSidelines, decoded.bookWidth)
        assertEquals(LabSeriesSettings().sideALevel, decoded.sideALevel, 0.001)
    }

    /**
     * `null` veut dire « l'utilisateur n'y a pas touché », et c'est différent
     * de `false` : le défaut suit alors la longueur de la série.
     */
    @Test fun `la veille non reglee reste indecidee`() {
        val decoded = LabSeriesSettings.fromJson(JSONObject("{}"))
        assertNull(decoded.keepAwakeSetting)
        val explicit = LabSeriesSettings.fromJson(JSONObject("""{"keepAwakeSetting":false}"""))
        assertEquals(false, explicit.keepAwakeSetting)
    }

    /** Un personnage se retrouve par son identifiant ; un identifiant inconnu rend Stockfish. */
    @Test fun `le personnage se retrouve par son identifiant`() {
        assertEquals("lea", LabSeriesSettings(sideAProfileId = "lea").sideA.profile?.id)
        assertNull(LabSeriesSettings(sideAProfileId = "personne").sideA.profile)
        assertNull(LabSeriesSettings(sideBProfileId = null).sideB.profile)
    }
}
