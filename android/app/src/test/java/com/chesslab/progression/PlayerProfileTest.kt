package com.chesslab.progression

import chesskit.Piece
import com.chesslab.analysis.GameProfileCodec
import com.chesslab.analysis.GameSummary
import com.chesslab.analysis.MoveQuality
import com.chesslab.analysis.PhaseLoss
import com.chesslab.library.GameRecord
import com.chesslab.puzzles.GamePhase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** A4 — le profil de faiblesses. Pendant de `PlayerProfileTests.swift`. */
class PlayerProfileTest {

    private val day = 86_400_000L

    private fun game(
        daysAgo: Int, accuracy: Double?, opening: PhaseLoss? = null, middle: PhaseLoss? = null,
        end: PhaseLoss? = null, themes: Map<String, Int> = emptyMap(), name: String? = null,
    ): AnalyzedGame {
        val phases = HashMap<GamePhase, PhaseLoss>()
        opening?.let { phases[GamePhase.opening] = it }
        middle?.let { phases[GamePhase.middlegame] = it }
        end?.let { phases[GamePhase.endgame] = it }
        return AnalyzedGame(1_000_000_000_000L - daysAgo * day, accuracy, phases, themes, name)
    }

    @Test fun `les chaines stockees se relisent a l'identique`() {
        val phases = mapOf(GamePhase.opening to PhaseLoss(12.5, 6), GamePhase.endgame to PhaseLoss(4.0, 2))
        val text = GameProfileCodec.encodePhases(phases)
        assertEquals("o:12.50:6,m:0.00:0,e:4.00:2", text)
        val decoded = GameProfileCodec.decodePhases(text)
        assertEquals(PhaseLoss(12.5, 6), decoded[GamePhase.opening])
        assertEquals(PhaseLoss(4.0, 2), decoded[GamePhase.endgame])

        assertEquals("fork:2,pin:1", GameProfileCodec.encodeThemes(mapOf("pin" to 1, "fork" to 2, "other" to 0)))
        assertEquals(mapOf("fork" to 2, "pin" to 1), GameProfileCodec.decodeThemes("fork:2,pin:1"))
        assertTrue(GameProfileCodec.decodePhases(null).isEmpty())
        assertTrue(GameProfileCodec.decodeThemes("n'importe quoi").isEmpty())
    }

    @Test fun `le bilan d'une partie porte la perte par phase et les fautes par motif`() {
        val q = MoveQuality.good
        val entries = listOf(
            GameSummary.Companion.Entry(Piece.Color.white, q, 10.0, GamePhase.opening, null),
            GameSummary.Companion.Entry(Piece.Color.white, MoveQuality.book, 0.0, GamePhase.opening, null),
            GameSummary.Companion.Entry(Piece.Color.white, MoveQuality.blunder, 30.0, GamePhase.middlegame, "fork"),
            GameSummary.Companion.Entry(Piece.Color.white, MoveQuality.mistake, 20.0, GamePhase.middlegame, "other"),
            GameSummary.Companion.Entry(Piece.Color.black, q, 5.0, GamePhase.endgame, null),
        )
        val summary = GameSummary.compute(entries, 5, emptyMap(), openingName = "Italian Game")
        assertEquals(PhaseLoss(10.0, 1), summary.white.phases[GamePhase.opening])
        assertEquals(PhaseLoss(50.0, 2), summary.white.phases[GamePhase.middlegame])
        assertEquals(mapOf("fork" to 1, "other" to 1), summary.white.themes)
        assertEquals(PhaseLoss(5.0, 1), summary.black.phases[GamePhase.endgame])
        assertEquals("Italian Game", summary.openingName)
    }

    @Test fun `trop peu de parties le profil n'est pas montre`() {
        assertFalse(PlayerProfile.compute(listOf(game(1, 70.0), game(2, 72.0))).isMeaningful)
    }

    @Test fun `la phase la plus couteuse est le point faible a condition d'avoir assez de coups`() {
        val games = (0 until 4).map {
            game(it, 75.0, PhaseLoss(6.0, 3), PhaseLoss(60.0, 6), PhaseLoss(10.0, 2))
        }
        val profile = PlayerProfile.compute(games)
        assertTrue(profile.isMeaningful)
        assertEquals(GamePhase.middlegame, profile.weakestPhase!!.phase)
        assertEquals(10.0, profile.weakestPhase!!.averageLoss, 1e-9)
        assertEquals(listOf(GamePhase.opening, GamePhase.middlegame, GamePhase.endgame), profile.phases.map { it.phase })

        val thin = PlayerProfile.compute((0 until 3).map { game(it, 70.0, middle = PhaseLoss(9.0, 1)) })
        assertTrue(thin.phases.isEmpty())
        assertNull(thin.weakestPhase)
    }

    @Test fun `la precision recente se compare aux dix precedentes`() {
        val games = (0 until 25).map { game(it, if (it < 10) 80.0 else if (it < 20) 70.0 else 60.0) }
        val trend = PlayerProfile.compute(games).accuracy!!
        assertEquals(10, trend.recent.size)
        assertEquals(80.0, trend.recentAverage, 1e-9)
        assertEquals(70.0, trend.previousAverage!!, 1e-9)
        assertEquals(10.0, trend.delta!!, 1e-9)

        val young = PlayerProfile.compute((0 until 12).map { game(it, 75.0) }).accuracy!!
        assertNull(young.previousAverage)
    }

    @Test fun `les tactiques manquees sont classees les trois premieres seulement`() {
        val games = listOf(
            game(1, 70.0, themes = mapOf("fork" to 2, "pin" to 1)),
            game(2, 70.0, themes = mapOf("fork" to 1, "other" to 5, "mate" to 1, "hanging" to 1)),
            game(3, 70.0),
        )
        val profile = PlayerProfile.compute(games)
        assertEquals(listOf("other", "fork", "hanging"), profile.themes.map { it.theme })
        assertEquals(listOf(5, 3, 1), profile.themes.map { it.count })
    }

    @Test fun `une ouverture couteuse demande deux parties et assez de coups hors theorie`() {
        val games = listOf(
            game(1, 70.0, opening = PhaseLoss(30.0, 3), name = "Sicilian Defense"),
            game(2, 70.0, opening = PhaseLoss(24.0, 3), name = "Sicilian Defense"),
            game(3, 70.0, opening = PhaseLoss(5.0, 3), name = "Italian Game"),
            game(4, 70.0, opening = PhaseLoss(90.0, 3), name = "Scandinavian Defense"),
        )
        val profile = PlayerProfile.compute(games)
        assertEquals(listOf("Sicilian Defense"), profile.openings.map { it.name })
        assertEquals(9.0, profile.openings.first().averageLoss, 1e-9)
        assertEquals(2, profile.openings.first().games)
    }

    @Test fun `seules les parties contre l'ordinateur vues du cote du joueur entrent dans le profil`() {
        fun record(source: String, engineColor: String?, whiteAcc: Double, blackAcc: Double) = GameRecord(
            playedAt = System.currentTimeMillis(), white = "a", black = "b", result = "1-0", source = source,
            moveCount = 20, pgn = "", engineColor = engineColor, analysisVersion = 1,
            whiteAccuracy = whiteAcc, blackAccuracy = blackAcc,
        )
        val profile = PlayerProfile.compute(
            listOf(
                record("engine", "black", 60.0, 10.0),      // je suis Blanc
                record("engine", "white", 20.0, 90.0),      // je suis Noir
                record("twoPlayer", null, 99.0, 99.0),      // à deux : exclue
                record("engine", "white", 50.0, 50.0).copy(analysisVersion = null),   // pas analysée
            ),
            analysisVersion = 1,
        )
        assertEquals(2, profile.games)
        assertEquals(75.0, profile.accuracy!!.recentAverage, 1e-9)   // (60 + 90) / 2
    }
}
