package com.chesslab

import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
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
 * Les coins du plateau sont DONNÉS : la détection automatique du cadre (celle
 * que fait `VNDetectRectanglesRequest` côté iOS) n'est pas portée, et le
 * scanner Android demande pour l'instant à l'utilisateur de poser lui-même ses
 * quatre poignées. Ce test vérifie tout le reste : redressement, modèle, NMS,
 * projection sur la grille, assemblage de la FEN.
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
        val placement = BoardReader.placement(BoardReader.grid(detections))

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
}
