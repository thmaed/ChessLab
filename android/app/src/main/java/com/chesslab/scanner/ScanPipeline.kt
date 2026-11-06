package com.chesslab.scanner

import android.content.Context
import android.graphics.Bitmap
import com.chesslab.vision.BoardConsistency
import com.chesslab.vision.BoardReader
import com.chesslab.vision.BoardRectifier
import com.chesslab.vision.Homography
import com.chesslab.vision.PieceDetector

/**
 * La lecture d'un plateau, de l'image et des quatre coins à la grille de
 * confiances — pendant de `ScannerViewModel.rectifyAndScan` (ChessLab).
 *
 * Redressement UNIQUE en 800 × 800, recalage de la grille sur les lignes du
 * damier, puis deux lecteurs indépendants sur les mêmes vignettes : le
 * détecteur (sur l'image recadrée sur la grille) et les gabarits (sur les
 * 64 vignettes). Chacun passe par les contrôles de cohérence d'échecs
 * ([BoardConsistency]) ; la lecture du détecteur est ensuite RECROISÉE avec
 * celle des gabarits, qui ne fait que signaler, jamais réécrire.
 */
object ScanPipeline {

    class Result(val reading: ScanReading, val detections: Int)

    /** `null` si le modèle de reconnaissance est absent — le scanner le dit plutôt que de mentir. */
    fun read(context: Context, source: Bitmap, corners: List<Homography.Point>): Result? {
        val detector = PieceDetector.shared(context) ?: return null

        val rectified = BoardRectifier.rectify(source, corners)
        val luminance = BoardRectifier.luminance(rectified)
        val grid = BoardRectifier.grid(luminance)

        val detections = detector.detect(BoardRectifier.alignedToGrid(rectified, grid))
        val primary = ScanReading(BoardConsistency.reconciled(BoardReader.grid(detections)))

        val templates = TemplateSquareClassifier.shared(context)
        val secondary = ScanReading(
            BoardConsistency.reconciled(templates.classify(BoardRectifier.patches(luminance, grid)))
        )
        return Result(primary.crossChecked(secondary), detections.size)
    }
}
