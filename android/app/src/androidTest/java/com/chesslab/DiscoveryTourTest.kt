package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.discovery.DiscoveryTourMemory
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain

/**
 * La visite guidée, de bout en bout : rejouée depuis l'Aide, elle pilote la
 * navigation (l'accueil, puis l'écran de réglages de partie), montre ses
 * chips, revient en arrière, et « Passer » la clôt en la comptant comme vue.
 */
class DiscoveryTourTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitText(text: String, timeoutMs: Long = 15_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun theTourReplaysFromHelpAndDrivesTheNavigation() {
        compose.onNodeWithTag("aide").performClick()
        compose.onNodeWithTag("revoir-visite").performScrollTo().performClick()

        // Étape 1 : l'accueil, sous le voile, et la tuile visée.
        awaitText("Tout part d'ici")
        compose.onNodeWithTag("mode-play").assertExists()

        // Étape 2 : la visite a OUVERT l'écran de réglages de partie.
        compose.onNodeWithTag("visite-suivant").performClick()
        awaitText("Choisissez votre adversaire")
        compose.onNodeWithTag("commencer").assertExists()

        // Étape 4 : les chips des gestes de la partie.
        compose.onNodeWithTag("visite-suivant").performClick()
        compose.onNodeWithTag("visite-suivant").performClick()
        awaitText("Pendant la partie")
        awaitText("Proposer nulle")

        // Retour d'une étape.
        compose.onNodeWithTag("visite-retour").performClick()
        awaitText("Les aides se choisissent avant")

        // Passer : la carte disparaît, l'écran où l'on était RESTE (comme sur
        // iOS, la visite ne ramène pas à l'accueil en partant), et la visite
        // compte comme vue.
        compose.onNodeWithTag("visite-passer").performClick()
        compose.waitUntil(15_000) { compose.onAllNodesWithTag("visite-carte").fetchSemanticsNodes().isEmpty() }
        compose.onNodeWithTag("commencer").assertIsDisplayed()
        compose.onNodeWithTag("retour").performClick()
        compose.onNodeWithTag("mode-play").assertIsDisplayed()
        assertFalse(DiscoveryTourMemory.shouldOffer(InstrumentationRegistry.getInstrumentation().targetContext))
    }
}
