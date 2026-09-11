package com.chesslab.training

import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToLong

/**
 * FSRS-5 (Free Spaced Repetition Scheduler), porté de `FSRS.swift`.
 *
 * Implémentation MAISON, sans dépendance : on maîtrise l'algorithme et son
 * évolution. FSRS-5 plutôt que FSRS-6 — decay FIXE (-0,5), 19 poids, formules
 * stables et documentées ; le gain d'exactitude de FSRS-6 ne justifie pas le
 * risque d'une implémentation subtilement fausse sur la donnée la plus
 * douloureuse à perdre.
 *
 * Pas de « learning steps » : [intervalDays] a un plancher d'UN JOUR, donc un
 * « encore » replanifie à demain, jamais dans la séance en cours. Assumé, pas
 * oublié — c'est la même décision que côté iOS.
 *
 * L'unité de révision est la POSITION (clé FEN normalisée), pas la ligne.
 * Cette classe est un CALCULATEUR PUR : aucune I/O, aucun état global. La
 * vérité vit dans [OpeningProgress].
 *
 * Les dates sont des millisecondes depuis l'epoch — le format que Room stocke
 * déjà pour le reste de l'app.
 */
enum class FsrsRating(val raw: Int) {
    again(1), hard(2), good(3), easy(4);

    companion object {
        fun of(raw: Int): FsrsRating = entries.firstOrNull { it.raw == raw } ?: good
    }
}

enum class FsrsState(val raw: Int) {
    new(0), learning(1), review(2), relearning(3);

    companion object {
        fun of(raw: Int): FsrsState = entries.firstOrNull { it.raw == raw } ?: new
    }
}

/** L'état complet d'une position pour la planification. Valeur pure. */
data class FsrsCard(
    val stability: Double = 0.0,
    val difficulty: Double = 0.0,
    val state: FsrsState = FsrsState.new,
    val reps: Int = 0,
    val lapses: Int = 0,
    /** Millisecondes epoch, ou `null` si jamais révisée. */
    val lastReview: Long? = null,
    val due: Long? = null,
) {
    companion object { val new = FsrsCard() }
}

/** Une révision : la carte replanifiée et de quoi journaliser l'événement. */
data class FsrsOutcome(
    val card: FsrsCard,
    val rating: FsrsRating,
    val reviewedAt: Long,
    val elapsedDays: Double,
    val scheduledDays: Double,
    val stabilityBefore: Double,
    val stabilityAfter: Double,
)

/** Les 19 poids FSRS-5 et la rétention visée. */
data class FsrsParameters(
    val w: DoubleArray = defaultWeights,
    val requestRetention: Double = 0.9,
    val maximumIntervalDays: Int = 36_500,
) {
    companion object {
        /**
         * Poids par défaut publiés par open-spaced-repetition. Non
         * ré-optimisés : ils conviennent tant qu'on n'entraîne pas les poids
         * sur les journaux de l'utilisateur.
         */
        val defaultWeights = doubleArrayOf(
            0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
            1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
            2.9898, 0.51655, 0.6621,
        )
        val default = FsrsParameters()
    }

    // `DoubleArray` casse equals/hashCode générés : on les écrit.
    override fun equals(other: Any?): Boolean = other is FsrsParameters &&
        w.contentEquals(other.w) && requestRetention == other.requestRetention &&
        maximumIntervalDays == other.maximumIntervalDays

    override fun hashCode(): Int =
        (w.contentHashCode() * 31 + requestRetention.hashCode()) * 31 + maximumIntervalDays
}

class Fsrs(private val parameters: FsrsParameters = FsrsParameters.default) {

    private val w: DoubleArray get() = parameters.w

    companion object {
        /** Décroissance fixe de la courbe d'oubli (FSRS-5). */
        const val DECAY = -0.5
        /** Facteur associé : `0.9^(1/decay) - 1` = `19/81`. */
        const val FACTOR = 19.0 / 81.0
        /** Plancher de stabilité (jours) — évite les intervalles dégénérés. */
        const val MIN_STABILITY = 0.01
        const val DAY_MS = 86_400_000L

        /** Probabilité de rappel `t` jours après la révision, pour stabilité `s`. */
        fun retrievability(elapsedDays: Double, stability: Double): Double {
            if (stability <= 0) return 0.0
            return (1 + FACTOR * max(0.0, elapsedDays) / stability).pow(DECAY)
        }
    }

    fun retrievability(card: FsrsCard, at: Long): Double {
        val last = card.lastReview
        if (card.state == FsrsState.new || last == null) return 0.0
        return retrievability((at - last).toDouble() / DAY_MS, card.stability)
    }

    /** Intervalle (jours) visant la rétention désirée. Borné à [1, max]. */
    fun intervalDays(stability: Double): Int {
        val raw = (stability / FACTOR) * (parameters.requestRetention.pow(1 / DECAY) - 1)
        val rounded = if (raw.isFinite()) raw.roundToLong() else parameters.maximumIntervalDays.toLong()
        return min(max(rounded, 1L), parameters.maximumIntervalDays.toLong()).toInt()
    }

    /** Applique une note à une carte et rend la carte replanifiée + le journal. */
    fun review(card: FsrsCard, rating: FsrsRating, at: Long): FsrsOutcome {
        val elapsedDays = card.lastReview?.let { max(0.0, (at - it).toDouble() / DAY_MS) } ?: 0.0
        val stabilityBefore = card.stability

        var difficulty: Double
        var stability: Double
        var state: FsrsState
        var lapses = card.lapses

        if (card.state == FsrsState.new) {
            difficulty = initialDifficulty(rating)
            stability = max(initialStability(rating), MIN_STABILITY)
            state = if (rating == FsrsRating.again) FsrsState.learning else FsrsState.review
        } else if (elapsedDays < 1) {
            // Révision le MÊME jour : formule court terme (FSRS-5).
            difficulty = nextDifficulty(card.difficulty, rating)
            stability = max(shortTermStability(card.stability, rating), MIN_STABILITY)
            if (rating == FsrsRating.again) { lapses += 1; state = FsrsState.relearning }
            else state = FsrsState.review
        } else {
            val r = retrievability(elapsedDays, card.stability)
            difficulty = nextDifficulty(card.difficulty, rating)
            if (rating == FsrsRating.again) {
                lapses += 1
                stability = max(forgetStability(card.difficulty, card.stability, r), MIN_STABILITY)
                state = FsrsState.relearning
            } else {
                stability = max(recallStability(card.difficulty, card.stability, r, rating), MIN_STABILITY)
                state = FsrsState.review
            }
        }

        val interval = intervalDays(stability)
        val next = FsrsCard(
            stability = stability, difficulty = difficulty, state = state,
            reps = card.reps + 1, lapses = lapses,
            lastReview = at, due = at + interval * DAY_MS,
        )
        return FsrsOutcome(
            card = next, rating = rating, reviewedAt = at, elapsedDays = elapsedDays,
            scheduledDays = interval.toDouble(),
            stabilityBefore = stabilityBefore, stabilityAfter = stability,
        )
    }

    // MARK: Formules FSRS-5

    /** Stabilité initiale (première révision) = poids de la note. */
    fun initialStability(rating: FsrsRating): Double = w[rating.raw - 1]

    /** Difficulté initiale D₀(G) = w4 − e^{w5·(G−1)} + 1, bornée [1, 10]. */
    fun initialDifficulty(rating: FsrsRating): Double =
        clampDifficulty(w[4] - exp(w[5] * (rating.raw - 1)) + 1)

    /** Amortissement linéaire, puis retour à la moyenne vers D₀(Facile). */
    fun nextDifficulty(difficulty: Double, rating: FsrsRating): Double {
        val deltaD = -w[6] * (rating.raw - 3)
        val damped = difficulty + deltaD * (10 - difficulty) / 9
        val anchor = clampDifficulty(w[4] - exp(w[5] * 3) + 1)   // D₀(Easy)
        return clampDifficulty(w[7] * anchor + (1 - w[7]) * damped)
    }

    /** Stabilité après un RAPPEL réussi (hard/good/easy). */
    fun recallStability(d: Double, s: Double, r: Double, rating: FsrsRating): Double {
        val hardPenalty = if (rating == FsrsRating.hard) w[15] else 1.0
        val easyBonus = if (rating == FsrsRating.easy) w[16] else 1.0
        return s * (1 + exp(w[8]) * (11 - d) * s.pow(-w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
    }

    /** Stabilité après un OUBLI (again). */
    fun forgetStability(d: Double, s: Double, r: Double): Double =
        w[11] * d.pow(-w[12]) * ((s + 1).pow(w[13]) - 1) * exp((1 - r) * w[14])

    /** Stabilité court terme (révision le même jour). */
    fun shortTermStability(s: Double, rating: FsrsRating): Double =
        s * exp(w[17] * (rating.raw - 3 + w[18]))

    private fun clampDifficulty(d: Double): Double = min(max(d, 1.0), 10.0)
}
