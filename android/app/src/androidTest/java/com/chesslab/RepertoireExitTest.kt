package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.courses.CourseRepository
import com.chesslab.courses.RepertoireExitDetector
import com.chesslab.library.LibraryDatabase
import com.chesslab.training.FsrsRating
import com.chesslab.training.OpeningProgress
import com.chesslab.training.recordReview
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A3 sur appareil : les cours suivis se chargent depuis les assets et la base,
 * la sortie est repérée, et la position rejoint les révisions FSRS.
 * Pendant de `RepertoireExitServiceTests` (iOS).
 */
@RunWith(AndroidJUnit4::class)
class RepertoireExitTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val dao by lazy { LibraryDatabase.get(context).training() }

    @Before @After fun videLaProgression() = runBlocking {
        dao.clearProgress()
        dao.clearLogs()
    }

    @Test fun uneSortieDeRepertoireRejointLesRevisions() = runBlocking {
        val rootKey = CourseRepository.key(Position.standard)

        // Rien de travaillé : aucun cours suivi, donc aucune sortie.
        val none = RepertoireExitDetector.followedCourses(context, Piece.Color.white)
        assertTrue(none.first.isEmpty())

        // La position de départ a été révisée : les cours blancs qui la contiennent sont suivis.
        dao.put(OpeningProgress(fenKey = rootKey, reps = 3, dueAt = System.currentTimeMillis() + 86_400_000L))
        val (courses, studied) = RepertoireExitDetector.followedCourses(context, Piece.Color.white)
        assertTrue("des cours blancs doivent être suivis", courses.isNotEmpty())
        assertTrue(rootKey in studied)

        // 1.a3 n'est dans aucun cours : la sortie est repérée sur la position de départ.
        val board = Board(Position.standard.copy())
        val first = checkNotNull(board.move(Square("a2"), Square("a3")))
        val positions = listOf(Position.standard.copy(), board.position.copy())
        val exit = RepertoireExitDetector.firstExit(positions, listOf(first), Piece.Color.white, courses, studied)
        assertNotNull(exit)
        assertEquals(rootKey, exit!!.fenKey)
        assertEquals("a3", exit.playedSan)

        // Les Noirs n'ont pas de cours étudié : la même partie ne signale rien pour eux.
        val black = RepertoireExitDetector.followedCourses(context, Piece.Color.black)
        assertNull(RepertoireExitDetector.firstExit(positions, listOf(first), Piece.Color.black, black.first, black.second))

        // La position rejoint les révisions : une répétition de plus, et un journal.
        dao.recordReview(exit.fenKey, FsrsRating.again)
        val progress = checkNotNull(dao.progress(exit.fenKey))
        assertEquals(4, progress.reps)
        assertEquals(1, dao.allLogs().size)
    }
}
