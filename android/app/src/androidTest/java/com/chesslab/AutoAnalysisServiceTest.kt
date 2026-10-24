package com.chesslab

import android.app.Application
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.analysis.AutoAnalysisService
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A1 (2.0) — le service d'analyse automatique, de bout en bout, sur l'appareil :
 * une partie rangée puis mise en file ressort avec son bilan chiffré.
 */
class AutoAnalysisServiceTest {

    @org.junit.Before fun reset() = runBlocking {
        // Dans une suite complète, les écrans précédents ont laissé l'app « en
        // arrière-plan » (l'analyse de fond s'y arrête) : on la remet au premier plan.
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
            AutoAnalysisService.setForeground(true)
            AutoAnalysisService.stop()
        }
        // Et on efface ce qu'un essai précédent interrompu aurait laissé dans la bibliothèque.
        val dao = LibraryDatabase.get(app).games()
        dao.allOnce().filter { it.white == "Vous" && it.black == "Ordinateur" && it.pgn.startsWith("[Event \"A") }
            .forEach { dao.delete(it.id) }
    }

    @org.junit.After fun cleanUp() = runBlocking {
        SettingsStore.setAutoAnalysis(app, "off")
        val dao = LibraryDatabase.get(app).games()
        dao.allOnce().filter { it.white == "Vous" && it.black == "Ordinateur" && it.pgn.startsWith("[Event \"A") }
            .forEach { dao.delete(it.id) }
        LibraryDatabase.get(app).ownPuzzles().clear()
    }

    private val app = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application
    private val pgn = "[Event \"A1\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 7. Qf3+ Ke6 8. Nc3 Ncb4 9. O-O c6 10. d4 1-0"

    @Test fun analyzesQueuedGameAndWritesMetrics() = runBlocking {
        val dao = LibraryDatabase.get(app).games()
        val id = dao.insert(
            GameRecord(
                playedAt = System.currentTimeMillis(), white = "Vous", black = "Ordinateur",
                result = "1-0", source = "engine", variant = null, moveCount = 19, pgn = pgn,
            )
        )
        SettingsStore.setAutoAnalysis(app, "on")
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) { AutoAnalysisService.enqueue(app, pgn) }
        assertEquals(1, AutoAnalysisService.queue.size)
        withTimeout(240_000) {
            // Le profil (A4) est rangé juste après les métriques : on attend les deux.
            while (dao.allOnce().firstOrNull { it.pgn == pgn }?.whitePhase == null) delay(500)
        }
        val record = dao.allOnce().first { it.pgn == pgn }
        assertNotNull(record.whiteAccuracy)
        // A4 : le profil de faiblesses est rangé avec les métriques.
        assertTrue(record.whitePhase!!.contains("o:"))
        assertNotNull(record.blackThemes)
        assertNotNull(record.openingName)
        withTimeout(10_000) { while (AutoAnalysisService.queue.isNotEmpty()) delay(200) }
        SettingsStore.setAutoAnalysis(app, "off")
        dao.allOnce().filter { it.pgn == pgn }.forEach { dao.delete(it.id) }
        Unit
    }

    /** A2 : le mat manqué de l'utilisateur (et lui seul) devient un puzzle « Mes parties ». */
    @Test fun createsOwnPuzzleFromMissedMate() = runBlocking {
        val missedMatePgn = "[Event \"A2\"]\n[Result \"0-1\"]\n\n1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. d3 Nxh5 5. Bxf7+ Ke7 6. Nc3 Nf4 0-1"
        val dao = LibraryDatabase.get(app).games()
        val puzzles = LibraryDatabase.get(app).ownPuzzles()
        puzzles.clear()   // build débogable : ses données ne sont que celles des essais
        dao.insert(
            GameRecord(
                playedAt = System.currentTimeMillis(), white = "Vous", black = "Ordinateur",
                result = "0-1", source = "engine", variant = null, moveCount = 12, pgn = missedMatePgn,
            )
        )
        SettingsStore.setAutoAnalysis(app, "on")
        val before = AutoAnalysisService.newPuzzleCount
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
            AutoAnalysisService.enqueue(app, missedMatePgn, chesskit.Piece.Color.white)
        }
        withTimeout(240_000) {
            while (AutoAnalysisService.queue.isEmpty()) delay(100)
            while (AutoAnalysisService.queue.isNotEmpty()) delay(500)
        }
        val created = AutoAnalysisService.newPuzzleCount - before
        assertTrue("1 à 3 puzzles, eu $created", created in 1..AutoAnalysisService.MAX_PUZZLES_PER_GAME)
        // Jamais depuis une position où les Noirs (l'ordinateur) avaient le trait.
        val own = puzzles.all()
        assertTrue(own.isNotEmpty() && own.all { it.fen.contains(" w ") })
        SettingsStore.setAutoAnalysis(app, "off")
        puzzles.clear()
        dao.allOnce().filter { it.pgn == missedMatePgn }.forEach { dao.delete(it.id) }
        Unit
    }

    /**
     * Le conflit de fin de partie : l'utilisateur ouvre un écran qui prend le
     * moteur pendant que l'arrière-plan travaille. L'écran doit l'obtenir vite,
     * et le service reprendre ensuite jusqu'au bout.
     */
    @Test fun yieldsEngineToUserThenResumes() = runBlocking {
        val gamePgn = "[Event \"A1c\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Bc5 5. Be3 Nxd4 6. Bxd4 Bxd4 7. Qxd4 Nf6 8. e5 Qe7 9. Be2 c5 10. exf6 Qxe2+ 11. Kxe2 cxd4 12. fxg7 Rg8 13. Rd1 d5 14. Rxd4 Be6 15. Nd2 Rc8 16. c3 Rxg7 17. g3 Rg5 18. Nf1 Ke7 1-0"
        val dao = LibraryDatabase.get(app).games()
        dao.insert(
            GameRecord(
                playedAt = System.currentTimeMillis(), white = "Vous", black = "Ordinateur",
                result = "1-0", source = "engine", variant = null, moveCount = 36, pgn = gamePgn,
            )
        )
        SettingsStore.setAutoAnalysis(app, "on")
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) { AutoAnalysisService.enqueue(app, gamePgn) }
        delay(3000)   // laisse l'arrière-plan s'engager dans la revue

        val start = System.currentTimeMillis()
        val identity = withTimeout(60_000) {
            com.chesslab.engine.EngineService.use(app) { com.chesslab.engine.EngineService.identity }
        }
        val waited = System.currentTimeMillis() - start
        assertNotNull("l'écran doit obtenir le moteur", identity)
        assertTrue("l'écran a attendu ${waited} ms", waited < 30_000)

        // Il l'a rendu : le service reprend et termine la partie.
        withTimeout(240_000) {
            while (dao.allOnce().firstOrNull { it.pgn == gamePgn }?.whiteAccuracy == null) delay(500)
        }
        SettingsStore.setAutoAnalysis(app, "off")
        dao.allOnce().filter { it.pgn == gamePgn }.forEach { dao.delete(it.id) }
        Unit
    }
}
