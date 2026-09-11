package com.chesslab.training

import com.chesslab.courses.Course
import com.chesslab.courses.CourseMove
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Porté d'`OpeningTrainingQueueTests.swift`. */
class TrainingQueueTest {

    private fun move(san: String, uci: String, to: String, main: Boolean = false, pop: Double? = null) =
        CourseMove(san, uci, to, if (main) "mainLine" else "sideline", null, null, pop)

    /** 1.e4 e5 2.Cf3 — un cours minuscule, des Blancs. */
    private val tiny = Course(
        id = "tiny", name = "Petit cours", summary = "", 
        rootFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -",
        chapters = emptyList(),
        positions = mapOf(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -" to listOf(
                move("e4", "e2e4", "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3", main = true),
                move("d4", "d2d4", "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3", pop = 0.3),
            ),
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3" to listOf(
                move("e5", "e7e5", "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6", main = true),
            ),
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6" to listOf(
                move("Nf3", "g1f3", "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -", main = true),
            ),
        ),
    )

    @Test fun `la ligne principale suit le rôle puis la popularité`() {
        val line = TrainingQueue.mainLine(tiny)
        assertEquals(listOf("e4", "e5", "Nf3"), line.map { it.second.san })
    }

    @Test fun `un cycle de transposition ne fait pas tourner en rond`() {
        val a = "8/8/8/8/8/8/8/K6k w - -"
        val b = "8/8/8/8/8/8/8/K6k b - -"
        val loop = tiny.copy(
            rootFEN = a,
            positions = mapOf(
                a to listOf(move("x", "a1a2", b, main = true)),
                b to listOf(move("y", "h1h2", a, main = true)),
            ),
        )
        assertTrue(TrainingQueue.mainLine(loop).size <= 2)
    }

    @Test fun `seules les positions au trait du camp d'étude sont entraînables`() {
        val white = TrainingQueue.trainableCards(tiny, "white").map { it.expectedSan }.sorted()
        assertEquals(listOf("Nf3", "e4"), white)
        assertEquals(listOf("e5"), TrainingQueue.trainableCards(tiny, "black").map { it.expectedSan })
    }

    @Test fun `la file du jour sert les dues d'abord, la plus en retard en tête`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val now = 1_700_000_000_000L
        val jour = Fsrs.DAY_MS
        val progress = mapOf(
            cards[0].fenKey to ProgressSnapshot(now - 3 * jour, 0, 5.0, 2),
            cards[1].fenKey to ProgressSnapshot(now - 10 * jour, 0, 5.0, 2),
        )
        val queue = TrainingQueue.daily(cards, progress, now)
        assertEquals(listOf(cards[1].fenKey, cards[0].fenKey), queue.map { it.fenKey })
    }

    @Test fun `une position pas encore due ne revient pas`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val now = 1_700_000_000_000L
        val progress = cards.associate { it.fenKey to ProgressSnapshot(now + 5 * Fsrs.DAY_MS, 0, 9.0, 1) }
        assertTrue(TrainingQueue.daily(cards, progress, now).isEmpty())
    }

    @Test fun `un enregistrement sans échéance est traité comme neuf`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val now = 1_700_000_000_000L
        val progress = mapOf(cards[0].fenKey to ProgressSnapshot(null, 0, 0.0, 0))
        assertEquals(cards.size, TrainingQueue.daily(cards, progress, now).size)
    }

    @Test fun `le quota de neuves est respecté`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        assertEquals(1, TrainingQueue.daily(cards, emptyMap(), 0L, newLimit = 1).size)
    }

    @Test fun `la file est dédoublonnée par clé FEN`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val doubled = cards + cards.map { it.copy(courseId = "autre") }
        assertEquals(cards.size, TrainingQueue.daily(doubled, emptyMap(), 0L).size)
    }

    @Test fun `les difficiles vont du plus raté au moins raté`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val progress = mapOf(
            cards[0].fenKey to ProgressSnapshot(null, 1, 4.0, 3),
            cards[1].fenKey to ProgressSnapshot(null, 5, 2.0, 7),
        )
        assertEquals(listOf(cards[1].fenKey, cards[0].fenKey),
            TrainingQueue.hardest(cards, progress).map { it.fenKey })
    }

    @Test fun `sans échec, rien n'est difficile`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val progress = cards.associate { it.fenKey to ProgressSnapshot(null, 0, 4.0, 3) }
        assertTrue(TrainingQueue.hardest(cards, progress).isEmpty())
    }

    @Test fun `une position ratée du premier coup compte comme difficile`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        // Ce que FSRS écrit pour un « encore » sur une carte neuve : zéro
        // rechute, mais l'état « apprentissage ».
        val neuve = ProgressSnapshot(null, 0, 0.40255, 1, FsrsState.learning)
        assertTrue(TrainingQueue.isHard(neuve))
        val progress = mapOf(cards[0].fenKey to neuve)
        assertEquals(listOf(cards[0].fenKey), TrainingQueue.hardest(cards, progress).map { it.fenKey })
    }

    @Test fun `une position acquise n'est pas difficile`() {
        assertTrue(!TrainingQueue.isHard(ProgressSnapshot(null, 0, 12.0, 4, FsrsState.review)))
    }

    @Test fun `une rechute passe devant une simple position en apprentissage`() {
        val cards = TrainingQueue.trainableCards(tiny, "white")
        val progress = mapOf(
            cards[0].fenKey to ProgressSnapshot(null, 0, 0.4, 1, FsrsState.learning),
            cards[1].fenKey to ProgressSnapshot(null, 2, 3.0, 5, FsrsState.relearning),
        )
        assertEquals(listOf(cards[1].fenKey, cards[0].fenKey),
            TrainingQueue.hardest(cards, progress).map { it.fenKey })
    }
}
