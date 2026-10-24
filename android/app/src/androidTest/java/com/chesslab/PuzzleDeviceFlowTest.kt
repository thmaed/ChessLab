package com.chesslab

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import com.chesslab.puzzles.OwnPuzzle
import com.chesslab.puzzles.PuzzleDraw
import com.chesslab.puzzles.PuzzleFilter
import com.chesslab.puzzles.PuzzleOutcome
import com.chesslab.puzzles.PuzzleScreen
import com.chesslab.puzzles.PuzzleSource
import com.chesslab.puzzles.PuzzleViewModel
import com.chesslab.puzzles.WoodpeckerPlan
import com.chesslab.puzzles.WoodpeckerProgram
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les parcours de puzzles qu'on ne vérifiait qu'à la main (PARITE.md,
 * 23/10/2026) — joués ici sur l'appareil, coup par coup, à travers l'écran :
 *
 * - la série « Ratés » rejoue un puzzle raté, puis le retire une fois réussi ;
 * - un autre coup qui mate est accepté ;
 * - un cycle Woodpecker complet mène au bilan, puis au cycle suivant.
 */
@RunWith(AndroidJUnit4::class)
class PuzzleDeviceFlowTest {

    @get:Rule val compose = createComposeRule()

    private val app get() = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application
    private val db get() = LibraryDatabase.get(app)

    /** Base vierge : un essai précédent ne doit rien laisser derrière lui. */
    @Before fun basePropre() = runBlocking {
        db.ownPuzzles().clear()
        db.puzzleProgress().clear()
        db.woodpecker().clear()
    }

    private fun makeModel(): PuzzleViewModel {
        lateinit var model: PuzzleViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = PuzzleViewModel(app) }
        return model
    }

    private fun tap(from: String, to: String) {
        compose.onNodeWithTag("case-$from").performClick()
        compose.onNodeWithTag("case-$to").performClick()
        compose.waitForIdle()
    }

    /**
     * Deux mats du couloir (Ta8# et Tb8#) ; la solution enregistrée est Ta8#.
     * Raté une fois, il doit revenir dans « Ratés », y être réussi par l'AUTRE
     * mat, puis en sortir.
     */
    @Test fun laSerieRatesRejoueLePuzzleRateEtAccepteLAutreMat() {
        runBlocking {
            db.ownPuzzles().insert(
                OwnPuzzle(
                    uid = "test-couloir", fen = "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1", playedSan = "Kf1",
                    solution = "a1a8", theme = "checkmate", rating = 0,
                    createdAt = System.currentTimeMillis(), sourcePgn = "",
                )
            )
        }
        val model = makeModel()
        var filter by mutableFilter(PuzzleFilter(source = PuzzleSource.ownGames))
        compose.setContent { PuzzleScreen(filter = filter, model = model) }
        compose.waitUntil(30_000) { model.ui.puzzle?.id == "test-couloir" && !model.ui.loading }

        // Un coup qui ne mate pas, jusqu'à épuiser les essais du réglage.
        repeat(3) {
            if (model.ui.outcome == PuzzleOutcome.solving) tap("b1", "b7")
        }
        compose.waitUntil(10_000) { model.ui.outcome == PuzzleOutcome.failed }
        compose.waitUntil(10_000) { runBlocking { db.puzzleProgress().missedIds() }.contains("test-couloir") }

        // La série « Ratés » le ressert…
        compose.runOnIdle { filter = PuzzleFilter(missedOnly = true) }
        compose.waitUntil(60_000) {
            model.ui.puzzle?.id == "test-couloir" && model.ui.outcome == PuzzleOutcome.solving && !model.ui.loading
        }
        // … et l'AUTRE mat est juste.
        tap("b1", "b8")
        compose.waitUntil(10_000) { model.ui.outcome == PuzzleOutcome.solved }
        compose.waitUntil(10_000) { !runBlocking { db.puzzleProgress().missedIds() }.contains("test-couloir") }

        // Réussi, il quitte la série : plus rien de raté.
        compose.onNodeWithTag("suivant").performClick()
        compose.waitUntil(10_000) { model.ui.puzzle == null }
        // L'écran le DIT — il montrait l'ancien plateau sans un mot.
        compose.waitUntil(5_000) { compose.onAllNodesWithTag("serie-vide").fetchSemanticsNodes().isNotEmpty() }
        compose.waitUntil(5_000) {
            compose.onAllNodesWithText("Aucun puzzle raté", substring = true).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithText("No missed puzzles", substring = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    /**
     * Dix VRAIS puzzles de la bibliothèque, résolus coup par coup — ripostes du
     * moteur comprises — jusqu'au bilan du cycle, puis le cycle 2.
     */
    @Test fun unCycleWoodpeckerCompletMeneAuBilanPuisAuCycleSuivant() {
        val puzzles = runBlocking { PuzzleDraw.draw(app, PuzzleFilter(), own = emptyList(), count = 10) }
        assertEquals(10, puzzles.size)
        val plan = WoodpeckerPlan.start(puzzles.map { WoodpeckerPlan.Item.of(it) })!!
        val now = System.currentTimeMillis()
        val program = WoodpeckerProgram("test-woodpecker", now, now, "10 puzzles", plan.toJson())
        runBlocking { db.woodpecker().put(program) }

        val model = makeModel()
        compose.setContent { PuzzleScreen(woodpeckerId = program.id, model = model) }
        compose.waitUntil(30_000) { model.ui.woodpeckerPlan != null && model.ui.puzzle != null && !model.ui.loading }

        for (rank in 1..10) {
            val puzzle = model.ui.puzzle!!
            assertTrue("rang $rank", model.ui.woodpeckerPlan!!.currentCycle.attempts.size == rank - 1)
            assertTrue(compose.onAllNodesWithTag("passer").fetchSemanticsNodes().isEmpty())
            for (k in puzzle.solution.indices step 2) {
                val lan = puzzle.solution[k]
                tap(lan.substring(0, 2), lan.substring(2, 4))
                // La riposte du moteur, s'il y en a une, avant le coup suivant.
                if (k + 1 < puzzle.solution.size) {
                    val reply = puzzle.solution[k + 1]
                    compose.waitUntil(10_000) {
                        !model.ui.busy && model.ui.lastMove?.let { (a, b) -> a.notation + b.notation == reply.take(4) } == true
                    }
                }
            }
            compose.waitUntil(10_000) { model.ui.outcome == PuzzleOutcome.solved }
            if (rank < 10) {
                assertTrue(compose.onAllNodesWithTag("woodpecker-bilan").fetchSemanticsNodes().isEmpty())
                compose.onNodeWithTag("suivant").performClick()
                compose.waitUntil(10_000) { model.ui.outcome == PuzzleOutcome.solving }
            }
        }

        // Le bilan, puis le cycle 2 sur le même lot.
        compose.waitUntil(10_000) { compose.onAllNodesWithTag("woodpecker-bilan").fetchSemanticsNodes().isNotEmpty() }
        val finished = model.ui.woodpeckerPlan!!.currentCycle
        assertTrue(finished.isComplete)
        assertEquals(10, finished.solvedCount)
        compose.onNodeWithTag("suivant").performClick()
        compose.waitUntil(10_000) { model.ui.woodpeckerPlan?.currentCycle?.number == 2 && model.ui.outcome == PuzzleOutcome.solving }

        // Tout est écrit : rouvrir le programme le retrouverait au cycle 2.
        compose.waitUntil(10_000) { runBlocking { db.woodpecker().byId(program.id) }?.plan?.cycles?.size == 2 }
        val stored = runBlocking { db.woodpecker().byId(program.id) }!!.plan!!
        assertEquals(10, stored.cycles[0].solvedCount)
        assertFalse(stored.currentCycle.isComplete)
        // Et la répétition espacée n'a rien vu passer.
        assertTrue(runBlocking { db.puzzleProgress().all() }.isEmpty())
    }

    private fun mutableFilter(initial: PuzzleFilter) =
        androidx.compose.runtime.mutableStateOf(initial)

    /**
     * Un thème LONG avec ses deux pastilles : « ATTAQUE À LA DÉCOUVERTE »,
     * « Débutant », « Milieu de partie ». La ligne débordait, le score s'y
     * écrivait une lettre par ligne et l'en-tête prenait la moitié de l'écran :
     * plateau en bas, essais et indice hors champ (Galaxy A16, 24/10/2026).
     */
    @Test fun unThemeLongNeRepoussePasLePlateau() {
        val model = makeModel()
        val filter = PuzzleFilter(
            difficulty = com.chesslab.puzzles.DifficultyTier.beginner,
            phase = com.chesslab.puzzles.GamePhase.middlegame,
            theme = com.chesslab.puzzles.PuzzleThemeKind.discoveredAttack,
        )
        compose.setContent { PuzzleScreen(filter = filter, model = model) }
        compose.waitUntil(90_000) { model.ui.puzzle?.theme == "discoveredAttack" && !model.ui.loading }
        compose.waitForIdle()

        val screenHeight = compose.onRoot().fetchSemanticsNode().boundsInRoot.height
        // Le HAUT du plateau : a8 aux Blancs, h1 aux Noirs (plateau retourné).
        val boardTop = minOf(
            compose.onNodeWithTag("case-a8").fetchSemanticsNode().boundsInRoot.top,
            compose.onNodeWithTag("case-h1").fetchSemanticsNode().boundsInRoot.top,
        )
        assertTrue("le plateau commence trop bas : $boardTop sur $screenHeight", boardTop < screenHeight * 0.3f)
        compose.onNodeWithTag("indice").assertIsDisplayed()
    }

    /**
     * « À mon niveau » : la série ne contient que des puzzles dans la fenêtre de
     * cotes du joueur, et sa cote suit ses réussites (B3, 24/10/2026).
     */
    @Test fun laSerieAMonNiveauResteDansLaFenetreDeLaCote() {
        val window = com.chesslab.puzzles.PuzzleRating().window
        val model = makeModel()
        val filter = PuzzleFilter(ratingWindow = window)
        compose.setContent { PuzzleScreen(filter = filter, model = model) }
        compose.waitUntil(90_000) { model.ui.puzzle != null && !model.ui.loading }
        val puzzle = model.ui.puzzle!!
        assertTrue("cote ${puzzle.rating} hors de $window", puzzle.rating in window)

        // Le résoudre fait bouger la cote.
        val before = runBlocking { com.chesslab.settings.StatsStore.puzzleRating(app) }
        for (k in puzzle.solution.indices step 2) {
            val lan = puzzle.solution[k]
            tap(lan.substring(0, 2), lan.substring(2, 4))
            if (k + 1 < puzzle.solution.size) {
                val reply = puzzle.solution[k + 1]
                compose.waitUntil(10_000) {
                    !model.ui.busy && model.ui.lastMove?.let { (a, b) -> a.notation + b.notation == reply.take(4) } == true
                }
            }
        }
        compose.waitUntil(10_000) { model.ui.outcome == PuzzleOutcome.solved }
        compose.waitUntil(10_000) { runBlocking { com.chesslab.settings.StatsStore.puzzleRating(app) }.count == before.count + 1 }
        assertTrue(runBlocking { com.chesslab.settings.StatsStore.puzzleRating(app) }.rating > before.rating)
    }
}

