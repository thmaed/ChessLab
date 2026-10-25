package com.chesslab

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
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

/** C5 : les cartes des ouvertures et des finales portent une vignette de plateau. Pendant de l'écran iOS. */
@RunWith(AndroidJUnit4::class)
class CourseCardsTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private fun hasTagPrefix(prefix: String) = SemanticsMatcher("tag commence par $prefix") {
        SemanticsProperties.TestTag in it.config && it.config[SemanticsProperties.TestTag].startsWith(prefix)
    }

    private fun thumbnails() = compose.onAllNodes(hasTagPrefix("vignette-"), useUnmergedTree = true).fetchSemanticsNodes().size

    @Test fun lesCartesOntUneVignette() {
        for (mode in listOf("mode-openings", "mode-endgames")) {
            compose.waitUntil(20_000) { compose.onAllNodesWithTag(mode).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag(mode).performScrollTo().performClick()
            compose.waitUntil(20_000) { thumbnails() > 0 }
            assertTrue(thumbnails() > 0)
            compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        }
    }

    /** Le filtre « Classiques » ne garde que les ouvertures les plus courantes. */
    @Test fun leFiltreClassiquesReduitLaListe() {
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("mode-openings").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("mode-openings").performScrollTo().performClick()
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("menu-niveau").fetchSemanticsNodes().isNotEmpty() }
        fun total() = compose.onAllNodesWithTag("compte").fetchSemanticsNodes().sumOf {
            (if (SemanticsProperties.Text in it.config) it.config[SemanticsProperties.Text].joinToString("") else "").trim().toIntOrNull() ?: 0
        }
        val all = total()
        // Le niveau est un menu replié : on l'ouvre, puis on choisit.
        compose.onNodeWithTag("menu-niveau").performClick()
        compose.waitUntil(5_000) { compose.onAllNodesWithTag("filtre-classiques").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("filtre-classiques").performClick()
        compose.waitForIdle()
        val classics = total()
        assertTrue("classiques ($classics) < toutes ($all)", classics in 15..25 && classics < all)
    }
}
