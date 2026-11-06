package com.chesslab.vision

import android.graphics.Bitmap
import kotlin.math.ceil
import kotlin.math.floor

/**
 * Du plateau photographié aux 64 vignettes — pendant de `BoardRectifier.swift`
 * et de `BoardScanner.alignedToGrid` (ChessLab).
 *
 * Chaîne : redressement du quadrilatère en 800 × 800 → recalage de la grille
 * sur les lignes du damier ([BoardGridFinder]) → image recadrée sur cette
 * grille (pour le détecteur) et vignettes découpées sur elle (pour les
 * gabarits). Le redressement est échantillonné en sens INVERSE, bilinéaire.
 */
object BoardRectifier {

    /** Côté de l'image redressée, comme iOS (`BoardRectifier.normalizedSide`). */
    const val NORMALIZED_SIDE = 800

    /** Marge rognée sur chaque bord de vignette, en fraction du côté de la case. */
    const val EDGE_INSET = 0.02

    /** Côté des vignettes comparées aux gabarits (`TemplateSquareClassifier.patchSide`). */
    const val PATCH_SIDE = 32

    /** Le quadrilatère [corners] de [source] ramené à un carré de [side] px. */
    fun rectify(source: Bitmap, corners: List<Homography.Point>, side: Int = NORMALIZED_SIDE): Bitmap {
        val h = Homography.fromSquare(corners, side.toDouble())
        val width = source.width
        val height = source.height
        val pixels = IntArray(width * height)
        source.getPixels(pixels, 0, width, 0, 0, width, height)

        val out = IntArray(side * side)
        for (y in 0 until side) for (x in 0 until side) {
            val p = Homography.map(h, x + 0.5, y + 0.5)
            out[y * side + x] = bilinear(pixels, width, height, p.x - 0.5, p.y - 0.5)
        }
        return Bitmap.createBitmap(out, side, side, Bitmap.Config.ARGB_8888)
    }

    private fun bilinear(pixels: IntArray, width: Int, height: Int, fx: Double, fy: Double): Int {
        val x0 = floor(fx).toInt(); val y0 = floor(fy).toInt()
        val tx = fx - x0; val ty = fy - y0
        fun at(x: Int, y: Int) = pixels[y.coerceIn(0, height - 1) * width + x.coerceIn(0, width - 1)]
        val c00 = at(x0, y0); val c10 = at(x0 + 1, y0); val c01 = at(x0, y0 + 1); val c11 = at(x0 + 1, y0 + 1)
        var result = 0xFF shl 24
        for (shift in intArrayOf(16, 8, 0)) {
            val top = ((c00 shr shift) and 0xFF) * (1 - tx) + ((c10 shr shift) and 0xFF) * tx
            val bottom = ((c01 shr shift) and 0xFF) * (1 - tx) + ((c11 shr shift) and 0xFF) * tx
            result = result or ((top * (1 - ty) + bottom * ty).toInt().coerceIn(0, 255) shl shift)
        }
        return result
    }

    /** La luminance (0…1) d'une image carrée, ligne par ligne. */
    fun luminance(square: Bitmap): DoubleArray {
        val side = square.width
        val pixels = IntArray(side * square.height)
        square.getPixels(pixels, 0, side, 0, 0, side, square.height)
        return DoubleArray(pixels.size) { ImagePatch.luma(pixels[it]) }
    }

    /** La grille recalée de l'image redressée [rectified], dont [luminance] est la luminance. */
    fun grid(luminance: DoubleArray): BoardGridFinder.Grid = BoardGridFinder.grid(luminance, NORMALIZED_SIDE)

    /**
     * L'image redressée recadrée sur la grille puis remise à 800 × 800 : ce que
     * voit le détecteur. Même idée qu'iOS (`alignedToGrid`) — sans elle, le
     * plateau n'occupe que ~96 % de l'image et chaque case est décalée.
     * Rend [rectified] telle quelle si la grille est dégénérée.
     */
    fun alignedToGrid(rectified: Bitmap, grid: BoardGridFinder.Grid): Bitmap {
        val left = floor(grid.columns.first()).toInt()
        val top = floor(grid.rows.first()).toInt()
        val right = ceil(grid.columns.last()).toInt()
        val bottom = ceil(grid.rows.last()).toInt()
        if (right - left <= 0 || bottom - top <= 0) return rectified
        val cropped = Bitmap.createBitmap(rectified, left, top, right - left, bottom - top)
        return Bitmap.createScaledBitmap(cropped, NORMALIZED_SIDE, NORMALIZED_SIDE, true)
    }

    /**
     * Les 64 vignettes `[ligne][colonne]` (ligne 0 en haut) découpées sur la
     * grille, ramenées à [PATCH_SIDE] × [PATCH_SIDE]. Rognées de [EDGE_INSET]
     * à l'intérieur des lignes : sans cela, chaque vignette emporte un liseré
     * de la case voisine, de couleur opposée.
     */
    fun patches(luminance: DoubleArray, grid: BoardGridFinder.Grid): Array<Array<DoubleArray>> =
        Array(8) { row ->
            Array(8) { column ->
                val width = grid.columns[column + 1] - grid.columns[column]
                val height = grid.rows[row + 1] - grid.rows[row]
                // `CGRect.integral` : l'enveloppe entière du rectangle.
                val x0 = floor(grid.columns[column] + width * EDGE_INSET).toInt()
                val y0 = floor(grid.rows[row] + height * EDGE_INSET).toInt()
                val x1 = ceil(grid.columns[column] + width * EDGE_INSET + width * (1 - 2 * EDGE_INSET)).toInt()
                val y1 = ceil(grid.rows[row] + height * EDGE_INSET + height * (1 - 2 * EDGE_INSET)).toInt()
                ImagePatch.patch(
                    luminance, NORMALIZED_SIDE,
                    x0.coerceIn(0, NORMALIZED_SIDE - 1), y0.coerceIn(0, NORMALIZED_SIDE - 1),
                    x1.coerceIn(1, NORMALIZED_SIDE), y1.coerceIn(1, NORMALIZED_SIDE),
                    PATCH_SIDE,
                )
            }
        }
}
