package com.chesslab.dailysession

import androidx.compose.ui.graphics.Color
import com.chesslab.R
import com.chesslab.ui.Palette

/**
 * C8 : les médailles de la série de jours d'entraînement. Pendant de
 * `StreakMedal` (iOS) — mêmes paliers, mêmes teintes.
 */
enum class StreakMedal(val days: Int, val nameRes: Int, val color: Color) {
    bronze(3, R.string.medal_bronze, Palette.gold),
    silver(7, R.string.medal_silver, Color(0.78f, 0.82f, 0.88f)),
    gold(30, R.string.medal_gold, Palette.warning),
    platinum(100, R.string.medal_platinum, Palette.accentSecondary),
    diamond(365, R.string.medal_diamond, Palette.violet);

    companion object {
        /** La plus haute médaille méritée par une série, `null` sous trois jours. */
        fun earned(streak: Int): StreakMedal? = entries.lastOrNull { streak >= it.days }

        /** La prochaine à gagner, `null` une fois le diamant acquis. */
        fun next(streak: Int): StreakMedal? = entries.firstOrNull { streak < it.days }

        /** Vrai quand ce jour de série vient d'ATTEINDRE un palier. */
        fun isMilestone(streak: Int): Boolean = entries.any { it.days == streak }
    }
}
