package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Le test de bout en bout de l'écran de jeu : on clique des CASES, pas des
 * pixels, et on vérifie qu'une partie se déroule vraiment — moteur compris.
 *
 * C'est le seul test du projet qui demande un appareil ; tout le reste tourne
 * sur la JVM en quelques secondes.
 */
@RunWith(AndroidJUnit4::class)
class PlayScreenTest {

    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    @Test fun theBoardIsDisplayed() {
        compose.onNodeWithTag("case-e2").assertIsDisplayed()
        compose.onNodeWithTag("case-e4").assertIsDisplayed()
        compose.onNodeWithTag("case-h8").assertIsDisplayed()
    }

    @Test fun playingAMoveMakesTheEngineReply() {
        awaitText("À vous de jouer")          // le moteur doit être prêt

        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()

        awaitTag("coup-0", 10_000)            // notre coup est écrit
        awaitTag("coup-1", 60_000)            // le moteur a répondu
        awaitText("À vous de jouer")          // la main revient
    }
}
