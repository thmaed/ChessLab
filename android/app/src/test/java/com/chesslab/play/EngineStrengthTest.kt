package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le barème de force. Il ne se voit nulle part à l'écran : ce qu'on lit, c'est
 * un chiffre — et jusqu'au 14/09 ce chiffre ne pilotait RIEN, le moteur jouant
 * à pleine puissance quel que soit le niveau choisi. Ces tests sont la seule
 * chose qui empêche d'y revenir sans s'en apercevoir.
 */
class EngineStrengthTest {

    @Test fun `au-dessus de la borne, aucune limite`() {
        val max = EngineStrength.of(3190.0)
        assertTrue(max is EngineStrength.Maximum)
        assertEquals(
            listOf(
                "setoption name UCI_LimitStrength value false",
                "setoption name Skill Level value 20",
            ),
            max.setupCommands,
        )
        assertNull("rien à plafonner", max.maxDepth)
    }

    @Test fun `entre 1320 et 3190, le moteur est bride par UCI_Elo`() {
        val limited = EngineStrength.of(1400.0)
        assertEquals(EngineStrength.Limited(1400), limited)
        assertEquals(
            listOf(
                "setoption name UCI_LimitStrength value true",
                "setoption name UCI_Elo value 1400",
                "setoption name Skill Level value 20",
            ),
            limited.setupCommands,
        )
        assertNull("la profondeur n'est pas plafonnée au-dessus de 1320", limited.maxDepth)
        // La borne basse d'UCI_Elo est bien 1320.
        assertTrue(EngineStrength.of(1320.0) is EngineStrength.Limited)
        assertTrue(EngineStrength.of(1319.0) is EngineStrength.BelowMinimum)
    }

    /**
     * Sous 1320, `UCI_Elo` n'existe plus : la force se simule par un
     * `Skill Level` bas ET une profondeur plafonnée. Sans le plafond, un
     * « grand débutant » à qui l'on donne quatre dixièmes de seconde reste un
     * joueur redoutable sur un plateau à trente-deux pièces.
     */
    @Test fun `sous 1320, Skill Level ET profondeur`() {
        val bottom = EngineStrength.of(800.0) as EngineStrength.BelowMinimum
        assertEquals(0, bottom.skillLevel)
        assertEquals(1, bottom.depth)
        assertEquals(1, bottom.maxDepth)
        assertEquals(
            listOf(
                "setoption name UCI_LimitStrength value false",
                "setoption name Skill Level value 0",
            ),
            bottom.setupCommands,
        )
        val top = EngineStrength.of(1319.0) as EngineStrength.BelowMinimum
        assertEquals(5, top.skillLevel)
        assertEquals(6, top.depth)
        // Et l'interpolation est monotone entre les deux.
        var previousSkill = -1
        var previousDepth = -1
        for (elo in 800..1319 step 20) {
            val s = EngineStrength.of(elo.toDouble()) as EngineStrength.BelowMinimum
            assertTrue("skill ne redescend jamais", s.skillLevel >= previousSkill)
            assertTrue("la profondeur non plus", s.depth >= previousDepth)
            previousSkill = s.skillLevel
            previousDepth = s.depth
        }
    }

    /**
     * Fairy-Stockfish ne connaît `UCI_Elo` qu'entre 500 et 2850, et REJETTE EN
     * SILENCE une valeur hors bornes : un curseur à 3000 donnait un adversaire
     * à 1350 sans le dire.
     */
    @Test fun `les bornes de Fairy-Stockfish sont respectees`() {
        assertEquals(500..2850, EngineStrength.fairyRatedRange)
        // Au-dessus de sa borne : plus de bridage du tout.
        assertEquals(
            EngineStrength.Maximum.setupCommands,
            EngineStrength.Limited(3000).fairySetupCommands,
        )
        // En dessous : ramené à la borne, pas laissé tel quel.
        assertTrue(EngineStrength.Limited(1400).fairySetupCommands.contains("setoption name UCI_Elo value 1400"))
    }

    @Test fun `le palier nomme est le plus proche, l'egalite au plus bas`() {
        assertEquals("e800", EnginePreset.nearest(800.0)?.id)
        assertEquals("e800", EnginePreset.nearest(900.0)?.id)
        assertEquals("e1000", EnginePreset.nearest(950.0)?.id)
        assertEquals("e1400", EnginePreset.nearest(1400.0)?.id)
        assertEquals("e2500", EnginePreset.nearest(2900.0)?.id)
        // Au MAXIMUM, aucun palier : c'est « Maximum », et le chiffre le dit.
        assertNull(EnginePreset.nearest(3190.0))
        assertEquals(8, EnginePreset.all.size)
    }

    @Test fun `la plage du mode Jouer monte jusqu'au maximum de Stockfish`() {
        assertEquals(800.0, EngineStrength.playSliderRange.start, 0.0)
        assertEquals(3190.0, EngineStrength.playSliderRange.endInclusive, 0.0)
        assertEquals(1320, EngineStrength.ratedMinimum)
    }

    @Test fun `le reglage par defaut est accueillant, pas la pleine puissance`() {
        val settings = PlayGameSettings()
        assertEquals(1200.0, settings.level, 0.0)
        assertTrue(settings.strength is EngineStrength.BelowMinimum)
        // Et le livre général s'en tient aux lignes principales.
        assertEquals(BookWidth.mainLinesOnly, settings.bookWidth)
    }

    @Test fun `la cadence personnalisee se fabrique a la demande`() {
        val settings = PlayGameSettings(timeControlId = "custom", customMinutes = 20, customIncrementSeconds = 5)
        assertEquals(20 * 60, settings.timeControl.initialSeconds)
        assertEquals(5, settings.timeControl.incrementSeconds)
        assertEquals("20+5", settings.timeControl.label)
        assertTrue(settings.timeControl.hasClock)
        assertTrue("custom" in TimeControl.categories)
    }
}
