package com.chesslab.puzzles

import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * La cote de puzzle PERSONNELLE du joueur (B3, 24/10/2026), sur l'échelle des
 * puzzles Lichess. Pendant de `PuzzleRating.swift`, mêmes formules.
 *
 * Glicko (v1), un puzzle comptant pour une « partie » contre un adversaire dont
 * la cote est celle du puzzle. Glicko plutôt qu'Elo : il porte sa propre
 * INCERTITUDE, donc la cote bouge vite au début et se stabilise ensuite.
 *
 * Un puzzle réussi AVEC l'indice ne rapporte rien et coûte quelques points (décision
 * du 25/10/2026, voir [HINT_PENALTY]) ; ceux de vos parties
 * (cote 0) ne comptent pas ; un programme Woodpecker n'y touche pas.
 */
data class PuzzleRating(
    val rating: Double = 1500.0,
    val deviation: Double = 350.0,
    val count: Int = 0,
) {
    /** Enregistre un puzzle de cote [puzzleRating], réussi ou non. */
    fun record(solved: Boolean, puzzleRating: Int, usedHint: Boolean = false): PuzzleRating {
        val gj = g(PUZZLE_DEVIATION)
        val expected = 1 / (1 + 10.0.pow(-gj * (rating - puzzleRating) / 400))
        val dSquared = 1 / (Q * Q * gj * gj * expected * (1 - expected))
        val precision = 1 / (deviation * deviation) + 1 / dSquared
        val score = when {
            !solved -> 0.0
            usedHint -> max(0.0, expected - HINT_PENALTY)
            else -> 1.0
        }
        return PuzzleRating(
            rating = rating + Q / precision * gj * (score - expected),
            deviation = max(MIN_DEVIATION, sqrt(1 / precision)),
            count = count + 1,
        )
    }

    /** La cote arrondie, telle qu'on l'affiche. */
    val displayed: Int get() = rating.roundToInt()

    /** Une cote encore jeune s'annonce « environ ». */
    val isSettled: Boolean get() = count >= SETTLED_COUNT

    /** La fenêtre de puzzles « à mon niveau » : la cote ± 100 au plus serré, 250 au plus large. */
    val window: IntRange
        get() {
            val half = min(250.0, max(100.0, deviation * 0.6))
            val low = max(400, (rating - half).roundToInt())
            val high = max(low + 1, (rating + half).roundToInt())
            return low..high
        }

    companion object {
        const val MIN_DEVIATION = 60.0
        /**
         * Un puzzle réussi avec l'indice vaut ce que la formule attendait MOINS cette
         * part : aucun gain, quelques points perdus (environ 3 sur un puzzle de son
         * niveau, contre 10 pour un échec franc). Pendant d'iOS.
         */
        const val HINT_PENALTY = 0.15
        const val PUZZLE_DEVIATION = 80.0
        const val SETTLED_COUNT = 10
        private val Q = ln(10.0) / 400.0

        private fun g(deviation: Double) = 1 / sqrt(1 + 3 * Q * Q * deviation * deviation / (Math.PI * Math.PI))
    }
}
