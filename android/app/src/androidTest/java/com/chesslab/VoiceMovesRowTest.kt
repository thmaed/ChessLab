package com.chesslab

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * COUPS À LA VOIX (19/11/2026) : la ligne « Coups à la voix » de la carte « Partie », dans Nouvelle partie. Pendant de
 * `VoiceMovesUITests` (iOS). Le micro lui-même ne se teste pas ici ; la partie est couverte par `VoiceMovesGameTest`.
 */
@RunWith(AndroidJUnit4::class)
class VoiceMovesRowTest {
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    @Test fun laLigneCoupsALaVoixEstDansLaCartePartie() {
        compose.onNodeWithTag("mode-play").performScrollTo().performClick()
        compose.waitUntil(120_000) { compose.onAllNodesWithTag("voix-coups").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("voix-coups").performScrollTo()
        // Un appareil sans reconnaissance SUR L'APPAREIL dans la langue grise l'interrupteur et le dit.
        compose.waitForIdle()
        val node = compose.onNodeWithTag("voix-coups").fetchSemanticsNode()
        assertTrue("Nouvelle partie s'ouvre TOUJOURS voix éteinte, même allumée la fois d'avant (19/11/2026)",
            node.config.getOrElseNullable(SemanticsProperties.ToggleableState) { null } ==
                androidx.compose.ui.state.ToggleableState.Off)
        val disabled = node.config.contains(SemanticsProperties.Disabled)
        if (disabled) {
            assertTrue("un interrupteur grisé doit dire pourquoi",
                compose.onAllNodesWithTag("voix-coups-note").fetchSemanticsNodes().isNotEmpty())
        }
    }
}
