package com.chesslab.variants

import com.chesslab.analysis.AccuracyScore
import kotlin.math.max

/**
 * La précision par joueur d'une partie de VARIANTE. Pendant de
 * `VariantAccuracy.swift`.
 *
 * Le calcul lui-même est celui du mode « Contre l'ordinateur »
 * (`AccuracyScore`) : une perte de probabilité de gain par coup, pondérée par
 * ce qui bougeait autour de lui et par ce qui était encore en jeu. Seule
 * l'ENTRÉE change — l'analyse d'une variante tient une ligne unique de
 * demi-coups, indexée par un entier, là où le mode classique parcourt un arbre
 * de coups.
 *
 * ## Ce que cette précision vaut
 *
 * Elle vaut ce que vaut l'évaluation dont elle est tirée, et celle-ci est
 * approximative dans la plupart des variantes — Fairy-Stockfish n'a de réseau
 * dédié que pour quelques-unes, et le Duck Chess est jugé par un moteur qui ne
 * voit pas le canard. C'est la même approximation que les pastilles de qualité
 * affichées à côté : les deux disent la même chose avec la même confiance, ce
 * qui vaut mieux que de n'en montrer qu'une.
 */
object VariantAccuracy {

    /** Ce que valent les deux camps — les Blancs d'abord. */
    data class ByColor(val white: Double?, val black: Double?) {
        val isEmpty: Boolean get() = white == null && black == null
    }

    /**
     * @param plyCount nombre de demi-coups joués.
     * @param winPercentWhite probabilité de gain POV BLANCS à un demi-coup
     *   donné, `null` si la position n'a pas encore été évaluée — la passe
     *   avance, et la précision se complète avec elle.
     * @param whiteMovesAt vrai si ce sont les BLANCS qui jouent le demi-coup
     *   `ply + 1`, c'est-à-dire si le trait de la position `ply` est à eux ;
     *   `null` si la position est inconnue.
     */
    fun byColor(
        plyCount: Int,
        winPercentWhite: (Int) -> Double?,
        whiteMovesAt: (Int) -> Boolean?,
    ): ByColor {
        // Trois séries parallèles, l'ordre des coups portant l'information : la
        // probabilité de gain le long de la partie (position de départ
        // COMPRISE — sans elle le premier coup n'aurait pas de « avant »), qui
        // a joué, et ce que le coup a coûté.
        val whitePercents = ArrayList<Double>()
        val movers = ArrayList<Boolean>()
        val losses = ArrayList<Double>()

        for (ply in 0 until max(0, plyCount)) {
            val before = winPercentWhite(ply) ?: continue
            val after = winPercentWhite(ply + 1) ?: continue
            val whiteMoved = whiteMovesAt(ply) ?: continue
            if (whitePercents.isEmpty()) whitePercents += before

            val beforeMover = if (whiteMoved) before else 100 - before
            val afterMover = if (whiteMoved) after else 100 - after
            whitePercents += after
            movers += whiteMoved
            losses += max(0.0, beforeMover - afterMover)
        }

        val weights = AccuracyScore.moveWeights(whitePercents)
        // Un TROU dans les évaluations fait sauter le coup concerné, pas plus :
        // les trois séries grandissent ENSEMBLE, donc un coup sauté l'est dans
        // les trois et les poids restent en face des pertes. Le coup perdu ne
        // compte pour personne — ni à charge, ni à décharge —, ce qui est le
        // seul verdict honnête tant que la position n'est pas évaluée. Le test
        // de taille reste : il coûte une comparaison et dit que l'invariant
        // est voulu, pas constaté.
        if (weights.size != losses.size || losses.isEmpty()) return ByColor(null, null)

        fun scoreOf(white: Boolean): Double? {
            val indices = movers.indices.filter { movers[it] == white }
            if (indices.isEmpty()) return null
            return AccuracyScore.accuracy(indices.map { losses[it] }, indices.map { weights[it] })
        }
        return ByColor(scoreOf(true), scoreOf(false))
    }
}
