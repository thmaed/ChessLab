package com.chesslab

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.click
import androidx.compose.ui.test.isEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.printToLog
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Visualisation de bout en bout (18/11/2026). Pendant de `VisualizationUITests` (iOS) : la tuile de l'accueil, les
 * deux marches, dix réponses au hasard, le bilan ; puis le chrono par question qui tranche seul.
 */
@RunWith(AndroidJUnit4::class)
class VisualizationTest {
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun awaitTag(tag: String, timeoutMs: Long = 20_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    /** Le texte d'un nœud, ou "" s'il vient de disparaître (la série peut finir entre deux lectures). */
    private fun text(tag: String): String =
        compose.onAllNodesWithTag(tag).fetchSemanticsNodes().firstOrNull()
            ?.config?.getOrNull(SemanticsProperties.Text)?.joinToString("") ?: ""

    private val activeChoice = SemanticsMatcher("un choix") {
        it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith("choix-") == true
    } and isEnabled()

    /** Répond : le premier choix actif, ou le milieu du plateau pour « Touchez… ». */
    private fun answerCurrent() {
        compose.waitForIdle()
        val choices = compose.onAllNodes(activeChoice).fetchSemanticsNodes()
        if (choices.isNotEmpty()) {
            compose.onAllNodes(activeChoice)[0].performClick()
        } else {
            compose.onNodeWithTag("visualisation-plateau").performTouchInput { click(center) }
        }
    }

    @Test fun aSeriesFromTheHomeTileToTheSummary() {
        awaitTag("mode-visualization", 120_000)
        compose.onNodeWithTag("mode-visualization").performScrollTo().performClick()
        awaitTag("visualisation-commencer")
        val lines = compose.onAllNodesWithTag("marche-lines").fetchSemanticsNodes().first()
        if (lines.config.getOrNull(SemanticsProperties.Selected) != true) compose.onNodeWithTag("marche-lines").performClick()
        compose.onNodeWithTag("marche-lines").assertIsSelected()
        compose.onNodeWithTag("longueur-ten").performScrollTo().performClick()
        compose.onNodeWithTag("chrono-sans").performScrollTo().performClick()
        compose.onNodeWithTag("visualisation-commencer").performClick()

        awaitTag("visualisation-question", 5_000)
        assertTrue(text("visualisation-progression") == "1 / 10")
        for (index in 0 until 10) {
            answerCurrent()
            // Un juste ne reste qu'un instant : on attend la question suivante, ou le bilan.
            val next = "${index + 2} / 10"
            runCatching {
                compose.waitUntil(5_000) {
                    compose.onAllNodesWithTag("visualisation-bilan").fetchSemanticsNodes().isNotEmpty() ||
                        (compose.onAllNodesWithTag("visualisation-progression").fetchSemanticsNodes().isNotEmpty() &&
                            text("visualisation-progression") == next)
                }
            }.onFailure {
                compose.onRoot().printToLog("VISU-DEBUG")
                throw it
            }
        }
        awaitTag("visualisation-bilan", 5_000)
        val score = text("visualisation-bilan")
        assertTrue("dix questions posées : $score", score.endsWith("/ 10"))
        val correct = score.substringBefore(" ").toInt()

        compose.onNodeWithTag("visualisation-reglages").performClick()
        awaitTag("visualisation-commencer")
        if (correct < 10) awaitTag("a-revoir", 3_000)

        // Chrono par question : sans réponse, le temps tranche.
        compose.onNodeWithTag("chrono-5").performScrollTo().performClick()
        compose.onNodeWithTag("visualisation-commencer").performClick()
        compose.waitUntil(16_000) {
            compose.onAllNodesWithText("Temps écoulé", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("visualisation-arreter").performClick()
        awaitTag("visualisation-bilan", 5_000)
        assertTrue(text("visualisation-bilan").startsWith("0 /"))

        // Le retour (flèche de la barre), d'une série en cours, mène aux réglages du module, pas à l'accueil.
        compose.onNodeWithTag("visualisation-reglages").performClick()
        awaitTag("visualisation-commencer")
        compose.onNodeWithTag("visualisation-commencer").performClick()
        awaitTag("visualisation-question", 5_000)
        compose.onNodeWithTag("retour").performClick()
        awaitTag("visualisation-commencer", 5_000)
        assertTrue("pas à l'accueil", compose.onAllNodesWithTag("mode-visualization").fetchSemanticsNodes().isEmpty())

        // Réglages rendus tels qu'un joueur les trouverait.
        compose.onNodeWithTag("chrono-sans").performScrollTo().performClick()
    }

    /** Lot 2 : les marches 3 et 4 seules ; chaque question met en scène son trajet ou sa position. */
    @Test fun piecesAndPositionSteps() {
        awaitTag("mode-visualization", 120_000)
        compose.onNodeWithTag("mode-visualization").performScrollTo().performClick()
        awaitTag("visualisation-commencer")
        fun selected(tag: String) =
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().first().config.getOrNull(SemanticsProperties.Selected) == true
        for (step in listOf("pieces", "position")) {
            if (!selected("marche-$step")) compose.onNodeWithTag("marche-$step").performScrollTo().performClick()
        }
        for (step in listOf("squares", "lines")) {
            if (selected("marche-$step")) compose.onNodeWithTag("marche-$step").performScrollTo().performClick()
        }
        assertTrue(selected("marche-pieces") && selected("marche-position") && !selected("marche-squares"))
        compose.onNodeWithTag("longueur-ten").performScrollTo().performClick()
        compose.onNodeWithTag("chrono-sans").performScrollTo().performClick()
        compose.onNodeWithTag("visualisation-commencer").performClick()

        for (index in 0 until 10) {
            awaitTag("visualisation-scene", 5_000)
            answerCurrent()
            val next = "${index + 2} / 10"
            compose.waitUntil(5_000) {
                compose.onAllNodesWithTag("visualisation-bilan").fetchSemanticsNodes().isNotEmpty() ||
                    (compose.onAllNodesWithTag("visualisation-progression").fetchSemanticsNodes().isNotEmpty() &&
                        text("visualisation-progression") == next)
            }
        }
        awaitTag("visualisation-bilan", 5_000)

        // Réglages rendus : la marche 1 seule.
        compose.onNodeWithTag("visualisation-reglages").performClick()
        awaitTag("visualisation-commencer")
        compose.onNodeWithTag("marche-squares").performScrollTo().performClick()
        for (step in listOf("pieces", "position")) {
            if (selected("marche-$step")) compose.onNodeWithTag("marche-$step").performScrollTo().performClick()
        }
    }
}
