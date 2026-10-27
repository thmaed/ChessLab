package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.analysis.PuzzleCandidate
import com.chesslab.analysis.PuzzleOffer
import com.chesslab.analysis.PuzzleOfferSheet
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Le récapitulatif de fin d'analyse : il liste ce qui peut être créé, et attend un accord ou un refus. */
@RunWith(AndroidJUnit4::class)
class PuzzleOfferSheetTest {

    @get:Rule val compose = createComposeRule()

    private val fen = "rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR b KQkq - 0 1"
    private val offer = PuzzleOffer(
        "k",
        listOf(
            PuzzleCandidate(fen, "Cf6", listOf("f3f7"), "checkmate", isMate = true, moveNumber = 4, blackToMove = false),
            PuzzleCandidate(fen, "Cxc2", listOf("d1d2"), "fork", isMate = false, moveNumber = 10, blackToMove = false),
        ),
    )

    @Test fun lePuzzleOfferSheetListeEtAttendUneDecision() {
        var accepted = 0
        var declined = 0
        compose.setContent {
            PuzzleOfferSheet(offer, onAccept = { accepted++ }, onDecline = { declined++ })
        }
        compose.waitUntil(10_000) { compose.onAllNodesWithTagCount("offre-puzzles") > 0 }
        compose.onNodeWithTag("offre-puzzles-creer").assertIsDisplayed()
        compose.onNodeWithTag("offre-puzzles-creer").performClick()
        assertEquals(1, accepted)
        assertEquals(0, declined)
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTagCount(tag: String) =
        onAllNodes(androidx.compose.ui.test.hasTestTag(tag)).fetchSemanticsNodes().size
}
