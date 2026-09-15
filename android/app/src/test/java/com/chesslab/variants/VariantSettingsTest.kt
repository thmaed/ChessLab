package com.chesslab.variants

import com.chesslab.play.EngineStrength
import com.chesslab.play.PlayerColorChoice
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les réglages d'une partie de variante : ce qui se relit, et ce qui se
 * traduit en commandes pour le moteur.
 *
 * Le cœur du sujet est le BRIDAGE. Fairy-Stockfish borne `UCI_Elo` à
 * 500…2850 — pas 1320…3190 comme Stockfish — et rejette EN SILENCE une valeur
 * hors bornes, en gardant son Elo par défaut : un curseur à 3000 donnait un
 * adversaire à 1350 sans que rien ne le dise.
 */
class VariantSettingsTest {

    @Test fun `un reglage se relit tel qu'il a ete ecrit`() {
        val settings = VariantSettings(
            colorChoice = PlayerColorChoice.black,
            level = 1750.0,
            timeControlId = "custom",
            customMinutes = 12,
            customIncrementSeconds = 7,
            showEvalBar = true,
            hintsEnabled = false,
            blunderAlertEnabled = false,
            tokenInterval = 4,
            twoPlayers = true,
            chess960Number = 518,
        )
        val decoded = VariantSettingsStore.decode(encode(settings))
        assertEquals(settings, decoded)
    }

    /**
     * Un champ absent ne doit pas faire retomber les AUTRES aux valeurs
     * d'usine : c'est ce qui arrive à chaque version quand on ajoute un
     * réglage, et l'utilisateur retrouverait tout à zéro sans comprendre.
     */
    @Test fun `un champ absent ne fait pas tomber les autres`() {
        val decoded = VariantSettingsStore.decode("""{"level":2100.0,"colorChoice":"black"}""")!!
        assertEquals(2100.0, decoded.level, 0.001)
        assertEquals(PlayerColorChoice.black, decoded.colorChoice)
        // Les autres gardent leur valeur par défaut, pas une valeur vide.
        assertEquals(VariantSettings().timeControlId, decoded.timeControlId)
        assertEquals(VariantSettings().tokenInterval, decoded.tokenInterval)
        assertTrue(decoded.hintsEnabled)
    }

    @Test fun `un texte illisible ne rend rien plutot qu'un reglage faux`() {
        assertNull(VariantSettingsStore.decode("pas du json"))
    }

    @Test fun `la cadence personnalisee suit ses deux nombres`() {
        val settings = VariantSettings(timeControlId = "custom", customMinutes = 3, customIncrementSeconds = 2)
        assertEquals(180, settings.timeControl.initialSeconds)
        assertEquals(2, settings.timeControl.incrementSeconds)
        assertTrue(settings.timeControl.hasClock)
    }

    @Test fun `sans cadence il n'y a pas de pendule`() {
        assertEquals(false, VariantSettings(timeControlId = "none").timeControl.hasClock)
    }

    /** 2850 est la borne HAUTE de Fairy-Stockfish : au-delà, plus de bridage du tout. */
    @Test fun `au-dela de la borne de Fairy le moteur est laisse libre`() {
        val commands = VariantSettings(level = 3000.0).strength.fairySetupCommands
        assertTrue(commands.any { it == "setoption name UCI_LimitStrength value false" })
        assertTrue(commands.none { it.startsWith("setoption name UCI_Elo") })
    }

    /** 500 est la borne BASSE : en dessous, on la remonte plutôt que se faire ignorer. */
    @Test fun `sous la borne de Fairy l'Elo remonte a la borne`() {
        val commands = EngineStrength.Limited(400).fairySetupCommands
        assertTrue(commands.contains("setoption name UCI_Elo value 500"))
    }

    @Test fun `un Elo dans les bornes passe tel quel`() {
        val commands = VariantSettings(level = 1600.0).strength.fairySetupCommands
        assertTrue(commands.contains("setoption name UCI_Elo value 1600"))
        assertTrue(commands.contains("setoption name UCI_LimitStrength value true"))
    }

    /**
     * Sous 1320, `UCI_Elo` n'a plus cours : on descend par `Skill Level` et une
     * profondeur courte. C'est ce que `maxDepth` rend au modèle de vue, qui
     * envoie alors `go depth` au lieu de `go movetime`.
     */
    @Test fun `un niveau tres bas se regle en profondeur`() {
        val strength = VariantSettings(level = 900.0).strength
        assertTrue(strength is EngineStrength.BelowMinimum)
        assertTrue((strength.maxDepth ?: 0) in 1..6)
    }

    /**
     * Le Coup Volé se joue en secret : un jeton se dépense sans l'annoncer, et
     * deux joueurs sur le même écran verraient tout. Le catalogue le dit, et
     * l'écran de réglage s'en sert pour ne pas proposer le mode à deux.
     */
    @Test fun `le Coup Vole ne se joue pas a deux sur un appareil`() {
        assertEquals(false, VariantCatalog.byId("stolenmove")!!.supportsTwoPlayers)
        assertEquals(true, VariantCatalog.byId("duck")!!.supportsTwoPlayers)
        assertEquals(true, VariantCatalog.byId("kingofthehill")!!.supportsTwoPlayers)
    }

    /** L'encodage passe par le store : on le reproduit ici sans `Context`. */
    private fun encode(s: VariantSettings): String = """
        {"colorChoice":"${s.colorChoice.name}","level":${s.level},
         "timeControlId":"${s.timeControlId}","customMinutes":${s.customMinutes},
         "customIncrementSeconds":${s.customIncrementSeconds},"showEvalBar":${s.showEvalBar},
         "hintsEnabled":${s.hintsEnabled},"blunderAlertEnabled":${s.blunderAlertEnabled},
         "tokenInterval":${s.tokenInterval},"twoPlayers":${s.twoPlayers},
         "chess960Number":${s.chess960Number ?: "null"}}
    """.trimIndent()
}
