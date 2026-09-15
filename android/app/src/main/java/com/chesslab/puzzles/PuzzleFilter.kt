package com.chesslab.puzzles

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CallSplit
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.chesslab.R
import com.chesslab.ui.Palette

/**
 * Le palier de difficulté d'un puzzle, d'après sa cote Lichess. Pendant de
 * `DifficultyTier.swift`.
 */
enum class DifficultyTier(@StringRes val labelRes: Int, val range: IntRange) {
    beginner(R.string.tier_beginner, 0..1199),
    intermediate(R.string.tier_intermediate, 1200..1599),
    advanced(R.string.tier_advanced, 1600..1999),
    expert(R.string.tier_expert, 2000..Int.MAX_VALUE);

    /**
     * La difficulté se lit à sa COULEUR, du vert au rose — quatre paliers,
     * quatre teintes, les mêmes qu'iOS. Android affichait la cote brute en
     * vert-bleu-jaune-rouge : ni le même barème, ni les mêmes couleurs.
     */
    val tint: Color
        get() = when (this) {
            beginner -> Palette.accent
            intermediate -> Palette.info
            advanced -> Palette.warning
            expert -> Palette.rose
        }

    companion object {
        fun forRating(rating: Int): DifficultyTier =
            entries.firstOrNull { rating in it.range } ?: expert
    }
}

/** La phase de partie d'où vient la position. Pendant de `GamePhase.swift`. */
enum class GamePhase(val raw: String, @StringRes val labelRes: Int) {
    opening("opening", R.string.phase_opening),
    middlegame("middlegame", R.string.phase_middlegame),
    endgame("endgame", R.string.phase_endgame);

    /** L'icône la dit sans qu'on lise : un drapeau, un éclair, une couronne. */
    val icon: ImageVector
        get() = when (this) {
            opening -> Icons.Outlined.Flag
            middlegame -> Icons.Default.Bolt
            endgame -> Icons.Default.WorkspacePremium
        }

    val tint: Color
        get() = when (this) {
            opening -> Palette.teal
            middlegame -> Palette.violet
            endgame -> Palette.warning
        }

    companion object {
        fun of(raw: String?): GamePhase? = entries.firstOrNull { it.raw == raw }
    }
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
    tactic("tactic", R.string.theme_tactic);

    /** Les mêmes symboles qu'iOS, dans leur équivalent Material. */
    val icon: ImageVector
        get() = when (this) {
            checkmate -> Icons.Default.SportsScore
            hangingPiece -> Icons.Default.Warning
            fork -> Icons.Default.CallSplit
            pin -> Icons.Default.PushPin
            skewer -> Icons.Default.SwapHoriz
            discoveredAttack -> Icons.Default.Visibility
            sacrifice -> Icons.Default.LocalFireDepartment
            tactic -> Icons.Default.Extension
        }
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
