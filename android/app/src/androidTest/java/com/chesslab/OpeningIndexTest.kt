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
 * L'index des lignes, sur l'appareil.
 *
 * L'ARBRE est prouvé sur la JVM (`OpeningLineTreeTest`) ; ce qui se vérifie
 * ici est le geste central de l'écran : taper un coup au milieu d'une
 * variante amène le lecteur DIRECTEMENT à cette position, avec le fil des
 * coups rempli — pas « au début de la ligne, puis N fois Suivant ».
 */
@RunWith(AndroidJUnit4::class)
class OpeningIndexTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openItalianGame() {
        compose.onNodeWithTag("mode-openings").performScrollTo().performClick()
        awaitTag("compte")
        compose.onNodeWithTag("recherche").performTextInput("Italian")
        awaitTag("cours-italian-game", 10_000)
        compose.onNodeWithTag("cours-italian-game").performClick()
        awaitTag("racine")
    }

    @Test fun taperUnCoupDeLIndexAmeneASaPosition() {
        openItalianGame()
        compose.onNodeWithTag("index-des-lignes").performClick()
        awaitTag("index-rangee-0", 20_000)

        // Le 5ᵉ demi-coup de la ligne principale de l'Italienne : 3.Fc4.
        // Un seul tap, et le lecteur doit être là — cinq coups plus loin.
        compose.onNodeWithTag("index-coup-5-f1c4").performScrollTo().performClick()
        awaitTag("fil-4", 20_000)
        compose.onNodeWithTag("fil-4").assertIsDisplayed()
        compose.onNodeWithTag("case-c4").assertIsDisplayed()
        // Et l'index s'est refermé de lui-même.
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("index-fermer").fetchSemanticsNodes().isEmpty() }
    }

    @Test fun lIndexRouvertMontreOuLOnEst() {
        openItalianGame()
        repeat(3) { compose.onNodeWithTag("suivant").performClick(); compose.waitForIdle() }

        compose.onNodeWithTag("index-des-lignes").performClick()
        awaitTag("index-rangee-0", 20_000)
        // Le coup courant est dans l'arbre, et l'écran s'est ouvert dessus.
        compose.onNodeWithTag("index-coup-3-g1f3").assertIsDisplayed()
        compose.onNodeWithTag("index-fermer").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("index-fermer").fetchSemanticsNodes().isEmpty() }
    }

    @Test fun leLecteurMontreLesMaitresEtLeMoteur() {
        openItalianGame()
        // À la racine, le sidecar sait ce que jouent les maîtres et ce que dit
        // le moteur : la première ligne du moteur est e4.
        compose.onNodeWithTag("moteur-e2e4").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("maitre-e2e4").performScrollTo().assertIsDisplayed()
        // Et une ligne du moteur qui est dans le répertoire se JOUE.
        compose.onNodeWithTag("moteur-e2e4").performClick()
        awaitTag("fil-0", 10_000)
    }
}
