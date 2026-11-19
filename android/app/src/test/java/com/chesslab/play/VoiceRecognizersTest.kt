package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * La variante de la langue demandée au reconnaisseur (19/11/2026) : un Galaxy réglé en français de Suisse n'a que
 * « fr-CH » et répondait « langue indisponible » (erreur 13) à « fr-FR ».
 */
class VoiceRecognizersTest {
    private val swiss = Locale.forLanguageTag("fr-CH")
    private val france = Locale.forLanguageTag("fr-FR")

    @Test fun `un téléphone suisse reconnaît en fr-CH qui est la variante installée`() {
        assertEquals("fr-CH", VoiceRecognizers.locale("fr", listOf("en-US", "fr-CH"), swiss))
    }

    @Test fun `la variante du téléphone passe avant celle par défaut quand les deux sont installées`() {
        assertEquals("fr-CH", VoiceRecognizers.locale("fr", listOf("fr-FR", "fr-CH"), swiss))
        assertEquals("fr-FR", VoiceRecognizers.locale("fr", listOf("fr-CH", "fr-FR"), france))
    }

    @Test fun `seule une autre variante est installée, on la prend`() {
        assertEquals("fr-CA", VoiceRecognizers.locale("fr", listOf("en-US", "fr-CA"), france))
    }

    @Test fun `téléphone dans une autre langue que l'app, la variante par défaut si elle est là`() {
        assertEquals("de-DE", VoiceRecognizers.locale("de", listOf("fr-CH", "de-DE", "de-CH"), swiss))
    }

    @Test fun `rien d'installé, la variante du téléphone si c'est la même langue, sinon celle par défaut`() {
        assertEquals("fr-CH", VoiceRecognizers.locale("fr", emptyList(), swiss))
        assertEquals("it-IT", VoiceRecognizers.locale("it", emptyList(), swiss))
        assertEquals("en-US", VoiceRecognizers.locale("en", listOf("fr-CH"), swiss))
    }
}
