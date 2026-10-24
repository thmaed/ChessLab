package com.chesslab

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import chesskit.Board
import chesskit.Position
import com.chesslab.analysis.HumanMoveCoach
import com.chesslab.analysis.HumanMoveInsight
import com.chesslab.engine.EngineService
import com.chesslab.maia.MaiaCandidate
import com.chesslab.maia.MaiaMove
import com.chesslab.maia.MaiaOpponent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * B1 — le Coach. Pendant de `HumanMoveCoachTests.swift`. Instrumenté : les
 * phrases lisent les ressources, et le dernier test charge le VRAI modèle.
 */
@RunWith(AndroidJUnit4::class)
class HumanMoveCoachTest {

    private val context = ApplicationProvider.getApplicationContext<android.app.Application>()

    private fun candidate(uci: String, probability: Double) =
        MaiaCandidate(MaiaMove(uci, 0), probability)

    @Test
    fun thresholds() {
        assertEquals(HumanMoveInsight.Kind.TypicalMistake, HumanMoveCoach.classify(0.20, true))
        assertEquals(HumanMoveInsight.Kind.TypicalMistake, HumanMoveCoach.classify(0.08, true))
        assertNull(HumanMoveCoach.classify(0.05, true))
        assertEquals(HumanMoveInsight.Kind.Accident, HumanMoveCoach.classify(0.029, true))
        assertEquals(HumanMoveInsight.Kind.Accident, HumanMoveCoach.classify(0.0, true))
        assertEquals(HumanMoveInsight.Kind.RareFind, HumanMoveCoach.classify(0.01, false))
        assertNull(HumanMoveCoach.classify(0.40, false))
    }

    @Test
    fun insightAndSentences() {
        val board = Board(Position.standard.copy())
        val distribution = listOf(candidate("e2e4", 0.50), candidate("d2d4", 0.30), candidate("a2a3", 0.002))

        val typical = HumanMoveCoach.insight(distribution, "d2d4", board, 1400)!!
        assertEquals(0.30, typical.playedProbability, 1e-9)
        assertEquals("e4", typical.topMoveSan)
        assertFalse(typical.playedIsTop)
        val line = HumanMoveCoach.sentence(context, typical, true, "e4")!!
        assertTrue(line, "30 %" in line && "1400" in line && "e4" in line)

        val same = HumanMoveCoach.insight(distribution, "e2e4", board, 1400)!!
        assertTrue(same.playedIsTop)
        val sameLine = HumanMoveCoach.sentence(context, same, true, "e4") ?: ""
        assertFalse(sameLine, "plus courant" in sameLine || "Most common" in sameLine)
        assertNull(HumanMoveCoach.sentence(context, same, false, "e4"))

        val rare = HumanMoveCoach.insight(distribution, "a2a3", board, 1400)!!
        assertNotNull(HumanMoveCoach.sentence(context, rare, false, "e4"))

        val absent = HumanMoveCoach.insight(distribution, "h2h3", board, 1200)!!
        assertEquals(0.0, absent.playedProbability, 0.0)
        assertEquals(HumanMoveInsight.Kind.Accident, absent.kind(true))
    }

    @Test
    fun defaultLevelStaysInRange() {
        assertTrue(HumanMoveCoach.defaultLevel(context) in HumanMoveCoach.levelRange)
    }

    @Test
    fun realModelKnowsE4() {
        val maia = MaiaOpponent.shared(context, EngineService.threads)
        assertNotNull("le modèle Maia doit être embarqué", maia)
        val board = Board(Position.standard.copy())
        val distribution = maia!!.distribution(listOf(board.position), board, 1500.0, 1500.0)!!
        assertEquals(20, distribution.size)
        assertEquals(1.0, distribution.sumOf { it.probability }, 1e-6)
        val e4 = HumanMoveCoach.insight(distribution, "e2e4", board, 1500)!!
        val h4 = HumanMoveCoach.insight(distribution, "h2h4", board, 1500)!!
        assertTrue(e4.playedProbability > 0.2)
        assertTrue(h4.playedProbability < e4.playedProbability)
    }
}
