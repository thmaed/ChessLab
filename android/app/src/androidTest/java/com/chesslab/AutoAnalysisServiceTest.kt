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
}
