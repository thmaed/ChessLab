package com.chesslab.maia

import kotlin.math.exp
import kotlin.math.ln
import kotlin.random.Random

/** Un coup légal et la probabilité que Maia lui attribue. */
data class MaiaCandidate(val move: MaiaMove, val probability: Double)

/**
 * Traduction Kotlin de `MaiaPolicy.swift`.
 *
 * De 4 352 logits à une distribution sur les coups LÉGAUX, puis à un coup :
 * masque, softmax, température, top-p. Module PUR — aucun runtime de modèle,
 * donc testable sur JVM.
 *
 * Réplique `sample_from_logits()` du dépôt de référence : une température
 * nulle prend le coup le plus probable ; top-p < 1 ne garde que la tête de la
 * distribution, toujours au moins le premier coup.
 */
object MaiaPolicy {

    /** La distribution sur les coups légaux, triée par probabilité décroissante. */
    fun candidates(logits: FloatArray, legal: List<MaiaMove>): List<MaiaCandidate> {
        if (legal.isEmpty()) return emptyList()
        val scores = legal.map { logits[it.index].toDouble() }
        val probabilities = softmax(scores)
        return legal.zip(probabilities) { move, p -> MaiaCandidate(move, p) }
            .sortedByDescending { it.probability }
    }

    /**
     * Tire un coup dans la distribution.
     *
     * [temperature] : 0 = le plus probable ; 1 = fidèle aux humains ; au-delà,
     * plus erratique. [topP] : seuil de noyau (1 = désactivé).
     */
    fun sample(
        candidates: List<MaiaCandidate>,
        temperature: Double,
        topP: Double = 1.0,
        random: Random = Random.Default,
    ): MaiaCandidate? {
        val first = candidates.firstOrNull() ?: return null
        if (temperature <= 0) return first

        // Re-tempérer depuis les probabilités : équivalent à tempérer les
        // logits masqués, à une constante près que le softmax absorbe.
        val logs = candidates.map { ln(maxOf(it.probability, 1e-12)) / temperature }
        var weights = softmax(logs)

        if (topP < 1) {
            // la liste est triée : on coupe la queue au-delà de topP, en
            // gardant toujours le premier
            var cumulative = 0.0
            var kept = 0
            for (weight in weights) {
                if (kept > 0 && cumulative > topP) break
                cumulative += weight
                kept++
            }
            weights = weights.take(kept)
            val total = weights.sum()
            weights = weights.map { it / total }
        }

        var roll = random.nextDouble()
        for ((index, weight) in weights.withIndex()) {
            if (roll < weight) return candidates[index]
            roll -= weight
        }
        return candidates[weights.size - 1]
    }

    /** Softmax numériquement stable. */
    fun softmax(values: List<Double>): List<Double> {
        val maximum = values.maxOrNull() ?: return emptyList()
        val exponentials = values.map { exp(it - maximum) }
        val total = exponentials.sum()
        return exponentials.map { it / total }
    }
}
