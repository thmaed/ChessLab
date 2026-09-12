package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * « Changer de mode » : le raccourci qui emporte la position affichée vers un
 * autre grand mode, sur chaque écran qui a une position. Pendant des dix
 * écrans iOS qui portent `QuickSwitchMenu`.
 *
 * Ce qui est vérifié n'est pas que le menu s'ouvre — c'est que la POSITION
 * ARRIVE : un lien qui navigue en perdant la position ne sert à rien.
 */
@RunWith(AndroidJUnit4::class)
class QuickSwitchTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun open(mode: String) {
        compose.onNodeWithTag("mode-$mode").performScrollTo().performClick()
    }

    /**
     * Deux joueurs passe d'abord par l'écran de RÉGLAGES — noms, présentation
     * du plateau, cadence — depuis le 12/09. On le traverse avec les valeurs
     * par défaut : c'est bien la partie qu'on vient tester.
     */
    private fun openTwoPlayers() {
        open("two")
        awaitTag("commencer")
        compose.onNodeWithTag("commencer").performClick()
    }

    /** Ouvre le menu et choisit une destination par son libellé. */
    private fun switchTo(label: String) {
        compose.onNodeWithTag("changer-de-mode").performClick()
        compose.waitForIdle()
        compose.onNodeWithText(label, ignoreCase = true).performClick()
        compose.waitForIdle()
    }

    @Test fun leMenuEstSurLesDeuxJoueurs() {
        openTwoPlayers()
        awaitTag("changer-de-mode")
        compose.onNodeWithTag("changer-de-mode").assertIsDisplayed()
    }

    @Test fun deuxJoueursEnvoieLaPositionVersLAnalyse() {
        openTwoPlayers()
        awaitTag("case-e2")
        // Un coup, pour que la position ne soit plus la position initiale :
        // c'est LUI qu'on doit retrouver de l'autre côté.
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        compose.waitForIdle()

        switchTo("Analyser")

        // L'analyse s'ouvre sur la position reçue : le plateau est là, et le
        // pion est bien arrivé en e4.
        awaitTag("case-e4")
        awaitText("position", 20_000)
    }

    @Test fun lesPuzzlesPortentLeMenu() {
        open("puzzles")
        awaitTag("changer-de-mode", 120_000)
        compose.onNodeWithTag("changer-de-mode").assertIsDisplayed()
    }

    @Test fun laListeDOuverturesPorteLeMenu() {
        open("openings")
        awaitTag("changer-de-mode", 60_000)
        // Depuis une liste, la bascule ouvre simplement le mode : il n'y a pas
        // de position affichée à emporter, donc on arrive sur les RÉGLAGES.
        switchTo("Deux joueurs")
        awaitTag("commencer", 30_000)
        compose.onNodeWithTag("commencer").performClick()
        awaitTag("case-e2", 30_000)
    }

    @Test fun lAnalyseRenvoieVersUnePartieContreLOrdinateur() {
        openTwoPlayers()
        awaitTag("case-e2")
        compose.onNodeWithTag("case-d2").performClick()
        compose.onNodeWithTag("case-d4").performClick()
        compose.waitForIdle()

        switchTo("Analyser")
        awaitTag("case-d4", 30_000)

        // Et de l'analyse, on repart jouer CETTE position contre l'ordinateur.
        switchTo("Contre l'ordinateur")
        awaitTag("case-d4", 120_000)
        // Le pion est bien en d4 : la partie n'a pas recommencé de zéro.
        compose.onNodeWithTag("case-d4").assertIsDisplayed()
    }
}
