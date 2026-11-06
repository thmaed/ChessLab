package com.chesslab.vision

/**
 * Vignette en niveaux de gris et corrélation — traduction de `ImagePatch`
 * (`TemplateSquareClassifier.swift`, ChessLab).
 *
 * Pur et sans état : calcul sur des tableaux de luminance (0…1), testable sur
 * JVM. Le passage Bitmap → luminance est dans [BoardRectifier].
 */
object ImagePatch {

    /** Luminance d'un pixel ARGB, pondérations Rec. 601 (celles d'un gris « appareil »). */
    fun luma(argb: Int): Double {
        val r = (argb shr 16) and 0xFF
        val g = (argb shr 8) and 0xFF
        val b = argb and 0xFF
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }

    /**
     * La région [x0, x1) × [y0, y1) de [lum] (de largeur [stride]) ramenée à
     * [side] × [side] par MOYENNE de boîte : réduire un glyphe de 96 px à 32
     * sans crénelage, comme le fait l'interpolation « haute » d'iOS.
     */
    fun patch(lum: DoubleArray, stride: Int, x0: Int, y0: Int, x1: Int, y1: Int, side: Int): DoubleArray {
        val w = (x1 - x0).coerceAtLeast(1)
        val h = (y1 - y0).coerceAtLeast(1)
        val out = DoubleArray(side * side)
        for (j in 0 until side) {
            val ys = y0 + j * h / side
            val ye = maxOf(y0 + (j + 1) * h / side, ys + 1)
            for (i in 0 until side) {
                val xs = x0 + i * w / side
                val xe = maxOf(x0 + (i + 1) * w / side, xs + 1)
                var sum = 0.0
                for (y in ys until ye) for (x in xs until xe) sum += lum[y * stride + x]
                out[j * side + i] = sum / ((ye - ys) * (xe - xs))
            }
        }
        return out
    }

    /** Région centrale d'une vignette carrée : la fraction [fraction] du côté, centrée. */
    fun centralRegion(patch: DoubleArray, side: Int, fraction: Double): DoubleArray {
        val inset = (side * (1 - fraction) / 2).toInt()
        if (inset <= 0 || side - 2 * inset <= 0) return patch
        val inner = side - 2 * inset
        return DoubleArray(inner * inner) { patch[(inset + it / inner) * side + inset + it % inner] }
    }

    fun mean(values: DoubleArray): Double = if (values.isEmpty()) 0.0 else values.sum() / values.size

    fun standardDeviation(values: DoubleArray): Double {
        if (values.isEmpty()) return 0.0
        val average = mean(values)
        return Math.sqrt(values.sumOf { (it - average) * (it - average) } / values.size)
    }

    /**
     * Centre et réduit : la corrélation ZNCC de deux vecteurs ainsi normalisés
     * est leur simple produit scalaire. `null` sur un aplat (écart-type nul).
     */
    fun normalize(values: DoubleArray): DoubleArray? {
        val average = mean(values)
        val deviation = standardDeviation(values)
        if (deviation <= 1e-6) return null
        val scale = 1 / (deviation * Math.sqrt(values.size.toDouble()))
        return DoubleArray(values.size) { (values[it] - average) * scale }
    }

    /** Produit scalaire = ZNCC pour des vecteurs normalisés, dans -1…1. */
    fun dot(a: DoubleArray, b: DoubleArray): Double {
        if (a.size != b.size) return 0.0
        var sum = 0.0
        for (i in a.indices) sum += a[i] * b[i]
        return sum
    }
}
