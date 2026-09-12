package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.training.Fsrs
import com.chesslab.training.FsrsRating
import com.chesslab.training.OpeningProgress
import com.chesslab.training.OpeningReviewLog
import com.chesslab.transfer.TransferFile
import com.chesslab.transfer.TransferService
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Le transfert de bout en bout : la base, le fichier, et la base à nouveau.
 *
 * La fusion elle-même est prouvée sur la JVM ; ce qui se joue ici, c'est tout
 * ce qu'un test pur ne peut pas voir — la sérialisation gzip, les
 * `contentResolver`, et le fait que la progression revienne VRAIMENT après un
 * effacement complet.
 */
@RunWith(AndroidJUnit4::class)
class TransferTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val db get() = LibraryDatabase.get(context)
    private val fsrs = Fsrs()
    private val t0 = 1_700_000_000_000L

    private val e4 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
    private val e5 = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -"

    @Before fun cleanSlate() = runBlocking {
        db.training().clearProgress()
        db.training().clearLogs()
    }

    /** Écrit une révision comme le fait l'app : le journal ET l'état. */
    private suspend fun review(fen: String, rating: FsrsRating, at: Long) {
        val existing = db.training().progress(fen) ?: OpeningProgress(fenKey = fen)
        val outcome = fsrs.review(existing.card, rating, at)
        db.training().put(existing.applying(outcome))
        db.training().log(
            OpeningReviewLog(
                fenKey = fen, ratingRaw = rating.raw, reviewedAt = outcome.reviewedAt,
                elapsedDays = outcome.elapsedDays, scheduledDays = outcome.scheduledDays,
                stabilityAfter = outcome.stabilityAfter,
            )
        )
    }

    private fun tempFile(name: String) = File(context.cacheDir, name).apply { delete() }

    @Test fun uneProgressionEffaceeRevientIntacteApresImport() = runBlocking {
        review(e4, FsrsRating.good, t0)
        review(e5, FsrsRating.again, t0 + Fsrs.DAY_MS)
        review(e4, FsrsRating.hard, t0 + 3 * Fsrs.DAY_MS)
        val before = db.training().allProgress().associateBy { it.fenKey }
        assertEquals(2, before.size)

        val file = tempFile("aller.clab")
        val saved = TransferService.export(context, android.net.Uri.fromFile(file))
        assertTrue("export échoué : ${saved.exceptionOrNull()}", saved.isSuccess)
        assertTrue("le fichier devrait exister et ne pas être vide", file.length() > 0)

        // On efface TOUT, comme un téléphone neuf.
        db.training().clearProgress()
        db.training().clearLogs()
        assertTrue(db.training().allProgress().isEmpty())

        val summary = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        assertEquals(3, summary.newReviews)

        val after = db.training().allProgress().associateBy { it.fenKey }
        assertEquals(before.keys, after.keys)
        for (key in before.keys) {
            assertEquals("stabilité de $key", before.getValue(key).stability, after.getValue(key).stability, 1e-9)
            assertEquals("répétitions de $key", before.getValue(key).reps, after.getValue(key).reps)
            assertEquals("échéance de $key", before.getValue(key).dueAt, after.getValue(key).dueAt)
        }
    }

    @Test fun reimporterLeMemeFichierNeChangeRien() = runBlocking {
        review(e4, FsrsRating.good, t0)
        val file = tempFile("deuxfois.clab")
        TransferService.export(context, android.net.Uri.fromFile(file)).getOrThrow()

        val first = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        val second = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        assertEquals(0, first.newReviews)     // on a déjà tout : rien de neuf
        assertEquals(0, second.newReviews)
        assertEquals(1, db.training().allLogs().size)
    }

    @Test fun lesDeuxJournauxSeReunissentEtLEtatSuit() = runBlocking {
        // L'appareil B a révisé la même position, PLUS TÔT. Après fusion,
        // l'état doit compter les deux révisions.
        review(e4, FsrsRating.good, t0 + 5 * Fsrs.DAY_MS)
        val local = db.training().progress(e4)!!
        assertEquals(1, local.reps)

        val other = TransferFile(
            exportedAt = t0, device = "autre",
            reviewLog = listOf(TransferFile.LogEntry("venu-d-ailleurs", e4, 3, t0, 0.0, 1.0, 1.0)),
            games = emptyList(), puzzlesAttempted = 0, puzzlesSolved = 0,
        )
        val file = tempFile("autre.clab")
        file.writeText(TransferFile.encode(other))   // en clair : l'import doit l'accepter aussi

        val summary = TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()
        assertEquals(1, summary.newReviews)
        assertEquals(2, db.training().progress(e4)!!.reps)
        assertEquals(2, db.training().allLogs().size)
    }

    @Test fun lesPartiesVoyagentSansDoublon() = runBlocking {
        val record = GameRecord(
            playedAt = t0, white = "Vous", black = "Lena", result = "1-0",
            source = "engine", moveCount = 40, pgn = "1. e4 e5",
        )
        db.games().insert(record)
        val countBefore = db.games().count()

        val file = tempFile("parties.clab")
        TransferService.export(context, android.net.Uri.fromFile(file)).getOrThrow()
        TransferService.import(context, android.net.Uri.fromFile(file)).getOrThrow()

        assertEquals("la partie ne doit pas être dupliquée", countBefore, db.games().count())
    }

    @Test fun unFichierEtrangerEstRefuseSansRienCasser() = runBlocking {
        review(e4, FsrsRating.good, t0)
        val file = tempFile("etranger.txt")
        file.writeText("ceci n'est pas un fichier de transfert")

        val result = TransferService.import(context, android.net.Uri.fromFile(file))
        assertTrue("l'import aurait dû échouer proprement", result.isFailure)
        assertEquals("la progression doit être intacte", 1, db.training().allProgress().size)
    }
}
