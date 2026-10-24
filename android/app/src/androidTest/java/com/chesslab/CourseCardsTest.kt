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
}
