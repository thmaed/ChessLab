package com.chesslab.progression

import androidx.annotation.StringRes
import com.chesslab.R
import com.chesslab.library.GameRecord
import com.chesslab.maia.OpponentGallery
import com.chesslab.puzzles.DifficultyTier
import com.chesslab.puzzles.PuzzleProgress
import com.chesslab.puzzles.PuzzleThemeKind

/**
 * Le bilan de vos puzzles : taux de réussite global et thèmes d'erreurs
 * RÉCURRENTS — « vous ratez souvent des fourchettes ». Pendant de
 * `PuzzleStats.swift`. Calcul PUR, testable sur des cas choisis.
 */
data class PuzzleStats(
    val attempts: Int,
    val successes: Int,
    /** Les thèmes les plus ratés en premier ; un thème sans assez d'essais n'y figure pas. */
    val weakestThemes: List<ThemeRecord>,
    /** La réussite par palier de difficulté — puzzles notés seulement. */
    val byTier: List<TierRecord>,
) {
    /** Un thème sur lequel vous butez. */
    data class ThemeRecord(val theme: String, val attempts: Int, val failures: Int) {
        val failureRate: Double get() = if (attempts == 0) 0.0 else failures.toDouble() / attempts
        val successRate: Double get() = 1 - failureRate

        @get:StringRes
        val labelRes: Int get() = PuzzleThemeKind.entries.firstOrNull { it.raw == theme }?.labelRes ?: R.string.theme_tactic
    }

    data class TierRecord(val tier: DifficultyTier, val attempts: Int, val successes: Int) {
        val successRate: Double get() = if (attempts == 0) 0.0 else successes.toDouble() / attempts
    }

    /** `null` tant qu'aucun puzzle n'a été tenté : « 0 % » serait faux ET décourageant. */
    val successRate: Double? get() = if (attempts == 0) null else successes.toDouble() / attempts

    /**
     * Le palier le plus difficile où la réussite est SOLIDE — au moins 60 %
     * sur cinq essais : un « niveau atteint » honnête, à défaut d'une courbe
     * dans le temps. Du plus dur au plus facile, le premier qui tient.
     */
    val reachedTier: DifficultyTier?
        get() = DifficultyTier.entries.reversed().firstOrNull { tier ->
            val record = byTier.firstOrNull { it.tier == tier } ?: return@firstOrNull false
            record.attempts >= MINIMUM_ATTEMPTS_FOR_TIER && record.successRate >= 0.6
        }

    companion object {
        /** En deçà, un thème ne dit rien : rater 1 puzzle sur 1 ne fait pas une faiblesse. */
        const val MINIMUM_ATTEMPTS_PER_THEME = 4

        /** Un thème n'est « à travailler » qu'au-delà de ce taux d'échec — sinon on désignerait un thème réussi à 90 %. */
        const val WEAKNESS_THRESHOLD = 0.34

        /** Réussir 2 sur 2 ne prouve pas qu'on « tient » le palier expert. */
        const val MINIMUM_ATTEMPTS_FOR_TIER = 5

        fun compute(rows: List<PuzzleProgress>, minimumAttemptsPerTheme: Int = MINIMUM_ATTEMPTS_PER_THEME): PuzzleStats {
            var successes = 0; var failures = 0
            val byTheme = HashMap<String, IntArray>()       // [réussites, échecs]
            val byTier = HashMap<DifficultyTier, IntArray>() // [essais, réussites]
            for (row in rows) {
                val s = row.successCount; val f = row.failureCount
                if (s + f == 0) continue
                successes += s; failures += f
                byTheme.getOrPut(row.theme) { IntArray(2) }.let { it[0] += s; it[1] += f }
                // Un puzzle sans note (tiré de vos parties) compte dans le
                // total, mais dans aucun palier.
                if (row.rating > 0) byTier.getOrPut(DifficultyTier.forRating(row.rating)) { IntArray(2) }.let { it[0] += s + f; it[1] += s }
            }
            val themes = byTheme.map { (theme, c) -> ThemeRecord(theme, c[0] + c[1], c[1]) }
                .filter { it.attempts >= minimumAttemptsPerTheme && it.failureRate > WEAKNESS_THRESHOLD }
                // À taux égal, le thème le plus éprouvé est le plus significatif.
                .sortedWith(compareByDescending<ThemeRecord> { it.failureRate }.thenByDescending { it.attempts })
            val tiers = DifficultyTier.entries.mapNotNull { tier ->
                byTier[tier]?.let { TierRecord(tier, it[0], it[1]) }
            }
            return PuzzleStats(successes + failures, successes, themes, tiers)
        }
    }
}

/** Les paliers de force d'un adversaire — les mêmes qu'iOS. */
enum class EloBand(@StringRes val labelRes: Int, val range: IntRange) {
    novice(R.string.band_novice, 0..1199),
    amateur(R.string.band_amateur, 1200..1699),
    club(R.string.band_club, 1700..2199),
    expert(R.string.band_expert, 2200..Int.MAX_VALUE);

    companion object {
        fun forElo(elo: Int): EloBand = entries.firstOrNull { elo in it.range } ?: expert
    }
}

/** La fenêtre du bilan contre l'ordinateur. */
enum class TimeRange(@StringRes val labelRes: Int, val days: Int?) {
    last7Days(R.string.progress_range_7, 7),
    last30Days(R.string.progress_range_30, 30),
    allTime(R.string.progress_range_all, null);

    /** `null` = pas de borne. */
    fun cutoff(now: Long): Long? = days?.let { now - it * 24L * 60 * 60 * 1000 }
}

/**
 * Le bilan de progression : une vue d'ensemble de ce que l'utilisateur a
 * accompli, agrégée à partir des données DÉJÀ persistées — parties de la
 * bibliothèque, progression des puzzles. Pendant de `ProgressionSummary.swift`.
 *
 * Les puzzles ne stockent que des compteurs cumulés, pas un historique daté :
 * ce bilan décrit un ÉTAT (« où j'en suis »), pas une courbe dans le temps.
 * Mieux vaut un chiffre honnête qu'une fausse timeline.
 */
data class ProgressionSummary(
    val puzzles: PuzzleStats,
    val engineWins: Int,
    val engineDraws: Int,
    val engineLosses: Int,
    /** Les résultats groupés par palier de force de l'adversaire. */
    val engineByBand: List<BandRecord>,
    /** Le plus haut Elo battu — la statistique qui motive. `null` sans victoire. */
    val bestWinElo: Int?,
    /** Les résultats par personnage, dans l'ordre de la galerie. */
    val engineByOpponent: List<OpponentRecord>,
) {
    data class BandRecord(val band: EloBand, val wins: Int, val draws: Int, val losses: Int)
    data class OpponentRecord(val profileId: String, val wins: Int, val draws: Int, val losses: Int, val bestWinLevel: Int?)

    enum class GameResult { win, draw, loss }

    val engineGames: Int get() = engineWins + engineDraws + engineLosses
    val hasAnyData: Boolean get() = puzzles.attempts > 0 || engineGames > 0

    companion object {
        fun compute(games: List<GameRecord>, rows: List<PuzzleProgress>): ProgressionSummary {
            var wins = 0; var draws = 0; var losses = 0
            val byBand = HashMap<EloBand, IntArray>()
            val byOpponent = HashMap<String, IntArray>()   // [v, n, d, meilleur]
            var bestWinElo: Int? = null

            for (game in games) {
                val result = userResult(game) ?: continue
                when (result) { GameResult.win -> wins++; GameResult.draw -> draws++; GameResult.loss -> losses++ }
                val elo = game.engineElo ?: continue
                byBand.getOrPut(EloBand.forElo(elo)) { IntArray(3) }[result.ordinal]++
                if (result == GameResult.win) bestWinElo = maxOf(bestWinElo ?: 0, elo)
                game.opponentId?.let { id ->
                    val entry = byOpponent.getOrPut(id) { intArrayOf(0, 0, 0, -1) }
                    entry[result.ordinal]++
                    if (result == GameResult.win) entry[3] = maxOf(entry[3], elo)
                }
            }
            val bands = EloBand.entries.mapNotNull { band -> byBand[band]?.let { BandRecord(band, it[0], it[1], it[2]) } }
            val opponents = OpponentGallery.all.mapNotNull { profile ->
                byOpponent[profile.id]?.let { OpponentRecord(profile.id, it[0], it[1], it[2], it[3].takeIf { b -> b >= 0 }) }
            }
            return ProgressionSummary(PuzzleStats.compute(rows), wins, draws, losses, bands, bestWinElo, opponents)
        }

        /**
         * Le résultat d'une partie DU POINT DE VUE DU JOUEUR. `null` pour une
         * partie à deux humains ou un résultat illisible.
         *
         * La couleur du joueur se déduit de la couleur du MOTEUR — champ
         * sémantique — avec repli sur le nom pour les enregistrements
         * antérieurs, où « Vous » n'existe qu'en français ou en anglais.
         */
        fun userResult(game: GameRecord): GameResult? {
            if (game.source != "engine") return null
            val userIsWhite = when (game.engineColor) {
                "black" -> true
                "white" -> false
                else -> game.white == "Vous" || game.white == "You"
            }
            return when (game.result) {
                "1-0" -> if (userIsWhite) GameResult.win else GameResult.loss
                "0-1" -> if (userIsWhite) GameResult.loss else GameResult.win
                "1/2-1/2" -> GameResult.draw
                else -> null
            }
        }
    }
}
