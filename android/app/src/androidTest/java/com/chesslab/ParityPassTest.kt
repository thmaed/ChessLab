package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.settings.SettingsStore
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * La passe de parité du 01/10/2026, vérifiée À L'ÉCRAN — ce que les tests JVM
 * ne voient pas : un champ qui existe, un nom qui arrive sur la plaque, un
 * menu présent là où iOS en a un.
 */
@RunWith(AndroidJUnit4::class)
class ParityPassTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    /** Le nom choisi ne doit pas survivre au test : les autres attendent « Vous ». */
    @After fun oublierLeNom() {
        SettingsStore.setPlayerName(context, "")
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
        }

    /** Réglages → « Votre nom » : le champ existe, juste sous la langue, comme sur iOS. */
    @Test fun leChampVotreNomExisteDansLesReglages() {
        compose.onNodeWithTag("reglages").performClick()
        awaitTag("player-name")
        // Le titre de section s'écrit en capitales à l'écran : on vise le
        // CHAMP, qui est ce qui compte — il existe, et il écrit le réglage.
        compose.onNodeWithTag("player-name").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("player-name").performTextInput("Ron")
        compose.waitUntil(5_000) { SettingsStore.state.value.playerName == "Ron" }
    }

    /** Le nom choisi remplace « Vous » sur la plaque du joueur, pendant la partie. */
    @Test fun leNomChoisiArriveSurLaPlaque() {
        SettingsStore.setPlayerName(context, "Ron")
        compose.onNodeWithTag("mode-play").performScrollTo().performClick()
        awaitTag("commencer", 120_000)
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("joueur-vous", 120_000)
        awaitText("Ron")
        compose.onNodeWithText("Ron").assertIsDisplayed()
    }

    /**
     * L'écran de JEU d'une variante a son menu d'export, comme sur iOS. Il ne
     * l'avait que sur la revue : on ne pouvait pas envoyer une partie en cours.
     */
    @Test fun uneVarianteSePartageDepuisLEcranDeJeu() {
        compose.onNodeWithTag("mode-variants").performScrollTo().performClick()
        awaitTag("variante-kingofthehill")
        compose.onNodeWithTag("variante-kingofthehill").performScrollTo().performClick()
        awaitTag("commencer", 120_000)
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("exporter", 120_000)
        compose.onNodeWithTag("exporter").assertIsDisplayed()
    }
}
