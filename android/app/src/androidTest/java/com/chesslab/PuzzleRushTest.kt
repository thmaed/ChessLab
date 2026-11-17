package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.puzzles.PuzzleRushViewModel
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * « Contre la montre » de bout en bout (17/11/2026) : la carte, la règle, le décompte, le plateau, le
 * chrono, le bilan, le retour. Pendant de `PuzzleRushUITests` (iOS). La série est raccourcie à 6 s.
 */
@RunWith(AndroidJUnit4::class)
class PuzzleRushTest {
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    @Before fun shortRun() { PuzzleRushViewModel.durationOverrideMs = 6_000 }
    @After fun normalRun() { PuzzleRushViewModel.durationOverrideMs = null }

    private fun awaitTag(tag: String, timeoutMs: Long = 30_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    @Test fun aRunGoesFromTheRuleToTheSummaryAndBack() {
        compose.onNodeWithTag("mode-puzzles").performScrollTo().performClick()
        awaitTag("serie-contre-la-montre", 15_000)
        compose.onNodeWithTag("serie-contre-la-montre").performScrollTo().performClick()

        awaitTag("rushRule")
        // Le lot se prépare (une passe sur la bibliothèque) : « Commencer » tourne puis répond.
        val start = System.currentTimeMillis()
        compose.waitUntil(30_000) {
            compose.onNodeWithTag("rushStart").performClick()
            compose.onAllNodesWithTag("rushCountdown").fetchSemanticsNodes().isNotEmpty()
        }
        android.util.Log.i("PuzzleRushTest", "lot prêt en ${System.currentTimeMillis() - start} ms")
        awaitTag("rushBoard", 10_000)
        awaitTag("rushClock")
        awaitTag("rushErrors")

        awaitTag("rushFinalScore", 25_000)
        awaitTag("rushAgain")
        compose.onNodeWithTag("rushDone").performClick()
        awaitTag("serie-contre-la-montre", 10_000)
    }
}
