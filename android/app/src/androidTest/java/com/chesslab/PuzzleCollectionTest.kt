package com.chesslab

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.RuleChain
import org.junit.runner.RunWith

/**
 * Les collections de puzzles importées, de bout en bout : coller un PGN → la
 * collection apparaît → on la travaille en série → en programme Woodpecker →
 * on la supprime. Pendant de `PuzzleCollectionUITests` (iOS).
 *
 * Le choix de FICHIERS passe par le sélecteur du système, que ce test ne pilote
 * pas : il passe par la zone de collage.
 */
@RunWith(AndroidJUnit4::class)
class PuzzleCollectionTest {
    private val compose = createAndroidComposeRule<MainActivity>()

    @get:Rule val rules: RuleChain = RuleChain.outerRule(LanguageRule()).around(compose)

    private val name = "Mats test"

    /**
     * Deux mats en deux du couloir, et une partie dont le FEN est illisible. Chacun
     * commence par sa PRÉPARATION, le coup adverse a6, joué d'avance.
     */
    private val pgn = listOf(
        "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22\"]", "22...a6 23. Re8+ Rxe8 24. Rxe8#", "",
        "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 23\"]", "23...a6 24. Re8+ Rxe8 25. Rxe8#", "",
        "[FEN \"pas une position\"]", "1. e4",
    ).joinToString("\n")

    private val db get() = LibraryDatabase.get(InstrumentationRegistry.getInstrumentation().targetContext)

    /** Base vierge : un essai précédent ne doit rien laisser derrière lui. */
    @Before fun cleanSlate() = runBlocking {
        db.importedPuzzles().all().map { it.collection }.distinct().forEach {
            com.chesslab.puzzles.PuzzleCollectionStore.delete(db.importedPuzzles(), it)
        }
        db.woodpecker().clear()
    }

    private fun awaitTag(tag: String, timeoutMs: Long = 30_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    @Test fun aCollectionCanBeImportedPracticedWorkedAsAProgrammeAndDeleted() {
        compose.onNodeWithTag("mode-puzzles").performScrollTo().performClick()
        awaitTag("puzzleImportRow", 15_000)
        compose.onNodeWithTag("puzzleImportRow").performScrollTo().performClick()

        awaitTag("puzzleImportName")
        compose.onNodeWithTag("puzzleImportName").performTextInput(name)
        compose.onNodeWithTag("puzzleImportText").performTextInput(pgn)
        compose.onNodeWithTag("puzzleImportPasted").performScrollTo().performClick()

        // Le bilan : deux puzzles ajoutés, une partie écartée.
        awaitTag("puzzleImportReport")
        compose.waitUntil(10_000) { compose.onAllNodesWithText("2 puzzles", substring = true).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("puzzleImportClose").performClick()

        // La collection est là, avec son compte.
        awaitTag("collection-$name", 10_000)
        assertEquals(2, runBlocking { db.importedPuzzles().countIn(name) })

        // En série : l'écran de résolution s'ouvre.
        compose.onNodeWithTag("collection-$name").performScrollTo().performClick()
        awaitTag("indice", 20_000)
        compose.onNodeWithTag("retour").performClick()

        // En programme Woodpecker : TOUTE la collection (2 puzzles).
        awaitTag("collectionMenu-$name", 10_000)
        compose.onNodeWithTag("collectionMenu-$name").performScrollTo().performClick()
        compose.onNodeWithTag("collection-woodpecker").performClick()
        awaitTag("woodpecker-chrono", 30_000)
        compose.waitUntil(10_000) { compose.onAllNodesWithText("1/2", substring = true).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("retour").performClick()

        // On arrête le programme, puis on supprime la collection.
        awaitTag("woodpecker-arreter", 15_000)
        compose.onNodeWithTag("woodpecker-arreter").performScrollTo().performClick()
        awaitTag("woodpecker-arreter-oui")
        compose.onNodeWithTag("woodpecker-arreter-oui").performClick()

        compose.onNodeWithTag("collectionMenu-$name").performScrollTo().performClick()
        compose.onNodeWithTag("collection-supprimer").performClick()
        awaitTag("collection-supprimer-oui")
        compose.onNodeWithTag("collection-supprimer-oui").performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("collection-$name").fetchSemanticsNodes().isEmpty() }
        assertTrue(runBlocking { db.importedPuzzles().countIn(name) } == 0)
    }
}
