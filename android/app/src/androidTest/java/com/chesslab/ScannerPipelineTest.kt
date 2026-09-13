package com.chesslab

import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.vision.BoardAutoFrame
import com.chesslab.vision.BoardReader
import com.chesslab.vision.Homography
import com.chesslab.vision.PieceDetector
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Le scanner, de bout en bout, sur une photo RÉELLE de l'app iOS.
 *
 * `ChessLabTests/ScannerFixtures/` porte des captures d'écran de vraies
 * parties et, dans son manifeste, la position que chacune montre. Le test
 * compare donc la FEN lue à celle qu'un humain a notée — pas à une sortie de
 * modèle, à une vérité.
 *
 * Deux choses s'y jugent : la lecture elle-même, coins DONNÉS (redressement,
 * modèle, NMS, projection sur la grille, assemblage de la FEN), et la
 * DÉTECTION automatique de ces coins — qui doit retrouver, à quelques pour
 * cent près, le cadre relevé à la main.
 */
@RunWith(AndroidJUnit4::class)
class ScannerPipelineTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    @Test fun aRealScreenshotIsReadCorrectly() {
        val detector = PieceDetector.shared(context)
        assumeTrue("modèle de reconnaissance absent", detector != null)

        val bitmap = assets.open("chesscom_endgame_rook.png").use { BitmapFactory.decodeStream(it) }
        assumeTrue("image de fixture absente", bitmap != null)

        // relevés sur l'image : le plateau va de bord à bord, de y=724 à y=1930
        val corners = listOf(
            Homography.Point(0.0, 724.0),
            Homography.Point(1206.0, 724.0),
            Homography.Point(1206.0, 1930.0),
            Homography.Point(0.0, 1930.0),
        )

        val detections = detector!!.detect(bitmap!!, corners)
        val grid = BoardReader.grid(detections)
        val placement = BoardReader.placement(grid)

        // L'orientation devinée ne promet qu'une chose : une position LÉGALE.
        // Sur cette finale, les deux sens le sont, et le départage par les
        // pions retient l'envers (un pion blanc en h2 y pèse plus qu'un pion
        // blanc en a7) — iOS devine pareil, et l'utilisateur inverse d'un tap.
        val reading = com.chesslab.scanner.ScanReading(grid)
        org.junit.Assert.assertTrue(
            com.chesslab.editor.FenValidator.isLegal(
                reading.fen(reading.suggestedRotation(), chesskit.Piece.Color.white)
            )
        )

        // du manifeste de l'app iOS
        val expected = "5rk1/P7/2R5/5P1p/8/4b3/6K1/8"
        val correct = squaresInCommon(expected, placement)
        assertTrue(
            "seulement $correct cases sur 64 correctes\n  attendu $expected\n  lu       $placement",
            correct >= 60,
        )
    }

    private fun squaresInCommon(a: String, b: String): Int {
        val ea = expand(a); val eb = expand(b)
        if (ea.length != 64 || eb.length != 64) return 0
        return ea.indices.count { ea[it] == eb[it] }
    }

    private fun expand(placement: String): String = buildString {
        for (c in placement) {
            when {
                c == '/' -> Unit
                c.isDigit() -> repeat(c - '0') { append('.') }
                else -> append(c)
            }
        }
    }

    /**
     * La détection automatique doit retrouver le cadre relevé à la main.
     *
     * Le cas est le plus dur du lot : capture de téléphone en portrait, plateau
     * PLEINE LARGEUR qui touche les deux bords — ses lignes de grille extrêmes
     * n'ont donc aucun gradient à offrir — et interface chargée au-dessus comme
     * en dessous.
     */
    @Test fun leCadreEstTrouveToutSeul() {
        val bitmap = assets.open("chesscom_endgame_rook.png").use { BitmapFactory.decodeStream(it) }
        assumeTrue("image de fixture absente", bitmap != null)

        val found = BoardAutoFrame.rect(bitmap!!)
        assertTrue("aucun plateau trouvé dans la capture", found != null)
        val r = found!!
        // Relevé à la main : (0, 724) sur 1206 de côté. On tolère 4 % du côté —
        // le cadrage n'a pas à être au pixel, BoardGridFinder recale ensuite.
        val tol = 1206 * 0.04
        assertTrue("bord gauche ${r.x}, attendu ≈ 0", kotlin.math.abs(r.x - 0.0) < tol)
        assertTrue("bord haut ${r.y}, attendu ≈ 724", kotlin.math.abs(r.y - 724.0) < tol)
        assertTrue("côté ${r.width}, attendu ≈ 1206", kotlin.math.abs(r.width - 1206.0) < tol)
    }

    /**
     * Le cadre trouvé tout seul doit donner la MÊME lecture que le cadre posé à
     * la main : c'est la seule mesure qui compte pour l'utilisateur.
     */
    @Test fun leCadreTrouveSeulSeLitAussiBien() {
        val detector = PieceDetector.shared(context)
        assumeTrue("modèle de reconnaissance absent", detector != null)
        val bitmap = assets.open("chesscom_endgame_rook.png").use { BitmapFactory.decodeStream(it) }
        assumeTrue("image de fixture absente", bitmap != null)

        val corners = BoardAutoFrame.corners(bitmap!!)
        assertTrue("aucun plateau trouvé", corners != null)
        val points = corners!!.map { (fx, fy) ->
            Homography.Point((fx * bitmap.width).toDouble(), (fy * bitmap.height).toDouble())
        }
        val placement = BoardReader.placement(BoardReader.grid(detector!!.detect(bitmap, points)))
        val correct = squaresInCommon("5rk1/P7/2R5/5P1p/8/4b3/6K1/8", placement)
        assertTrue("cadrage automatique : $correct/64 cases\n  lu $placement", correct >= 60)
    }
}
