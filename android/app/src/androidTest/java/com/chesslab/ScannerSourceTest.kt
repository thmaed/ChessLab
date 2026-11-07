package com.chesslab

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.scanner.ScanSource
import com.chesslab.scanner.ScanStage
import com.chesslab.scanner.ScannerViewModel
import com.chesslab.vision.PieceDetector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La déduction capture / photo d'écran, sur l'appareil. Pendant du chemin
 * `detectSourceAndBoard` de `ScannerViewModel` (iOS) : un damier reconnu avec
 * certitude est une capture, et la lecture s'enchaîne sans demander de recadrer ;
 * sinon c'est une photo d'écran, et l'on s'arrête au cadrage.
 */
@RunWith(AndroidJUnit4::class)
class ScannerSourceTest {

    @get:Rule val compose = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    private fun newModel(): ScannerViewModel {
        lateinit var model: ScannerViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model = ScannerViewModel(context.applicationContext as Application)
        }
        return model
    }

    private fun capture() = assets.open("lichess_ui_mpchess_white.png").use { BitmapFactory.decodeStream(it) }

    @Test fun uneCaptureNetteSeLitSansDemanderDeRecadrer() {
        assumeTrue("modèle de reconnaissance absent", PieceDetector.shared(context) != null)
        val model = newModel()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(capture()) }

        compose.waitUntil(60_000) { model.ui.stage == ScanStage.confirm }
        assertEquals(ScanSource.screenshot, model.ui.source)
        assertNotNull(model.ui.reading)
        assertNotNull("de quoi revenir au cadrage", model.ui.image)
    }

    @Test fun sansLectureAutomatiqueOnS_arreteAuCadrageMaisLaSourceEstDeduite() {
        val model = newModel()
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(capture(), autoRead = false) }

        compose.waitUntil(30_000) { model.ui.stage == ScanStage.adjustCrop }
        assertEquals(ScanSource.screenshot, model.ui.source)
    }

    /** Une image sans motif de damier (un aplat) : rien de certain, donc une photo, et le cadrage manuel. */
    @Test fun uneImageSansDamierSeDeduitPhotoEtOuvreLeCadrage() {
        val model = newModel()
        val flat = Bitmap.createBitmap(640, 640, Bitmap.Config.ARGB_8888).also { it.eraseColor(Color.GRAY) }
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(flat) }

        compose.waitUntil(30_000) { model.ui.stage == ScanStage.adjustCrop }
        assertEquals(ScanSource.screenPhoto, model.ui.source)
        assertEquals("cadre par défaut", com.chesslab.scanner.ScannerUiState.defaultCorners, model.ui.corners)
    }

    @Test fun uneSourceImposeeNeSeDeduitPas() {
        val model = newModel()
        model.forcedSource = ScanSource.screenPhoto
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadBitmap(capture(), autoRead = false) }

        compose.waitUntil(30_000) { model.ui.stage == ScanStage.adjustCrop }
        assertEquals(ScanSource.screenPhoto, model.ui.source)
    }
}
