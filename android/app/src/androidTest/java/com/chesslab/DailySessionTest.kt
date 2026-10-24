package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/** A5 / C7 : la carte « Séance du jour » de l'accueil ouvre l'écran des étapes. Pendant de `DailySessionUITests`. */
@RunWith(AndroidJUnit4::class)
class DailySessionTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    @Test fun laCarteOuvreLaSeance() {
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("seance-du-jour").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("seance-du-jour").performScrollTo().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("ecran-seance").fetchSemanticsNodes().isNotEmpty() }
        // La finale du jour est toujours proposée.
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("etape-endgame").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("etape-openings").assertExists()
    }
}
