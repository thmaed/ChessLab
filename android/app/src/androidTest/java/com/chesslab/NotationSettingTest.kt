package com.chesslab

import android.app.Application
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.settings.PieceNotation
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La notation des coups : « Automatique » par défaut (elle suit la langue de l'app), puis le choix de
 * l'utilisateur, MÉMORISÉ (DataStore) ; « Automatique » se mémorise de même. Pendant de
 * `NotationSettingUITests` (iOS), vérification demandée le 16/11/2026.
 */
@RunWith(AndroidJUnit4::class)
class NotationSettingTest {

    private val app get() = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application

    @After fun reglageRestaure() {
        SettingsStore.setPieceNotation(app, null)
        SettingsStore.followLanguage(java.util.Locale.getDefault().language)
    }

    private fun awaitState(condition: (com.chesslab.settings.AppSettings) -> Boolean) = runBlocking {
        withTimeout(10_000) { SettingsStore.state.first(condition) }
    }

    @Test fun automatiqueParDefautPuisChoixMemorise() {
        SettingsStore.start(app)

        // « Automatique » : la notation affichée est celle de la langue de l'interface (fixée ici, pour ne pas
        // dépendre de la langue laissée par le test précédent)…
        SettingsStore.followLanguage("de")
        SettingsStore.setPieceNotation(app, null)
        val auto = awaitState { it.pieceNotationAuto }
        assertTrue(auto.pieceNotationAuto)
        assertEquals(PieceNotation.german, auto.pieceNotation)
        // … et elle la SUIT quand la langue change, sans attendre un relancement (comme iOS).
        SettingsStore.followLanguage("es")
        assertEquals(PieceNotation.spanish, awaitState { it.pieceNotation == PieceNotation.spanish }.pieceNotation)

        // Un choix explicite l'emporte, et c'est lui qui est enregistré ; un changement de langue n'y touche pas.
        SettingsStore.setPieceNotation(app, PieceNotation.english)
        val chosen = awaitState { !it.pieceNotationAuto && it.pieceNotation == PieceNotation.english }
        assertFalse(chosen.pieceNotationAuto)
        SettingsStore.followLanguage("de")
        assertEquals(PieceNotation.english, SettingsStore.state.value.pieceNotation)

        // Retour à « Automatique », enregistré de même.
        SettingsStore.setPieceNotation(app, null)
        assertTrue(awaitState { it.pieceNotationAuto }.pieceNotationAuto)
    }
}
