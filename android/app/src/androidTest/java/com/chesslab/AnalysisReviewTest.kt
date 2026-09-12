package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * La revue complète d'une partie : classer chaque coup, en tirer un bilan, puis
 * fabriquer des puzzles avec les fautes.
 *
 * Le test demande le MOTEUR, donc un appareil ; les fonctions pures du barème,
 * elles, se vérifient sur la JVM en deux secondes (voir `ClassificationTest`).
 */
@RunWith(AndroidJUnit4::class)
class AnalysisReviewTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /**
     * Les Blancs laissent passer un mat en un (4.Cf3 au lieu de Dxf7#) : la
     * position d'avant n'a qu'UN bon coup, ce qui en fait un puzzle net. Une
     * gaffe d'ouverture ordinaire n'en ferait pas — plusieurs défenses s'y
     * valent, et deux coups qui se valent ne font pas un puzzle.
     */
    private val missedMate = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Nf3 Nxh5"

    /**
     * La table part VIDE. La même position ne donne qu'un puzzle — c'est voulu,
     * pour que revoir deux fois une partie ne la double pas —, si bien qu'un
     * puzzle laissé par un essai précédent ferait échouer celui-ci pour une
     * raison qui n'a rien à voir avec le code testé.
     */
    @Before fun videLesPuzzlesMaison() = runBlocking {
        LibraryDatabase.get(ApplicationProvider.getApplicationContext()).ownPuzzles().clear()
    }



    private fun awaitTag(tag: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun awaitNoTag(tag: String, timeoutMs: Long = 300_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isEmpty()
        }

    private fun awaitText(text: String, timeoutMs: Long = 120_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text, substring = true, ignoreCase = true)
                .fetchSemanticsNodes().isNotEmpty()
        }

    /** Tout le texte porté par un nœud, y compris celui de ses enfants fusionnés. */
    private fun textOf(tag: String): String =
        compose.onNodeWithTag(tag)
            .fetchSemanticsNode()
            .let { node ->
                (listOf(node) + node.children).flatMap {
                    it.config.getOrElse(androidx.compose.ui.semantics.SemanticsProperties.Text) { emptyList() }
                }
            }
            .joinToString(" ")

    private fun loadGame() {
        compose.onNodeWithTag("mode-analysis").performScrollTo().performClick()
        compose.onNodeWithTag("entree-coller").performScrollTo().performClick()
        awaitTag("saisie")
        compose.onNodeWithTag("saisie").performScrollTo().performTextInput(missedMate)
        compose.onNodeWithTag("charger").performScrollTo().performClick()
        awaitTag("coup-0")
    }

    @Test fun laRevueClasseLesCoupsEtDonneUnePrecision() {
        loadGame()

        compose.onNodeWithTag("analyser-partie").performScrollTo().performClick()
        // La revue affiche sa progression, puis les deux précisions remplacent
        // la phrase d'invite.
        awaitTag("precision", 300_000)

        // Le bandeau ne suffit pas : il s'affiche aussi avec un bilan VIDE.
        // Ce qu'on veut, c'est un chiffre — la preuve que le moteur a répondu
        // sur les neuf positions et que la classification a tourné.
        val chiffres = textOf("precision")
        require(chiffres.contains("%") && chiffres.any { it.isDigit() }) {
            "précision attendue, obtenu « $chiffres »"
        }

        compose.onNodeWithTag("menu-analyse").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("bilan").performClick()
        awaitTag("feuille-bilan", 20_000)
        compose.onNodeWithTag("feuille-bilan").assertIsDisplayed()
    }

    @Test fun lesFautesDeviennentDesPuzzles() {
        loadGame()

        compose.onNodeWithTag("analyser-partie").performScrollTo().performClick()
        awaitTag("precision", 300_000)

        compose.onNodeWithTag("menu-analyse").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("creer-puzzles").performClick()
        awaitTag("puzzles-crees", 300_000)
        // Le mat manqué donne son puzzle : la boîte annonce un nombre, pas un
        // « aucune position ».
        val message = textOf("puzzles-crees")
        require(message.contains("1 puzzle")) { "la boîte annonce : « $message »" }
    }
}
