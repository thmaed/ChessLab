package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Le bilan du Laboratoire, sur l'appareil.
 *
 * Les FORMULES sont prouvées sur la JVM (`LabStatsTest`) : ce qui se vérifie
 * ici est le branchement — que le panneau existe, que ses explications
 * s'ouvrent, et qu'une position collée est bien reprise par la série.
 */
@RunWith(AndroidJUnit4::class)
class LabSeriesTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openLab() {
        compose.onNodeWithTag("mode-lab").performScrollTo().performClick()
        awaitTag("bilan-detaille")
    }

    @Test fun leBilanEstLaAvantLaPremierePartie() {
        openLab()
        // Six tuiles, dès le départ : une série vide a un bilan bien défini.
        for (tag in listOf("tuile-score", "tuile-elo", "tuile-los", "tuile-vnd", "tuile-coups", "tuile-parties")) {
            compose.onNodeWithTag(tag).performScrollTo().assertIsDisplayed()
        }
    }

    @Test fun uneTuileSOuvreSurSonExplication() {
        openLab()
        compose.onNodeWithTag("tuile-elo").performScrollTo().performClick()
        awaitTag("explication", 10_000)
        // Elle s'ouvre SOUS la grille : on la fait venir avant de la regarder.
        compose.onNodeWithTag("explication").performScrollTo().assertIsDisplayed()
        // Et se referme : c'est la même touche.
        compose.onNodeWithTag("tuile-elo").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithTag("explication").fetchSemanticsNodes().isEmpty()
        }
    }

    @Test fun unePositionCollePartLaSerie() {
        openLab()
        // La forteresse de Sam Loyd, en FEN à quatre champs — celle des cours.
        compose.onNodeWithTag("position-depart").performScrollTo()
            .performTextInput("8/8/8/8/B6n/7p/6k1/4K3 w - -")
        compose.onNodeWithTag("poser-position").performScrollTo().performClick()
        compose.waitForIdle()

        // Le plateau montre la finale, et le retour à la position standard est
        // offert — donc la série a bien changé de point de départ.
        compose.onNodeWithTag("case-a4").assertIsDisplayed()
        awaitTag("position-standard", 10_000)
    }

    @Test fun unTexteIllisibleNeChangeRien() {
        openLab()
        compose.onNodeWithTag("position-depart").performScrollTo()
            .performTextInput("ceci n'est ni un fen ni un pgn")
        compose.onNodeWithTag("poser-position").performScrollTo().performClick()
        compose.waitForIdle()
        // Aucun retour à la standard proposé : rien n'a été imposé.
        compose.waitUntil(5_000) {
            compose.onAllNodesWithTag("position-standard").fetchSemanticsNodes().isEmpty()
        }
    }
}
