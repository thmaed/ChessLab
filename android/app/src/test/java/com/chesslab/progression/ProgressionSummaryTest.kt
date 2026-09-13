package com.chesslab.progression

import com.chesslab.library.GameRecord
import com.chesslab.puzzles.DifficultyTier
import com.chesslab.puzzles.PuzzleProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le bilan de progression, sur des cas choisis — les règles de
 * `ProgressionSummary.swift` et `PuzzleStats.swift`.
 */
class ProgressionSummaryTest {

    private fun puzzle(theme: String, ok: Int, ko: Int, rating: Int = 0) =
        PuzzleProgress("p-$theme-$ok-$ko-$rating", successCount = ok, failureCount = ko, theme = theme, rating = rating)

    private fun game(result: String, engineColor: String? = "black", elo: Int? = 1500, opponent: String? = null, source: String = "engine") =
        GameRecord(playedAt = 0, white = "Vous", black = "Léna", result = result, source = source, moveCount = 10, pgn = "",
            opponentId = opponent, engineElo = elo, engineColor = engineColor)

    @Test fun `un theme n'est a travailler qu'avec assez d'essais et assez d'echecs`() {
        val stats = PuzzleStats.compute(listOf(
            puzzle("fork", ok = 1, ko = 3),        // 75 % d'échecs sur 4 : à travailler
            puzzle("pin", ok = 0, ko = 2),         // trop peu d'essais
            puzzle("mate", ok = 9, ko = 1),        // réussi à 90 % : pas une faiblesse
        ))
        assertEquals(listOf("fork"), stats.weakestThemes.map { it.theme })
        assertEquals(0.75, stats.weakestThemes[0].failureRate, 1e-9)
        assertEquals(16, stats.attempts)
        assertEquals(10, stats.successes)
    }

    @Test fun `les themes les plus rates viennent en premier, les plus eprouves departagent`() {
        val stats = PuzzleStats.compute(listOf(
            puzzle("fork", ok = 2, ko = 2),
            puzzle("skewer", ok = 1, ko = 3),
            puzzle("pin", ok = 4, ko = 4),
        ))
        assertEquals(listOf("skewer", "pin", "fork"), stats.weakestThemes.map { it.theme })
    }

    @Test fun `sans puzzle tente, pas de taux`() {
        val stats = PuzzleStats.compute(listOf(puzzle("fork", 0, 0)))
        assertNull(stats.successRate)
        assertEquals(0, stats.attempts)
    }

    @Test fun `la reussite se ventile par palier, sans les puzzles sans note`() {
        val stats = PuzzleStats.compute(listOf(
            puzzle("fork", ok = 3, ko = 1, rating = 1000),
            puzzle("pin", ok = 1, ko = 1, rating = 1800),
            puzzle("mate", ok = 5, ko = 0),           // vos parties : pas de note
        ))
        assertEquals(listOf(DifficultyTier.beginner, DifficultyTier.advanced), stats.byTier.map { it.tier })
        assertEquals(0.75, stats.byTier[0].successRate, 1e-9)
        assertEquals(11, stats.attempts)
    }

    @Test fun `le niveau atteint est le plus dur qui tient, sur cinq essais au moins`() {
        val solid = PuzzleStats.compute(listOf(
            puzzle("fork", ok = 4, ko = 1, rating = 1000),   // 80 % sur 5 : tient
            puzzle("pin", ok = 3, ko = 2, rating = 1400),    // 60 % sur 5 : tient tout juste
            puzzle("mate", ok = 2, ko = 0, rating = 1800),   // 2 sur 2 ne prouve rien
        ))
        assertEquals(DifficultyTier.intermediate, solid.reachedTier)
        assertNull(PuzzleStats.compute(listOf(puzzle("fork", ok = 2, ko = 0, rating = 1000))).reachedTier)
    }

    @Test fun `les parties se comptent du point de vue du joueur`() {
        val s = ProgressionSummary.compute(listOf(
            game("1-0", engineColor = "black"),               // le joueur a les Blancs et gagne
            game("1-0", engineColor = "white"),               // le moteur a les Blancs : défaite
            game("1/2-1/2"),
            game("0-1", engineColor = null),                  // enregistrement ancien : « Vous » a les Blancs, défaite
            game("1-0", source = "twoPlayer"),                // deux humains : hors bilan
        ), emptyList())
        assertEquals(1, s.engineWins); assertEquals(1, s.engineDraws); assertEquals(2, s.engineLosses)
    }

    @Test fun `la meilleure victoire, les paliers et les personnages`() {
        // Deux personnages RÉELS de la galerie : le bilan ne retient que ceux
        // qu'elle connaît, dans son ordre.
        val first = com.chesslab.maia.OpponentGallery.all[0].id
        val second = com.chesslab.maia.OpponentGallery.all[1].id
        val s = ProgressionSummary.compute(listOf(
            game("1-0", elo = 1100, opponent = first),
            game("1-0", elo = 1900, opponent = first),
            game("0-1", elo = 2300, opponent = second),
            game("1-0", elo = null),                          // sans niveau : compte, sans palier
            game("1-0", elo = 1500, opponent = "inconnu"),    // hors galerie : compte, sans personnage
        ), emptyList())
        assertEquals(1900, s.bestWinElo)
        assertEquals(listOf(EloBand.novice, EloBand.amateur, EloBand.club, EloBand.expert), s.engineByBand.map { it.band })
        assertEquals(4, s.engineWins)
        assertEquals(listOf(first, second), s.engineByOpponent.map { it.profileId })
        val one = s.engineByOpponent[0]
        assertEquals(2, one.wins); assertEquals(1900, one.bestWinLevel)
        val two = s.engineByOpponent[1]
        assertEquals(1, two.losses); assertNull(two.bestWinLevel)
    }

    @Test fun `la fenetre de temps borne les parties`() {
        val now = 10_000_000_000L
        assertNull(TimeRange.allTime.cutoff(now))
        assertEquals(now - 7L * 24 * 3600 * 1000, TimeRange.last7Days.cutoff(now))
        assertTrue(TimeRange.last30Days.cutoff(now)!! < TimeRange.last7Days.cutoff(now)!!)
    }

    @Test fun `un palier de force couvre tout Elo`() {
        assertEquals(EloBand.novice, EloBand.forElo(800))
        assertEquals(EloBand.amateur, EloBand.forElo(1200))
        assertEquals(EloBand.club, EloBand.forElo(2199))
        assertEquals(EloBand.expert, EloBand.forElo(3000))
    }
}
