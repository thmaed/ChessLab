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
            while (dao.allOnce().firstOrNull { it.pgn == pgn }?.whiteAccuracy == null) delay(500)
        }
        val record = dao.allOnce().first { it.pgn == pgn }
        assertNotNull(record.whiteAccuracy)
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
}
