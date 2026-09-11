package com.chesslab.vision

import android.graphics.Bitmap
import android.graphics.Color

/**
 * Le pont entre une image Android et [CheckerboardDetector].
 *
 * Le détecteur est de l'arithmétique pure — il ne connaît qu'un tableau de
 * niveaux de gris — et c'est ce qui le rend testable sans appareil. Tout ce
 * qui touche à `Bitmap` vit donc ici, et nulle part ailleurs.
 */
object BoardAutoFrame {

    /**
     * Cherche le plateau dans [bitmap].
     *
     * @return les quatre coins en FRACTIONS de l'image (0…1), dans l'ordre
     *   haut-gauche, haut-droit, bas-droit, bas-gauche — celui qu'attendent le
     *   cadrage manuel et l'homographie — ou `null` si rien de convaincant.
     *   Ce n'est jamais une vérité : cela pré-positionne les poignées, que
     *   l'utilisateur garde la main de corriger.
     */
    fun corners(bitmap: Bitmap, minimumScore: Double = 0.55): List<Pair<Float, Float>>? {
        val r = rect(bitmap, minimumScore) ?: return null
        val w = bitmap.width.toDouble()
        val h = bitmap.height.toDouble()
        val left = (r.x / w).toFloat()
        val top = (r.y / h).toFloat()
        val right = (r.right / w).toFloat()
        val bottom = (r.bottom / h).toFloat()
        return listOf(left to top, right to top, right to bottom, left to bottom)
    }

    /** Le cadre en pixels, pour qui veut la mesure brute. */
    fun rect(bitmap: Bitmap, minimumScore: Double = 0.55): BoardRect? =
        detect(bitmap, minimumScore)?.rect

    /** Le cadre ET son score, pour décider si l'on s'y fie. */
    fun detect(bitmap: Bitmap, minimumScore: Double = 0.55): CheckerboardDetector.Result? {
        val side = CheckerboardDetector.ANALYSIS_SIDE
        val gray = grayscale(bitmap, side)
        return CheckerboardDetector.detect(gray, bitmap.width, bitmap.height, side, minimumScore)
    }

    /**
     * Niveaux de gris (0…1) sur un carré de [side] côtés.
     *
     * Le redimensionnement passe par `Bitmap.createScaledBitmap` avec filtrage,
     * et non par un échantillonnage au plus proche : les lignes fines d'un
     * damier disparaissent sans moyennage, et c'est précisément d'elles que
     * vit le détecteur.
     */
    fun grayscale(bitmap: Bitmap, side: Int): DoubleArray {
        val scaled = Bitmap.createScaledBitmap(bitmap, side, side, true)
        val pixels = IntArray(side * side)
        scaled.getPixels(pixels, 0, side, 0, 0, side, side)
        if (scaled !== bitmap) scaled.recycle()
        return DoubleArray(side * side) { i ->
            val p = pixels[i]
            (0.299 * Color.red(p) + 0.587 * Color.green(p) + 0.114 * Color.blue(p)) / 255.0
        }
    }
}
