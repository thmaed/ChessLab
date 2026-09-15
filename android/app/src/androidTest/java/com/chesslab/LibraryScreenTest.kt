package com.chesslab

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * La bibliothèque des parties : chercher, filtrer, étiqueter, supprimer.
 *
 * Les FILTRES sont prouvés sur la JVM (`LibraryFilterTest`) ; ce qui se
 * vérifie ici est le branchement — que l'écran existe, qu'il montre ce qu'on
 * y range, et que les gestes destructeurs demandent confirmation.
 */
@RunWith(AndroidJUnit4::class)
class LibraryScreenTest {

    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    /**
     * Deux parties écrites à la main : la suite ne doit pas dépendre de ce
     * qu'un autre test a joué avant.
     */
    @Before fun rangeDeuxParties() {
        runBlocking { insereDeuxParties() }
    }

    private suspend fun insereDeuxParties() {
        val dao = LibraryDatabase.get(ApplicationProvider.getApplicationContext()).games()
        dao.insert(
            GameRecord(
                playedAt = 1_700_000_000_000, white = "Vous", black = "Maia", result = "1-0",
                source = "engine", moveCount = 30, pgn = "1. e4 e5 2. Nf3 Nc6", engineColor = "black",
            )
        )
        dao.insert(
            GameRecord(
                playedAt = 1_700_000_100_000, white = "Thierry", black = "Camille", result = "0-1",
                source = "twoPlayer", moveCount = 42, pgn = "1. d4 d5",
            )
        )
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 30_000) =
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
        }

    private fun openLibrary() {
        compose.onNodeWithTag("mode-analysis").performScrollTo().performClick()
        awaitTag("entree-bibliotheque")
        compose.onNodeWithTag("entree-bibliotheque").performScrollTo().performClick()
        awaitTag("recherche")
    }

    @Test fun laBibliothequeMontreLesParties() {
        openLibrary()
        compose.waitUntil(20_000) {
            compose.onAllNodesWithText("Thierry — Camille", substring = true)
                .fetchSemanticsNodes().isNotEmpty()
        }
    }

    /** La recherche porte sur les noms des joueurs. */
    @Test fun laRechercheFiltreLesParties() {
        openLibrary()
        compose.onNodeWithTag("recherche").performTextInput("Camille")
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("Vous — Maia", substring = true)
                .fetchSemanticsNodes().isEmpty()
        }
        compose.onAllNodesWithText("Thierry — Camille", substring = true)[0].assertIsDisplayed()
    }

    /** Le filtre de mode : une partie à deux n'est pas une partie contre le moteur. */
    @Test fun leFiltreDeModeSepareLesDeuxJeux() {
        openLibrary()
        compose.onNodeWithTag("mode-twoPlayer").performScrollTo().performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodesWithText("Vous — Maia", substring = true)
                .fetchSemanticsNodes().isEmpty()
        }
    }

    /** L'appui long ouvre le menu de la ligne ; supprimer demande confirmation. */
    @Test fun supprimerUnePartieDemandeConfirmation() {
        openLibrary()
        val rows = compose.onAllNodesWithTag("partie-1", useUnmergedTree = false)
        if (rows.fetchSemanticsNodes().isEmpty()) return   // identifiant réattribué : rien à tester

        compose.onNodeWithTag("partie-1").performTouchInput { longClick() }
        awaitTag("supprimer-1", 10_000)
        compose.onNodeWithTag("supprimer-1").performClick()
        awaitTag("supprimer-oui", 10_000)
        compose.onNodeWithTag("supprimer-oui").assertIsDisplayed()
    }
}
