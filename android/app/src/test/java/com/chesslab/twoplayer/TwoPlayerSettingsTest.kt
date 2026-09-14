package com.chesslab.twoplayer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les réglages d'une partie à deux : ce qui est écrit se relit, un champ
 * absent ne fait pas tout retomber aux valeurs d'usine, et la cadence
 * personnalisée donne bien la pendule qu'on a réglée.
 */
class TwoPlayerSettingsTest {

    @Test fun `ce qui est encode se relit`() {
        val settings = TwoPlayerSettings(
            whiteName = "Thierry", blackName = "Camille",
            rotation = TwoPlayerSettings.RotationMode.tabletop,
            timeControlId = "custom", customMinutes = 25, customIncrementSeconds = 5,
        )
        val back = TwoPlayerSettingsStore.decode(TwoPlayerSettingsStore.encode(settings))
        assertEquals(settings, back)
    }

    /**
     * La position de départ ne voyage PAS dans les réglages mémorisés : c'est
     * un choix ponctuel. Elle est rangée à part dans l'autosauvegarde.
     */
    @Test fun `la position de depart ne se memorise pas`() {
        val settings = TwoPlayerSettings(startFen = "8/8/8/8/8/8/8/K6k w - - 0 1")
        val back = TwoPlayerSettingsStore.decode(TwoPlayerSettingsStore.encode(settings))
        assertNull(back?.startFen)
    }

    /**
     * Ajouter un réglage ne doit pas faire retomber tous les autres : une
     * relecture tolérante, comme celle du mode Jouer.
     */
    @Test fun `un champ absent retombe sur son defaut sans perdre les autres`() {
        val back = TwoPlayerSettingsStore.decode("""{"whiteName":"Alice"}""")
        assertEquals("Alice", back?.whiteName)
        assertEquals(TwoPlayerSettings().rotation, back?.rotation)
        assertEquals("none", back?.timeControlId)
    }

    @Test fun `un texte illisible ne rend rien plutot que de planter`() {
        assertNull(TwoPlayerSettingsStore.decode("ceci n'est pas du JSON"))
    }

    @Test fun `la cadence personnalisee donne la pendule reglee`() {
        val settings = TwoPlayerSettings(
            timeControlId = "custom", customMinutes = 25, customIncrementSeconds = 10,
        )
        assertEquals(25 * 60, settings.timeControl.initialSeconds)
        assertEquals(10, settings.timeControl.incrementSeconds)
        assertTrue(settings.timeControl.hasClock)
    }

    @Test fun `sans cadence il n y a pas de pendule`() {
        assertEquals(false, TwoPlayerSettings().timeControl.hasClock)
    }
}
