package com.chesslab.lab

import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Le résultat d'une partie DU POINT DE VUE DU CAMP A — celui réglé à gauche.
 *
 * L'alternance des couleurs (A joue tantôt Blanc, tantôt Noir) est déjà
 * résolue en amont : ici A désigne toujours le même réglage, quelle que soit
 * sa couleur. C'est exactement ce qu'il faut pour estimer un écart Elo que
 * l'avantage du trait ne fausse pas.
 */
enum class LabGameResult { winA, draw, winB }

/** Une partie terminée de la série, telle qu'on la garde pour le bilan. */
data class LabCompletedGame(
    val index: Int,
    /** A jouait-il les Blancs dans CETTE partie ? */
    val aWasWhite: Boolean,
    /** Le résultat côté échiquier : « 1-0 », « 0-1 », « 1/2-1/2 ». */
    val pgnResult: String,
    /** La raison de la fin, en clair. */
    val reasonLabel: String,
    val plyCount: Int,
    val pgn: String,
) {
    /** Le résultat rapporté au camp A, indépendant de la couleur. */
    val labResult: LabGameResult
        get() = when (pgnResult) {
            "1-0" -> if (aWasWhite) LabGameResult.winA else LabGameResult.winB
            "0-1" -> if (aWasWhite) LabGameResult.winB else LabGameResult.winA
            else -> LabGameResult.draw
        }
}

/**
 * Le bilan agrégé d'une série. Pendant de `LabStats.swift`.
 *
 * Entièrement PUR : score, écart Elo, intervalle de confiance et LOS ne
 * dépendent que des comptes et de la longueur des parties. C'est ce qui rend
 * ces chiffres vérifiables sans lancer un seul moteur — et ils méritent de
 * l'être, puisque c'est sur eux qu'on décide si une série a tranché.
 */
data class LabStats(
    /** Longueurs en DEMI-COUPS, une entrée par partie terminée. */
    val plyCounts: List<Int>,
    val winsA: Int,
    val draws: Int,
    val winsB: Int,
) {
    val games: Int get() = winsA + draws + winsB

    /** Le score de A au sens échiquéen : 1 par gain, ½ par nulle. */
    val score: Double
        get() = if (games == 0) 0.0 else (winsA + 0.5 * draws) / games

    val scorePercent: Double get() = score * 100

    val averagePlies: Double
        get() = if (plyCounts.isEmpty()) 0.0 else plyCounts.sum().toDouble() / plyCounts.size

    /** La longueur moyenne en COUPS COMPLETS (un coup = deux demi-coups). */
    val averageMoves: Double get() = averagePlies / 2

    /**
     * L'écart Elo estimé de A par rapport à B : −400·log₁₀(1/score − 1).
     *
     * `null` quand le score vaut 0 ou 1 : l'écart y est théoriquement infini,
     * ce qui veut simplement dire qu'il y a trop peu de données pour trancher.
     */
    val eloDifference: Double? get() = elo(score)

    /**
     * L'intervalle de confiance à 95 % sur l'écart Elo. `null` s'il n'est pas
     * calculable — moins de deux parties, ou bornes dégénérées.
     */
    val elo95ConfidenceInterval: Pair<Double, Double>?
        get() {
            val se = scoreStandardError ?: return null
            val low = elo(clampScore(score - 1.96 * se)) ?: return null
            val high = elo(clampScore(score + 1.96 * se)) ?: return null
            return low to high
        }

    /**
     * LOS — la probabilité que A soit RÉELLEMENT plus fort que B, et non que
     * l'écart observé vienne du hasard.
     *
     * Estimée sur les seules parties DÉCISIVES : une nulle ne dit rien sur qui
     * est le plus fort. 0,5 quand rien n'a été décidé.
     */
    val likelihoodOfSuperiority: Double
        get() {
            val decisive = winsA + winsB
            if (decisive == 0) return 0.5
            val x = (winsA - winsB) / (sqrt(2.0) * sqrt(decisive.toDouble()))
            return 0.5 * (1 + erf(x))
        }

    /**
     * L'erreur standard du score moyen (résultats codés 1 / ½ / 0).
     *
     * Deux correctifs venus d'iOS, qui changent les chiffres affichés et
     * méritent donc d'être dits :
     * - **Bessel** (`n − 1`, pas `n`) : ces `n` parties ESTIMENT une force
     *   inconnue ; diviser par `n` sous-estime l'incertitude — 5 % trop
     *   étroit à dix parties, négligeable à cent ;
     * - **terme de continuité (Wilson)** : sans lui, un échantillon dont
     *   toutes les parties partagent le même résultat (deux nulles d'affilée,
     *   par exemple) donne une variance EXACTEMENT nulle, donc un intervalle
     *   de largeur nulle : une fausse certitude à 95 % après trois parties.
     *   `z²/(4n²)` est le terme que Wilson ajoute à cette même place.
     */
    internal val scoreStandardError: Double?
        get() {
            if (games <= 1) return null
            val n = games.toDouble()
            val sumSquares = winsA * 1.0 + draws * 0.25       // + winsB * 0
            val sampleVariance = max(0.0, (sumSquares - n * score * score) / (n - 1))
            val continuityTerm = (1.96 * 1.96) / (4 * n * n)
            return sqrt(sampleVariance / n + continuityTerm)
        }

    private fun clampScore(s: Double): Double = min(max(s, 1e-6), 1 - 1e-6)

    companion object {
        fun of(results: List<LabGameResult>, plyCounts: List<Int>) = LabStats(
            plyCounts = plyCounts,
            winsA = results.count { it == LabGameResult.winA },
            draws = results.count { it == LabGameResult.draw },
            winsB = results.count { it == LabGameResult.winB },
        )

        fun elo(score: Double): Double? =
            if (score <= 0.0 || score >= 1.0) null else -400 * log10(1 / score - 1)

        /**
         * La courbe de progression : un point par partie, score CUMULÉ de A
         * avec sa bande de confiance — qui se resserre à mesure que la série
         * devient significative. Tant qu'elle chevauche les 50 %, rien n'est
         * tranché ; c'est son rétrécissement qui dit quand s'arrêter.
         */
        fun progression(games: List<LabCompletedGame>): List<LabProgressPoint> =
            games.indices.map { index ->
                val prefix = games.subList(0, index + 1)
                val stats = of(prefix.map { it.labResult }, prefix.map { it.plyCount })
                val margin = 1.96 * (stats.scoreStandardError ?: 0.0)
                LabProgressPoint(
                    game = index + 1,
                    scorePercent = stats.score * 100,
                    ciLow = max(0.0, stats.score - margin) * 100,
                    ciHigh = min(1.0, stats.score + margin) * 100,
                    result = games[index].labResult,
                )
            }

        /**
         * La fonction d'erreur, que la bibliothèque standard de Kotlin n'a
         * pas — contrairement au C dont Swift hérite `erf`. Approximation
         * d'Abramowitz & Stegun 7.1.26, exacte à 1,5·10⁻⁷ : bien au-delà de
         * ce qu'un pourcentage affiché demande.
         */
        internal fun erf(x: Double): Double {
            val sign = if (x < 0) -1.0 else 1.0
            val a = kotlin.math.abs(x)
            val t = 1.0 / (1.0 + 0.3275911 * a)
            val y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t +
                0.254829592) * t * kotlin.math.exp(-a * a)
            return sign * y
        }
    }
}

/** Un point de la courbe de progression : le score cumulé de A après `game`. */
data class LabProgressPoint(
    /** Le numéro de partie, à partir de 1. */
    val game: Int,
    val scorePercent: Double,
    /** Les bornes du score en %, à 95 %, dans [0 ; 100]. */
    val ciLow: Double,
    val ciHigh: Double,
    val result: LabGameResult,
)
