package com.chesslab.training

import com.chesslab.courses.CourseMove
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Le coup attendu quand « S'entraîner » reçoit la variante affichée par le
 * lecteur. Pendant des tests de `OpeningTrainViewModelTests.swift`
 * (`trainingFollowsTheOpponentSideOfTheChosenVariation` et suivants).
 */
class ExpectedMoveTest {

    private fun move(san: String, uci: String, main: Boolean = false) =
        CourseMove(san, uci, "to-$uci", if (main) "mainLine" else "sideline", null, null, null)

    /** Tel que `candidates()` les rend : la principale d'abord. */
    private val whiteRoot = listOf(move("e4", "e2e4", main = true), move("d4", "d2d4"))
    private val blackReply = listOf(move("e5", "e7e5", main = true), move("c5", "c7c5"))

    @Test fun withoutPathTheMainLineIsExpected() {
        assertEquals("e4", expectedMove(whiteRoot, emptyList(), emptyList())?.san)
        assertEquals("e5", expectedMove(blackReply, listOf("e2e4"), emptyList())?.san)
    }

    @Test fun theChosenVariationIsExpectedFromTheRoot() {
        assertEquals("d4", expectedMove(whiteRoot, emptyList(), listOf("d2d4"))?.san)
    }

    @Test fun theOpponentFollowsTheChosenVariationToo() {
        val path = listOf("e2e4", "c7c5")
        assertEquals("c5", expectedMove(blackReply, listOf("e2e4"), path)?.san)
    }

    @Test fun backToTheMainLineWhenThePathIsExhausted() {
        // La variante s'arrête après e4 : la riposte attendue est la principale.
        assertEquals("e5", expectedMove(blackReply, listOf("e2e4"), listOf("e2e4"))?.san)
    }

    @Test fun backToTheMainLineOnceTheGameLeftThePath() {
        // On a joué la principale alors que la variante demandait d4.
        assertEquals("e5", expectedMove(blackReply, listOf("e2e4"), listOf("d2d4", "d7d5"))?.san)
    }

    @Test fun aPathMoveMissingFromTheNodeFallsBackToTheMainLine() {
        assertEquals("e4", expectedMove(whiteRoot, emptyList(), listOf("c2c4"))?.san)
    }

    @Test fun nothingWhenThereIsNoMove() {
        assertNull(expectedMove(emptyList(), emptyList(), listOf("e2e4")))
    }
}
