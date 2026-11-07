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
import org.json.JSONArray
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La revue des cases douteuses, sur l'appareil. Pendant des tests UI de
 * `ScanConfirmationView` (iOS).
 *
 * La photo simulée `celtic_black` donne au moins une case douteuse (un pion lu
 * à tort en h6, signalé) : la revue doit la présenter, laisser la passer en
 * revue case par case, puis dire que tout est vérifié.
 */
@RunWith(AndroidJUnit4::class)
class ScannerReviewTest {

    @get:Rule val compose = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    private fun count(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().size

    @Test fun uneCaseDouteuseSePasseEnRevueAvantLAnalyse() {
        assumeTrue("modèle de reconnaissance absent", PieceDetector.shared(context) != null)
        val file = "lichess_ui_photo_celtic_black.jpg"
        val bitmap = assets.open(file).use { BitmapFactory.decodeStream(it) }
        assumeTrue("image de fixture absente", bitmap != null)

        // Les coins du manifeste, en fractions de l'image.
        val manifest = JSONArray(assets.open("manifest.json").bufferedReader().use { it.readText() })
        val entry = (0 until manifest.length()).map { manifest.getJSONObject(it) }.first { it.getString("file") == file }
        val corners = entry.getJSONArray("corners")

        lateinit var model: ScannerViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model = ScannerViewModel(context.applicationContext as Application)
        }
        compose.setContent { ScannerScreen(model = model, onAnalyse = {}) }

        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(bitmap!!, autoRead = false) }
        compose.waitUntil(30_000) { model.ui.stage == ScanStage.adjustCrop }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            for (i in 0 until 4) {
                model.moveCorner(
                    i,
                    (corners.getJSONArray(i).getDouble(0) / bitmap!!.width).toFloat(),
                    (corners.getJSONArray(i).getDouble(1) / bitmap.height).toFloat(),
                )
            }
            model.scan()
        }
        compose.waitUntil(60_000) { model.ui.stage == ScanStage.confirm }
        compose.waitUntil(10_000) { count("revue-cases") + count("banniere-sure") > 0 }

        // Au moins une case douteuse : la revue est là, avec la bannière d'incertitude.
        assertTrue("la photo simulée doit laisser une case douteuse", count("revue-cases") == 1)
        compose.onNodeWithTag("revue-cases").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("revue-garder").assertIsDisplayed()
        assertTrue(model.ui.reviewSquares.isNotEmpty())
        assertTrue("la vignette d'origine doit exister", model.ui.thumbnail(model.ui.reviewSquares.first()) != null)

        // On passe en revue case par case : « c'est bien ça » fait avancer, jusqu'à la fin.
        var guard = 0
        while (count("revue-cases") > 0 && guard++ < 20) {
            compose.onNodeWithTag("revue-garder").performScrollTo().performClick()
            compose.waitForIdle()
        }
        assertTrue("toutes les cases douteuses doivent être passées en revue", count("revue-cases") == 0)
        compose.waitUntil(5_000) { count("banniere-verifiee") == 1 }
    }
}
