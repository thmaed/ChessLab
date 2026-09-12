package com.chesslab.puzzles

import androidx.annotation.StringRes
import com.chesslab.R

/**
 * Le palier de difficulté d'un puzzle, d'après sa cote Lichess. Pendant de
 * `DifficultyTier.swift`.
 */
enum class DifficultyTier(@StringRes val labelRes: Int, val range: IntRange) {
    beginner(R.string.tier_beginner, 0..1199),
    intermediate(R.string.tier_intermediate, 1200..1599),
    advanced(R.string.tier_advanced, 1600..1999),
    expert(R.string.tier_expert, 2000..Int.MAX_VALUE);

    companion object {
        fun forRating(rating: Int): DifficultyTier =
            entries.firstOrNull { rating in it.range } ?: expert
    }
}

/** La phase de partie d'où vient la position. Pendant de `GamePhase.swift`. */
enum class GamePhase(val raw: String, @StringRes val labelRes: Int) {
    opening("opening", R.string.phase_opening),
    middlegame("middlegame", R.string.phase_middlegame),
    endgame("endgame", R.string.phase_endgame),
}

/** Les huit thèmes tactiques, dans l'ordre d'iOS. */
enum class PuzzleThemeKind(val raw: String, @StringRes val labelRes: Int) {
    checkmate("checkmate", R.string.theme_mate),
    hangingPiece("hangingPiece", R.string.theme_hanging),
    fork("fork", R.string.theme_fork),
    pin("pin", R.string.theme_pin),
    skewer("skewer", R.string.theme_skewer),
    discoveredAttack("discoveredAttack", R.string.theme_discovered),
    sacrifice("sacrifice", R.string.theme_sacrifice),
    tactic("tactic", R.string.theme_tactic),
}

/**
 * Ce qu'on demande à la file de puzzles. Pendant de `PuzzleSessionFilter`.
 *
 * Tout est facultatif : sans filtre, on tire dans les 106 094 positions, ce qui
 * est le comportement d'origine. **Avec** filtre, on travaille une faiblesse
 * précise — les fourchettes, les finales, ou les deux —, et c'est tout
 * l'intérêt d'une base de cette taille.
 */
data class PuzzleFilter(
    val difficulty: DifficultyTier? = null,
    val phase: GamePhase? = null,
    val theme: PuzzleThemeKind? = null,
) {
    val ratings: IntRange get() = difficulty?.range ?: 0..4000
    val isEmpty: Boolean get() = difficulty == null && phase == null && theme == null
}
