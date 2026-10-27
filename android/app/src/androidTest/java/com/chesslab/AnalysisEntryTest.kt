package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/** C6 : l'écran Analyser met la dernière partie en tête, avec ses deux gestes. Pendant de `AnalysisEntryUITests`. */
@RunWith(AndroidJUnit4::class)
class AnalysisEntryTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private val pgn = "[Event \"C6\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7# 1-0"

    @Before fun semeUnePartie() = runBlocking {
        LibraryDatabase.get(ApplicationProvider.getApplicationContext()).games().insert(
            GameRecord(playedAt = System.currentTimeMillis(), white = "C6Blanc", black = "C6Noir",
                result = "1-0", source = "twoPlayer", moveCount = 7, pgn = pgn)
        )
        Unit
    }

    @After fun nettoie() = runBlocking {
        val dao = LibraryDatabase.get(ApplicationProvider.getApplicationContext()).games()
        dao.allOnce().filter { it.white == "C6Blanc" }.forEach { dao.delete(it.id) }
    }

    @Test fun laCarteDeLaDernierePartieProposeAnalyse() {
        compose.waitUntil(20_000) { compose.onAllNodesWithTag("mode-analysis").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("mode-analysis").performScrollTo().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("entree-derniere").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("derniere-analyser").assertExists()
        compose.onNodeWithTag("entree-scanner").assertExists()
        compose.onNodeWithTag("entree-bibliotheque").assertExists()
        // « Mats manqués » n'a plus de bouton : tout passe par « Analyser ».
        assertEquals(0, compose.onAllNodesWithTag("derniere-mats").fetchSemanticsNodes().size)
        compose.onNodeWithTag("derniere-analyser").performClick()
        // L'écran d'analyse s'ouvre sur la partie : sa liste de coups apparaît.
        compose.waitUntil(30_000) { compose.onAllNodesWithTag("coup-0").fetchSemanticsNodes().isNotEmpty() }
    }
}
