package com.chesslab

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import com.chesslab.puzzles.OwnPuzzle
import com.chesslab.puzzles.PuzzleFilter
import com.chesslab.puzzles.PuzzleScreen
import com.chesslab.puzzles.PuzzleSource
import com.chesslab.puzzles.PuzzleViewModel
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Le thème du puzzle (« MAT », « FOURCHETTE »…) est un indice : le réglage « Afficher le
 * thème du puzzle » le masque. Retour de Ron (08/11/2026). Pendant du réglage iOS
 * `showPuzzleTheme`.
 */
@RunWith(AndroidJUnit4::class)
class PuzzleThemeSettingTest {

    @get:Rule val compose = createComposeRule()

    private val app get() = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application
    private val db get() = LibraryDatabase.get(app)

    @Before fun basePropre() = runBlocking {
        db.ownPuzzles().clear()
        db.puzzleProgress().clear()
        db.ownPuzzles().insert(
            OwnPuzzle(
                uid = "test-theme", fen = "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1", playedSan = "Kf1",
                solution = "a1a8", theme = "checkmate", rating = 0,
                createdAt = System.currentTimeMillis(), sourcePgn = "",
            )
        )
    }

    @After fun reglageRestaure() {
        SettingsStore.setShowPuzzleTheme(app, true)
    }

    private fun themeLabelShown(label: String) =
        compose.onAllNodesWithText(label).fetchSemanticsNodes().isNotEmpty()

    @Test fun leThemeSeMasqueEtSeReaffiche() {
        lateinit var model: PuzzleViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = PuzzleViewModel(app) }
        compose.setContent { PuzzleScreen(filter = PuzzleFilter(source = PuzzleSource.ownGames), model = model) }
        compose.waitUntil(30_000) { model.ui.puzzle?.id == "test-theme" && !model.ui.loading }
        val label = app.getString(model.ui.puzzle!!.themeLabel).uppercase()

        SettingsStore.setShowPuzzleTheme(app, true)
        compose.waitUntil(5_000) { themeLabelShown(label) }

        SettingsStore.setShowPuzzleTheme(app, false)
        compose.waitUntil(5_000) { !themeLabelShown(label) }
        assertTrue("le thème « $label » reste masqué", !themeLabelShown(label))

        SettingsStore.setShowPuzzleTheme(app, true)
        compose.waitUntil(5_000) { themeLabelShown(label) }
    }
}
