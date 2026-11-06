package com.chesslab.scanner

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.ContextCompat
import chesskit.Piece
import com.chesslab.R
import com.chesslab.ui.BoardTheme
import com.chesslab.vision.BoardRectifier
import com.chesslab.vision.ImagePatch
import com.chesslab.vision.SquareReading

/**
 * Reconnaissance des pièces d'un diagramme numérique par corrélation contre des
 * gabarits — le « second avis » qui recroise le détecteur.
 *
 * Pendant de `TemplateSquareClassifier.swift` (ChessLab) : même mesure (ZNCC,
 * produit scalaire de vignettes centrées-réduites), mêmes seuils, même calcul de
 * confiance, mêmes gabarits (12 pièces × 2 fonds × 4 thèmes × 3 échelles de
 * glyphe, cburnett). Les gabarits se rendent ici depuis les drawables `piece_*`.
 *
 * - note: écart assumé — iOS déduit la source (capture ou photo d'un écran) et
 *   assouplit ses seuils pour une photo. Android n'a pas cette déduction : ce
 *   sont toujours les seuils d'une capture (0,45 / 0,035). Voir `PARITE.md`.
 */
class TemplateSquareClassifier private constructor(private val templates: List<Template>) {

    class Template(val color: Piece.Color, val kind: Piece.Kind, val normalized: DoubleArray)

    /** Lecture d'une vignette `PATCH_SIDE × PATCH_SIDE` (luminance 0…1). */
    fun classify(patch: DoubleArray): SquareReading {
        // Une case vide est un aplat : rien à corréler.
        if (ImagePatch.standardDeviation(patch) < FLATNESS_THRESHOLD) return SquareReading(null, null, 1.0)

        // Coordonnées incrustées : un « 8 » dans le COIN d'une case vide la rend
        // contrastée, mais son CENTRE reste un aplat — une pièce couvre toujours
        // le centre.
        val central = ImagePatch.centralRegion(patch, BoardRectifier.PATCH_SIDE, 0.6)
        if (ImagePatch.standardDeviation(central) < FLATNESS_THRESHOLD) return SquareReading(null, null, 0.9)

        val normalized = ImagePatch.normalize(patch) ?: return SquareReading(null, null, 1.0)

        var best: Template? = null
        var bestScore = 0.0
        var bestOtherPieceScore = -1.0
        for (template in templates) {
            val score = ImagePatch.dot(normalized, template.normalized)
            val current = best
            if (current != null && score <= bestScore) {
                if (template.kind != current.kind || template.color != current.color) {
                    bestOtherPieceScore = maxOf(bestOtherPieceScore, score)
                }
                continue
            }
            if (current != null && (template.kind != current.kind || template.color != current.color)) {
                bestOtherPieceScore = maxOf(bestOtherPieceScore, bestScore)
            }
            best = template
            bestScore = score
        }

        val found = best
        // Du contraste, mais qui ne ressemble à aucune pièce : « vide », confiance basse.
        if (found == null || bestScore < MATCH_THRESHOLD) return SquareReading(null, null, 0.3)
        return SquareReading(found.kind, found.color, confidence(bestScore, bestOtherPieceScore))
    }

    /** Qualité du score ET avance sur la meilleure AUTRE pièce. */
    private fun confidence(best: Double, runnerUp: Double): Double {
        val quality = best.coerceIn(0.0, 1.0)
        val margin = ((best - runnerUp).coerceAtLeast(0.0) * 4).coerceAtMost(1.0)
        return (quality * 0.65 + margin * 0.35).coerceIn(0.0, 1.0)
    }

    /** Lecture de la grille entière `[ligne][colonne]` à partir de ses 64 vignettes. */
    fun classify(patches: Array<Array<DoubleArray>>): Array<Array<SquareReading>> =
        Array(8) { row -> Array(8) { column -> classify(patches[row][column]) } }

    companion object {
        /** Seuil de score (capture d'écran) au-delà duquel on considère qu'il y a une pièce. */
        const val MATCH_THRESHOLD = 0.45

        /** Écart-type en deçà duquel la case est jugée vide (capture d'écran). */
        const val FLATNESS_THRESHOLD = 0.035

        private const val GLYPH_SCALES = 3

        @Volatile private var instance: TemplateSquareClassifier? = null

        /** Vrai quand les gabarits sont déjà rendus : la prochaine lecture n'a rien à attendre. */
        val isReady: Boolean get() = instance != null

        /** Construit une fois (≈ 300 gabarits rendus) puis réutilise. */
        @Synchronized
        fun shared(context: Context): TemplateSquareClassifier =
            instance ?: TemplateSquareClassifier(makeTemplates(context.applicationContext)).also { instance = it }

        /** `piece_wp`, `piece_bk`… : le nom du drawable d'une pièce. */
        private fun drawableName(color: Piece.Color, kind: Piece.Kind): String {
            val c = if (color == Piece.Color.white) "w" else "b"
            val k = when (kind) {
                Piece.Kind.king -> "k"; Piece.Kind.queen -> "q"; Piece.Kind.rook -> "r"
                Piece.Kind.bishop -> "b"; Piece.Kind.knight -> "n"; Piece.Kind.pawn -> "p"
            }
            return "piece_$c$k"
        }

        /**
         * Les 12 pièces × (case claire, case sombre) de chaque thème × 3
         * échelles : deux fonds parce qu'un glyphe blanc sur case claire et sur
         * case sombre ne dessinent pas le même motif, plusieurs échelles parce
         * que la marge autour de la pièce varie d'un site à l'autre.
         */
        private fun makeTemplates(context: Context): List<Template> {
            val side = BoardRectifier.PATCH_SIDE * 4
            val templates = ArrayList<Template>()
            for (color in Piece.Color.entries) for (kind in Piece.Kind.entries) {
                val id = context.resources.getIdentifier(drawableName(color, kind), "drawable", context.packageName)
                val glyph = ContextCompat.getDrawable(context, id)?.mutate() ?: continue
                for (theme in BoardTheme.all) {
                    for (background in intArrayOf(theme.lightSquare.toArgb(), theme.darkSquare.toArgb())) {
                        for (scale in doubleArrayOf(0.78, 0.9, 1.0)) {
                            val bitmap = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
                            val canvas = Canvas(bitmap)
                            canvas.drawColor(background)
                            val glyphSide = side * scale
                            val inset = ((side - glyphSide) / 2).toInt()
                            glyph.setBounds(inset, inset, side - inset, side - inset)
                            glyph.draw(canvas)

                            val pixels = IntArray(side * side)
                            bitmap.getPixels(pixels, 0, side, 0, 0, side, side)
                            bitmap.recycle()
                            val lum = DoubleArray(pixels.size) { ImagePatch.luma(pixels[it]) }
                            val patch = ImagePatch.patch(lum, side, 0, 0, side, side, BoardRectifier.PATCH_SIDE)
                            ImagePatch.normalize(patch)?.let { templates += Template(color, kind, it) }
                        }
                    }
                }
            }
            return templates
        }
    }
}
