package com.chesslab.progression

import chesskit.Piece
import com.chesslab.analysis.GameProfileCodec
import com.chesslab.analysis.PhaseLoss
import com.chesslab.library.GameRecord
import com.chesslab.puzzles.GamePhase

/** Une partie du joueur, réduite à ce que le profil regarde. */
data class AnalyzedGame(
    val date: Long,
    val accuracy: Double?,
    val phases: Map<GamePhase, PhaseLoss>,
    val themes: Map<String, Int>,
    val openingName: String?,
)

/**
 * Le profil de faiblesses du joueur, tiré de ses parties ANALYSÉES (A4) : où il
 * perd des points, quelles tactiques il manque, comment sa précision évolue,
 * quelles ouvertures lui coûtent. Pendant de `PlayerProfile.swift`. Pur : des
 * parties, un profil.
 *
 * Seules comptent les parties jouées contre l'ordinateur (le « vous » est
 * connu) et analysées. Une partie analysée avant A4 n'a pas de profil par phase
 * — elle compte pour la précision, pas pour le reste.
 */
data class PlayerProfile(
    val games: Int,
    val accuracy: AccuracyTrend?,
    val phases: List<PhaseStat>,
    val weakestPhase: PhaseStat?,
    val themes: List<ThemeStat>,
    val openings: List<OpeningStat>,
) {
    data class PhaseStat(val phase: GamePhase, val averageLoss: Double, val moves: Int)

    /** `theme` : `mate`, `hanging`, `fork`, `discovery`, `pin` ou `other`. */
    data class ThemeStat(val theme: String, val count: Int)

    data class OpeningStat(val name: String, val games: Int, val averageLoss: Double)

    data class AccuracyTrend(
        /** Précision des parties les plus récentes (dix au plus), de la plus ancienne à la plus récente. */
        val recent: List<Double>,
        val recentAverage: Double,
        /** Moyenne des dix précédentes, si au moins trois. */
        val previousAverage: Double?,
    ) {
        val delta: Double? get() = previousAverage?.let { recentAverage - it }
    }

    val isMeaningful: Boolean get() = games >= MINIMUM_GAMES

    companion object {
        /** Sous ce nombre de parties analysées, le profil n'est pas montré : deux parties ne font pas une tendance. */
        const val MINIMUM_GAMES = 3

        /** Sous ce nombre de coups comptés, une phase n'est pas jugée. */
        const val MINIMUM_PHASE_MOVES = 8
        const val MINIMUM_OPENING_MOVES = 6
        const val TREND_WINDOW = 10

        fun compute(games: List<AnalyzedGame>): PlayerProfile {
            val ordered = games.sortedBy { it.date }

            val accuracies = ordered.mapNotNull { it.accuracy }
            val trend = if (accuracies.isEmpty()) null else {
                val recent = accuracies.takeLast(TREND_WINDOW)
                val earlier = accuracies.dropLast(recent.size).takeLast(TREND_WINDOW)
                AccuracyTrend(
                    recent = recent,
                    recentAverage = recent.average(),
                    previousAverage = if (earlier.size >= 3) earlier.average() else null,
                )
            }

            val totals = HashMap<GamePhase, PhaseLoss>()
            for (game in ordered) for ((phase, loss) in game.phases) {
                val current = totals[phase] ?: PhaseLoss()
                totals[phase] = PhaseLoss(current.total + loss.total, current.count + loss.count)
            }
            val phaseStats = GamePhase.entries.mapNotNull { phase ->
                val loss = totals[phase] ?: return@mapNotNull null
                val average = loss.average
                if (loss.count < MINIMUM_PHASE_MOVES || average == null) null
                else PhaseStat(phase, average, loss.count)
            }
            val weakest = if (phaseStats.size >= 2) phaseStats.maxByOrNull { it.averageLoss } else null

            val themeTotals = HashMap<String, Int>()
            for (game in ordered) for ((theme, count) in game.themes) themeTotals[theme] = (themeTotals[theme] ?: 0) + count
            val themes = themeTotals.entries
                .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
                .take(3).map { ThemeStat(it.key, it.value) }

            val byOpening = HashMap<String, Pair<Int, PhaseLoss>>()
            for (game in ordered) {
                val name = game.openingName ?: continue
                val opening = game.phases[GamePhase.opening]?.takeIf { it.count > 0 } ?: continue
                val (games, loss) = byOpening[name] ?: (0 to PhaseLoss())
                byOpening[name] = (games + 1) to PhaseLoss(loss.total + opening.total, loss.count + opening.count)
            }
            val openings = byOpening.mapNotNull { (name, entry) ->
                val average = entry.second.average
                if (entry.first < 2 || entry.second.count < MINIMUM_OPENING_MOVES || average == null || average <= 0.0) null
                else OpeningStat(name, entry.first, average)
            }
                .sortedWith(compareByDescending<OpeningStat> { it.averageLoss }.thenBy { it.name })
                .take(3)

            return PlayerProfile(ordered.size, trend, phaseStats, weakest, themes, openings)
        }

        /** Les parties du joueur contre l'ordinateur, analysées, vues de son côté. */
        fun compute(records: List<GameRecord>, analysisVersion: Int): PlayerProfile {
            val mine = records.mapNotNull { record ->
                if (record.source != "engine" || record.variant != null) return@mapNotNull null
                if (record.analysisVersion != analysisVersion) return@mapNotNull null
                val engineColor = record.engineColor ?: return@mapNotNull null
                val userIsWhite = engineColor == "black"
                AnalyzedGame(
                    date = record.playedAt,
                    accuracy = if (userIsWhite) record.whiteAccuracy else record.blackAccuracy,
                    phases = GameProfileCodec.decodePhases(if (userIsWhite) record.whitePhase else record.blackPhase),
                    themes = GameProfileCodec.decodeThemes(if (userIsWhite) record.whiteThemes else record.blackThemes),
                    openingName = record.openingName,
                )
            }
            return compute(mine)
        }
    }
}
