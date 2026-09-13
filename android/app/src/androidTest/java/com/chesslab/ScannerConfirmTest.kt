package com.chesslab

import android.app.Application
import android.graphics.BitmapFactory
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.scanner.ScanStage
import com.chesslab.scanner.ScannerScreen
import com.chesslab.scanner.ScannerViewModel
import com.chesslab.vision.PieceDetector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La confirmation du scanner, sur l'appareil, avec la capture de référence.
 *
 * Le contrat : rien de ce qui sort du scanner n'a échappé au regard de
 * l'utilisateur. Une lecture s'ouvre donc dans l'ÉDITEUR, pré-rempli, avec
 * ses cases douteuses surlignées et son sens de lecture réversible — et c'est
 * de là, seulement, que la position part vers l'analyse.
 */
@RunWith(AndroidJUnit4::class)
class ScannerConfirmTest {

    @get:Rule val compose = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    private fun awaitTag(tag: String, timeoutMs: Long = 60_000) =
        compose.waitUntil(timeoutMs) { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }

    @Test fun uneLectureSeConfirmeDansLEditeurAvantDePartir() {
        assumeTrue("modèle de reconnaissance absent", PieceDetector.shared(context) != null)
        val bitmap = assets.open("chesscom_endgame_rook.png").use { BitmapFactory.decodeStream(it) }
        assumeTrue("image de fixture absente", bitmap != null)

        var analysed: String? = null
        lateinit var model: ScannerViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model = ScannerViewModel(context.applicationContext as Application)
        }
        compose.setContent { ScannerScreen(model = model, onAnalyse = { analysed = it }) }

        // La capture, cadrée comme dans le test du pipeline : le plateau va de
        // bord à bord, de y = 724 à y = 1930 sur une image de 1206 × H.
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(bitmap!!) }
        compose.waitUntil(30_000) { model.ui.stage == ScanStage.adjustCrop }
        val h = bitmap!!.height.toFloat()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model.moveCorner(0, 0f, 724f / h); model.moveCorner(1, 1f, 724f / h)
            model.moveCorner(2, 1f, 1930f / h); model.moveCorner(3, 0f, 1930f / h)
            model.scan()
        }

        // La lecture s'ouvre dans l'éditeur : bannière de confiance, plateau
        // éditable, et pas d'envoi direct au moteur.
        compose.waitUntil(60_000) { model.ui.stage == ScanStage.confirm }
        compose.waitUntil(10_000) {
            compose.onAllNodesWithTag("banniere-sure").fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithTag("banniere-incertaine").fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithTag("case-g1").assertIsDisplayed()
        assertEquals(null, analysed)

        // Le sens de lecture : l'orientation devinée n'est qu'une proposition
        // (ici les deux sens sont légaux, et la règle des pions retient
        // l'envers — comme iOS). Si le plateau est à l'envers, on l'inverse
        // d'un tap, comme l'utilisateur.
        val expected = "5rk1/P7/2R5/5P1p/8/4b3/6K1/8"
        val shown = model.ui.fen!!.split(" ").first()
        if (common(expected, shown) < 60) {
            compose.onNodeWithTag("inverser-lecture").performScrollTo().performClick()
            compose.waitUntil(5_000) { model.ui.fen!!.split(" ").first() != shown }
        }

        // Partir vers l'analyse, c'est partir de l'ÉDITEUR — avec la position
        // qu'il montre, roques déduits, jamais inventés.
        compose.onNodeWithTag("analyser").performScrollTo().performClick()
        compose.waitUntil(5_000) { analysed != null }
        val placement = analysed!!.split(" ").first()
        assertTrue("position confirmée trop éloignée de la vérité :\n  $placement", common(expected, placement) >= 60)
        assertTrue("aucun roi sur sa case : pas de roque", analysed!!.contains(" w - "))
    }

    private fun common(a: String, b: String): Int {
        fun expand(p: String) = buildString { for (c in p) { if (c == '/') continue; if (c.isDigit()) repeat(c - '0') { append('.') } else append(c) } }
        val ea = expand(a); val eb = expand(b)
        return if (ea.length == 64 && eb.length == 64) ea.indices.count { ea[it] == eb[it] } else 0
    }
}
