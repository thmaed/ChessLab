package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain

/**
 * Le Chess960 par NUMÉRO, et la partie à deux sur un seul appareil.
 *
 * Le numéro est celui de Scharnagl — celui de Lichess et des moteurs. Qu'il
 * arrive jusqu'au plateau se vérifie ici ; qu'il désigne la bonne position se
 * vérifie sur les 960 (test JVM contre le fichier de python-chess).
 */
class Chess960Test {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitText(text: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    private fun openSetup() {
        compose.onNodeWithTag("mode-variants").performScrollTo().performClick()
        compose.onNodeWithTag("variante-chess960").performScrollTo().performClick()
        compose.onNodeWithTag("numero-960").performScrollTo().assertExists()
    }

    @Test fun laPositionChoisieArriveSurLePlateau() {
        openSetup()
        // 518 : la position classique. Elle se reconnaît d'un coup d'œil, ce
        // qu'aucune des 959 autres ne permet.
        compose.onNodeWithTag("classique-960").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()

        awaitText("À vous de jouer")
        compose.onNodeWithTag("numero-position").assertExists()
        awaitText("518")
        // Et c'est bien la position classique : le cavalier en b1, le roi en e1.
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        compose.waitUntil(90_000) {
            compose.onAllNodesWithText("2 demi-coups").fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test fun unNumeroSeSaisitALaMain() {
        openSetup()
        compose.onNodeWithTag("numero-960").performTextClearance()
        compose.onNodeWithTag("numero-960").performTextInput("0")
        compose.onNodeWithTag("commencer").performClick()
        awaitText("À vous de jouer")
        awaitText("0")
    }

    /**
     * À deux, le moteur n'est plus qu'un arbitre : personne ne joue contre
     * lui, et les deux camps se jouent à la main. Le statut nomme la COULEUR
     * au trait — « à vous » ne voudrait rien dire.
     */
    @Test fun aDeuxLeMoteurNeJoueRien() {
        openSetup()
        compose.onNodeWithTag("classique-960").performScrollTo().performClick()
        compose.onNodeWithTag("deux-joueurs").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()

        awaitText("Aux blancs de jouer")
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e4").performClick()
        // Le moteur ne répond pas : c'est aux Noirs, et ils attendent.
        awaitText("Aux noirs de jouer")
        awaitText("1 demi-coup")

        compose.onNodeWithTag("case-e7").performClick()
        compose.onNodeWithTag("case-e5").performClick()
        awaitText("Aux blancs de jouer")
        awaitText("2 demi-coups")
    }
}
