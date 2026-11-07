package com.chesslab

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.editor.PositionEditorScreen
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les sorties de l'éditeur (et du scanner, qui est l'éditeur pré-rempli).
 * Pendant de `PositionEditorView.Exit` côté iOS : l'écran AUTONOME propose
 * jouer, analyser et le départ du Laboratoire ; le réglage d'une partie, qui
 * n'attend qu'une position, n'a qu'un bouton.
 */
@RunWith(AndroidJUnit4::class)
class EditorExitsTest {

    @get:Rule val compose = createComposeRule()

    private val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    private fun count(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().size

    @Test fun lEcranAutonomeProposeTroisSortiesQuiPortentLaPosition() {
        var played: String? = null; var analysed: String? = null; var lab: String? = null
        compose.setContent {
            PositionEditorScreen(
                initialFen = start,
                onAnalyse = { analysed = it }, onPlay = { played = it }, onUseAsLabStart = { lab = it },
            )
        }
        for (tag in listOf("jouer", "analyser", "labo")) compose.onNodeWithTag(tag).performScrollTo().performClick()
        assertTrue(played!!.startsWith("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w"))
        assertEquals(played, analysed)
        assertEquals(played, lab)
    }

    @Test fun uneSeuleSortieSansLesAutres() {
        var analysed: String? = null
        compose.setContent { PositionEditorScreen(initialFen = start, onAnalyse = { analysed = it }) }
        assertEquals(0, count("jouer"))
        assertEquals(0, count("labo"))
        compose.onNodeWithTag("analyser").performScrollTo().performClick()
        assertTrue(analysed != null)
    }

    /** Une position illégale (ici, sans rois) ne part vers aucune des trois sorties. */
    @Test fun uneIllegalePositionGriseLesTroisSorties() {
        compose.setContent {
            PositionEditorScreen(initialFen = "8/8/8/8/8/8/8/8 w - - 0 1", onPlay = {}, onUseAsLabStart = {})
        }
        for (tag in listOf("jouer", "analyser", "labo")) compose.onNodeWithTag(tag).performScrollTo().assertIsNotEnabled()
    }

    @Test fun uneLegalePositionActiveLesTroisSorties() {
        compose.setContent { PositionEditorScreen(initialFen = start, onPlay = {}, onUseAsLabStart = {}) }
        for (tag in listOf("jouer", "analyser", "labo")) compose.onNodeWithTag(tag).performScrollTo().assertIsEnabled()
    }
}
