package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Partie À L'AVEUGLE de bout en bout (17/11/2026). Pendant de `BlindfoldUITests` (iOS) : la carte de
 * l'accueil ouvre le réglage, section cochée ; « Tout caché » ; le plateau ne nomme plus ses pièces ; un coup
 * impossible le dit ; un coup juste se joue en touchant départ puis arrivée ; le coup d'œil se compte ;
 * l'abandon fait réapparaître les pièces et le bilan dit comment la partie a été jouée.
 */
@RunWith(AndroidJUnit4::class)
class BlindfoldTest {
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /** Pas de partie laissée en cours par un autre test : « Commencer » ne demande alors rien. */
    @Before fun noGameInProgress() = runBlocking {
        LibraryDatabase.get(InstrumentationRegistry.getInstrumentation().targetContext).autosaves().clear("engine")
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 30_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    private fun pieceLabels(word: String) =
        compose.onAllNodesWithContentDescription(word, substring = true, ignoreCase = true).fetchSemanticsNodes().size

    @Test fun aBlindGameFromTheHomeCardToTheSummary() {
        compose.onNodeWithTag("mode-blindfold").performScrollTo().performClick()
        awaitTag("aveugle-allHidden", 120_000)
        compose.onNodeWithTag("aveugle-allHidden").performScrollTo().performClick()
        compose.onNodeWithTag("commencer").performClick()

        awaitTag("coup-d-oeil", 60_000)
        // La partie doit être PRÊTE (le modèle Maia se charge au lancement) : un toucher avant est ignoré —
        // vu sur le Galaxy, le premier coup tenté se perdait.
        compose.waitUntil(60_000) {
            compose.onAllNodesWithText("À vous de jouer").fetchSemanticsNodes().size >= 2
        }
        compose.waitForIdle()
        assertTrue("à l'aveugle, aucune case ne nomme sa pièce", pieceLabels("pion") == 0)
        // « Tout caché » et non « Cases occupées » : pas même un disque. Le toucher sur la tuile a bien porté (le
        // petit plateau de la tuile l'avalait, 17/11/2026).
        assertTrue("« Tout caché » : aucun disque non plus", pieceLabels("pièce") == 0)

        // Un coup impossible le dit, sans être joué.
        compose.onNodeWithTag("case-e2").performClick()
        compose.onNodeWithTag("case-e5").performClick()
        awaitTag("coup-impossible", 3_000)

        // Un coup juste : départ, puis arrivée ; l'adversaire répond, et son coup s'écrit en gros.
        compose.onNodeWithTag("case-g1").performClick()
        compose.onNodeWithTag("case-f3").performClick()
        compose.waitUntil(60_000) {
            compose.onAllNodesWithText(" : ", substring = true).fetchSemanticsNodes().isNotEmpty()
        }

        // Coup d'œil : on maintient, et ça compte.
        compose.onNodeWithTag("coup-d-oeil").performTouchInput { longClick(durationMillis = 1_200) }
        // Le compteur est FONDU dans le bouton pour le lecteur d'écran : on le lit dans l'arbre non fusionné.
        compose.waitUntil(5_000) {
            compose.onAllNodesWithTag("coup-d-oeil-compte", useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()
        }

        // Abandon : les pièces reviennent, le bilan dit « À l'aveugle ».
        compose.onNodeWithTag("abandonner").performClick()
        awaitTag("abandonner-oui", 5_000)
        compose.onNodeWithTag("abandonner-oui").performClick()
        awaitTag("bilan-aveugle", 10_000)
        compose.waitForIdle()
        assertTrue("la partie finie, les pièces réapparaissent", pieceLabels("pion") > 0)
    }
}
