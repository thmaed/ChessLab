package com.chesslab.vision

import kotlin.math.abs

/**
 * Recalage de la grille 8×8 sur une image de plateau **déjà redressée**.
 *
 * Traduction de `BoardGridFinder.swift` (ChessLab), ligne à ligne : mêmes
 * tolérances, même recherche exhaustive (pas × phase) puis deux passes
 * d'affinage, même règle d'ex æquo. Les raisons de chaque choix sont dans le
 * Swift, qui fait foi — notamment pourquoi la grille a le droit de déborder de
 * l'image (cadrage serré) et pourquoi les deux extrémités du profil sont
 * exclues.
 *
 * Pourquoi ce recalage : la détection automatique rend un quadrilatère
 * quelque 3 % trop grand même sur une capture parfaite. Après redressement, le
 * plateau est réduit et décalé d'environ 14 px dans 800 ; découper en huitièmes
 * exacts fait mordre chaque vignette sur sa voisine.
 *
 * Pur : prend une luminance carrée (`side` × `side`, valeurs 0…1) et rend les
 * bornes des 9 lignes dans le repère de cette image.
 *
 * - note: écart assumé avec iOS — l'entrée est TOUJOURS carrée (le
 *   redressement sort 800 × 800), donc le rééchantillonnage que fait iOS pour
 *   ramener une image non carrée à son plus petit côté n'a pas lieu d'être.
 */
object BoardGridFinder {

    /** Bornes des 9 lignes de la grille, en pixels de l'image redressée. */
    class Grid(val columns: DoubleArray, val rows: DoubleArray) {
        override fun equals(other: Any?) =
            other is Grid && columns.contentEquals(other.columns) && rows.contentEquals(other.rows)

        override fun hashCode() = 31 * columns.contentHashCode() + rows.contentHashCode()

        companion object {
            /** Grille naïve : huit parts égales — le repli quand le recalage n'inspire pas confiance. */
            fun uniform(width: Int, height: Int) = Grid(
                DoubleArray(9) { it * width / 8.0 },
                DoubleArray(9) { it * height / 8.0 },
            )
        }
    }

    /** Tolérance de recherche autour du pas théorique (`côté / 8`). */
    private const val PERIOD_TOLERANCE = 0.12

    /** Décalage exploré, en fraction du pas. */
    private const val PHASE_TOLERANCE = 0.30

    /** Combien des 9 lignes doivent tomber DANS l'image pour qu'une grille soit jugeable. */
    private const val MINIMUM_LINES_INSIDE_IMAGE = 7

    /** Deux scores plus proches que ça sont tenus pour ex æquo. */
    private const val SCORE_TIE_TOLERANCE = 1e-9

    /** Nombre de crans de part et d'autre du centre, dans chaque passe. */
    private const val SEARCH_STEPS = 12

    /** Passes d'affinage après la passe grossière. */
    private const val REFINEMENT_PASSES = 2

    /** Côté minimal analysable, comme iOS. */
    private const val MINIMUM_SIDE = 64

    /**
     * Recale la grille sur les lignes du damier.
     *
     * @return la grille recalée, ou la grille uniforme si l'image ne présente
     * aucune structure périodique exploitable — on ne remplace jamais une
     * hypothèse discutable par une hypothèse pire.
     */
    fun grid(luminance: DoubleArray, side: Int): Grid {
        require(luminance.size == side * side) { "luminance carrée attendue" }
        val uniform = Grid.uniform(side, side)
        if (side < MINIMUM_SIDE) return uniform

        val vertical = edgeProfile(luminance, side, alongColumns = true)
        val horizontal = edgeProfile(luminance, side, alongColumns = false)

        // Bornage : une grille qui déborde ferait rogner la découpe en silence.
        return Grid(
            clamped(lines(vertical) ?: uniform.columns, side),
            clamped(lines(horizontal) ?: uniform.rows, side),
        )
    }

    private fun clamped(lines: DoubleArray, size: Int) =
        DoubleArray(lines.size) { lines[it].coerceIn(0.0, size.toDouble()) }

    // MARK: Profil de contours

    /**
     * Force des contours le long d'une direction, mesurée par la **médiane**
     * des gradients — pas leur moyenne : une ligne du damier traverse l'image
     * de part en part, le bord d'une dame n'en touche qu'une poignée.
     *
     * Les deux valeurs extrêmes du profil restent à zéro (dérivée centrée).
     */
    fun edgeProfile(luminance: DoubleArray, side: Int, alongColumns: Boolean): DoubleArray {
        val profile = DoubleArray(side)
        val gradients = DoubleArray(side)
        for (index in 1 until side - 1) {
            for (other in 0 until side) {
                val before = if (alongColumns) luminance[other * side + index - 1] else luminance[(index - 1) * side + other]
                val after = if (alongColumns) luminance[other * side + index + 1] else luminance[(index + 1) * side + other]
                gradients[other] = abs(after - before)
            }
            profile[index] = median(gradients)
        }
        return profile
    }

    /** Médiane d'un échantillon (la moyenne des deux valeurs centrales si le nombre est pair). */
    fun median(values: DoubleArray): Double {
        if (values.isEmpty()) return 0.0
        val sorted = values.copyOf().also { it.sort() }
        val middle = sorted.size / 2
        return if (sorted.size % 2 == 0) (sorted[middle - 1] + sorted[middle]) / 2 else sorted[middle]
    }

    // MARK: Recherche du pas et de la phase

    private class Candidate(val score: Double, val period: Double, val phase: Double)

    /** Le couple (pas, phase) qui aligne 9 lignes équidistantes sur les crêtes du profil, puis ses 9 positions. */
    private fun lines(profile: DoubleArray): DoubleArray? {
        val side = profile.size.toDouble()
        val idealPeriod = side / 8

        var periodRadius = idealPeriod * PERIOD_TOLERANCE
        var phaseRadius = idealPeriod * PHASE_TOLERANCE
        var best = search(profile, side, idealPeriod, idealPeriod, periodRadius, 0.0, phaseRadius) ?: return null

        for (pass in 0 until REFINEMENT_PASSES) {
            periodRadius /= SEARCH_STEPS
            phaseRadius /= SEARCH_STEPS
            val refined = search(profile, side, idealPeriod, best.period, periodRadius, best.phase, phaseRadius) ?: break
            best = refined
        }

        if (best.score <= 0) return null
        return DoubleArray(9) { best.phase + it * best.period }
    }

    /** Le meilleur couple d'une fenêtre de recherche ; les ex æquo vont vers la grille la plus simple. */
    private fun search(
        profile: DoubleArray, side: Double, idealPeriod: Double,
        periodCenter: Double, periodRadius: Double,
        phaseCenter: Double, phaseRadius: Double,
    ): Candidate? {
        var best: Candidate? = null
        var bestDistanceToUniform = Double.POSITIVE_INFINITY

        for (periodStep in -SEARCH_STEPS..SEARCH_STEPS) {
            val period = periodCenter + periodStep.toDouble() / SEARCH_STEPS * periodRadius
            if (period <= 0) continue

            for (phaseStep in -SEARCH_STEPS..SEARCH_STEPS) {
                val phase = phaseCenter + phaseStep.toDouble() / SEARCH_STEPS * phaseRadius

                var score = 0.0
                var visibleLines = 0
                for (line in 0..8) {
                    val position = phase + line * period
                    // `1` et `side - 2`, pas `0` et `side - 1` : les extrémités du
                    // profil valent structurellement zéro (dérivée centrée).
                    if (position < 1 || position > side - 2) continue
                    score += sample(profile, position)
                    visibleLines++
                }
                if (visibleLines < MINIMUM_LINES_INSIDE_IMAGE) continue

                val distanceToUniform = abs(period - idealPeriod) + abs(phase)
                val current = best
                if (current == null) {
                    best = Candidate(score, period, phase)
                    bestDistanceToUniform = distanceToUniform
                    continue
                }
                // Tolérance RELATIVE : les scores sont des sommes de doubles.
                val tolerance = current.score * SCORE_TIE_TOLERANCE
                val isBetter = score > current.score + tolerance
                val isTied = abs(score - current.score) <= tolerance
                if (isBetter || (isTied && distanceToUniform < bestDistanceToUniform)) {
                    best = Candidate(score, period, phase)
                    bestDistanceToUniform = distanceToUniform
                }
            }
        }
        return best
    }

    /** Valeur du profil à une position fractionnaire, interpolée ; hors bornes : 0. */
    private fun sample(profile: DoubleArray, position: Double): Double {
        if (position < 0 || position > (profile.size - 1).toDouble()) return 0.0
        val lower = kotlin.math.floor(position).toInt()
        val upper = minOf(lower + 1, profile.size - 1)
        val fraction = position - lower
        return profile[lower] * (1 - fraction) + profile[upper] * fraction
    }
}
