package com.chesslab

import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Les migrations : v3 → v4 (identifiants stables du journal) et v4 → v5 (les
 * puzzles tirés de vos propres parties). Une base déjà remplie doit traverser
 * les deux sans rien perdre — une progression FSRS ne se reconstruit pas.
 *
 * Ce test existe pour une raison précise. La base garde un filet destructeur
 * pour qu'une base corrompue n'empêche pas l'app de démarrer — mais ce filet
 * EFFACERAIT une progression FSRS, qui ne se reconstruit pas. Il faut donc
 * prouver qu'on ne tombe jamais dedans : que la vraie migration marche, et
 * qu'elle garde tout.
 */
@RunWith(AndroidJUnit4::class)
class MigrationTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val name = "migration-v3.db"

    /** Recrée une base telle que la v3 l'écrivait, et y met des données. */
    private fun seedVersion3(): File {
        val file = context.getDatabasePath(name)
        file.parentFile?.mkdirs()
        file.delete()
        File("${file.path}-wal").delete()
        File("${file.path}-shm").delete()

        val db = SQLiteDatabase.openOrCreateDatabase(file, null)
        db.execSQL(
            """
            CREATE TABLE games (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                played_at INTEGER NOT NULL, white TEXT NOT NULL, black TEXT NOT NULL,
                result TEXT NOT NULL, source TEXT NOT NULL, variant TEXT,
                move_count INTEGER NOT NULL, pgn TEXT NOT NULL)
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE autosaves (
                mode TEXT PRIMARY KEY NOT NULL, saved_at INTEGER NOT NULL, moves TEXT NOT NULL,
                opponent_id TEXT, level REAL NOT NULL, label TEXT NOT NULL)
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE opening_progress (
                fen_key TEXT PRIMARY KEY NOT NULL, stability REAL NOT NULL, difficulty REAL NOT NULL,
                state_raw INTEGER NOT NULL, reps INTEGER NOT NULL, lapses INTEGER NOT NULL,
                last_reviewed_at INTEGER, due_at INTEGER, first_seen_at INTEGER,
                updated_at INTEGER NOT NULL)
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE opening_review_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                fen_key TEXT NOT NULL, rating_raw INTEGER NOT NULL, reviewed_at INTEGER NOT NULL,
                elapsed_days REAL NOT NULL, scheduled_days REAL NOT NULL, stability_after REAL NOT NULL)
            """.trimIndent()
        )
        db.execSQL(
            "INSERT INTO games (played_at, white, black, result, source, move_count, pgn) " +
                "VALUES (1700000000000, 'Vous', 'Lena', '1-0', 'engine', 40, '1. e4 e5')"
        )
        db.execSQL(
            "INSERT INTO opening_progress VALUES ('fen-a', 3.17, 5.0, 2, 2, 0, 1700000000000, 1700086400000, 1699900000000, 1700000000000)"
        )
        db.execSQL(
            "INSERT INTO opening_review_log (fen_key, rating_raw, reviewed_at, elapsed_days, scheduled_days, stability_after) " +
                "VALUES ('fen-a', 3, 1700000000000, 0.0, 1.0, 0.4)"
        )
        db.execSQL(
            "INSERT INTO opening_review_log (fen_key, rating_raw, reviewed_at, elapsed_days, scheduled_days, stability_after) " +
                "VALUES ('fen-a', 2, 1700086400000, 1.0, 2.0, 1.18)"
        )
        db.version = 3
        db.close()
        return file
    }

    @Test fun laMigrationGardeToutEtDonneDesIdentifiants() = runBlocking {
        seedVersion3()

        val db = Room.databaseBuilder(context, LibraryDatabase::class.java, name)
            // La liste de l'APP, et pas une copie : une copie prend du retard,
            // et le schéma neuf passe alors par le filet destructeur en silence.
            .addMigrations(*LibraryDatabase.ALL_MIGRATIONS)
            .build()
        try {
            // Rien n'a disparu.
            assertEquals(1, db.games().count())
            assertEquals(1, db.training().allProgress().size)
            val logs = db.training().allLogs()
            assertEquals(2, logs.size)

            // La progression est INTACTE, au chiffre près.
            val progress = db.training().progress("fen-a")!!
            assertEquals(3.17, progress.stability, 1e-9)
            assertEquals(2, progress.reps)
            assertEquals(1_700_086_400_000L, progress.dueAt)

            // Et chaque ligne a désormais son identité, toutes distinctes.
            assertTrue("les identifiants doivent être remplis", logs.all { it.uid.isNotBlank() })
            assertEquals("et distincts", 2, logs.map { it.uid }.toSet().size)
            assertTrue("les parties aussi", db.games().allOnce().all { it.uid.isNotBlank() })

            // La table v5 existe et s'écrit : sans elle, « créer des puzzles
            // depuis les erreurs » planterait sur une base migrée depuis v3.
            assertEquals(0, db.ownPuzzles().count())
            db.ownPuzzles().insert(
                com.chesslab.puzzles.OwnPuzzle(
                    uid = "p1", fen = "6k1/8/8/3R4/8/4n3/6PP/6K1 b - - 0 1",
                    playedSan = "Rd5", solution = "e3d5", theme = "hangingPiece",
                    rating = 0, createdAt = 1_700_000_000_000L, sourcePgn = "1. e4 e5",
                )
            )
            assertEquals(1, db.ownPuzzles().count())
            assertEquals(1, db.ownPuzzles().countFor("6k1/8/8/3R4/8/4n3/6PP/6K1 b - - 0 1"))
        } finally {
            db.close()
            context.deleteDatabase(name)
        }
    }
}
