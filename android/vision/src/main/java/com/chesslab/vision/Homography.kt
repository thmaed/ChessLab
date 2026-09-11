package com.chesslab.vision

/**
 * Le redressement de perspective : quatre coins d'un quadrilatère vers un
 * carré.
 *
 * Pendant de `BoardRectifier.swift`, qui passe côté iOS par Core Image. Ici
 * l'homographie est calculée à la main — huit inconnues, huit équations, une
 * élimination de Gauss — puis l'image est échantillonnée en sens INVERSE :
 * pour chaque pixel de la sortie, on va chercher d'où il vient. C'est ce qui
 * évite les trous qu'un parcours direct laisserait.
 */
object Homography {

    /** Un point du plan image. */
    data class Point(val x: Double, val y: Double)

    /**
     * La matrice 3×3 (aplatie, h22 = 1) qui envoie le carré unité de côté
     * [side] sur le quadrilatère [corners], donné dans l'ordre
     * haut-gauche, haut-droit, bas-droit, bas-gauche.
     */
    fun fromSquare(corners: List<Point>, side: Double): DoubleArray {
        require(corners.size == 4) { "quatre coins attendus" }
        val dst = listOf(
            Point(0.0, 0.0), Point(side, 0.0), Point(side, side), Point(0.0, side),
        )

        // On résout H · dst = src : chaque paire donne deux équations.
        val a = Array(8) { DoubleArray(9) }
        for (i in 0 until 4) {
            val (u, v) = dst[i].let { it.x to it.y }
            val (x, y) = corners[i].let { it.x to it.y }
            a[i * 2] = doubleArrayOf(u, v, 1.0, 0.0, 0.0, 0.0, -u * x, -v * x, x)
            a[i * 2 + 1] = doubleArrayOf(0.0, 0.0, 0.0, u, v, 1.0, -u * y, -v * y, y)
        }
        return solve(a)
    }

    /** Où va le point ([x], [y]) du carré, dans l'image d'origine. */
    fun map(h: DoubleArray, x: Double, y: Double): Point {
        val w = h[6] * x + h[7] * y + 1.0
        return Point(
            (h[0] * x + h[1] * y + h[2]) / w,
            (h[3] * x + h[4] * y + h[5]) / w,
        )
    }

    /** Élimination de Gauss avec pivot partiel, sur un système 8×8 augmenté. */
    private fun solve(m: Array<DoubleArray>): DoubleArray {
        val n = 8
        for (col in 0 until n) {
            var pivot = col
            for (row in col + 1 until n) {
                if (kotlin.math.abs(m[row][col]) > kotlin.math.abs(m[pivot][col])) pivot = row
            }
            val tmp = m[col]; m[col] = m[pivot]; m[pivot] = tmp

            val head = m[col][col]
            if (kotlin.math.abs(head) < 1e-12) continue
            for (k in col..n) m[col][k] /= head

            for (row in 0 until n) {
                if (row == col) continue
                val factor = m[row][col]
                if (factor == 0.0) continue
                for (k in col..n) m[row][k] -= factor * m[col][k]
            }
        }
        return DoubleArray(n) { m[it][n] }
    }
}
