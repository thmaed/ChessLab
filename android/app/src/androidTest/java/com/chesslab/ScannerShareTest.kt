package com.chesslab

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.scanner.ScannerScreen
import com.chesslab.scanner.ScannerViewModel
import com.chesslab.scanner.SharedImage
import com.chesslab.vision.PieceDetector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * « Partager › ChessLab » depuis une autre app. Pendant de `ScanShareTests`
 * (iOS, extension de partage) : l'image reçue ouvre le scanner à l'étape du
 * cadrage, sans repasser par le sélecteur.
 */
@RunWith(AndroidJUnit4::class)
class ScannerShareTest {

    @get:Rule val compose = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    private fun send(type: String?, stream: Uri?, action: String = Intent.ACTION_SEND) =
        Intent(action).apply {
            this.type = type
            stream?.let { putExtra(Intent.EXTRA_STREAM, it) }
        }

    @Test fun uneImagePartageeSeLit() {
        val uri = Uri.parse("content://media/external/images/media/42")
        assertEquals(uri, SharedImage.from(send("image/png", uri)))
        assertEquals(uri, SharedImage.from(send("image/jpeg", uri)))
    }

    @Test fun toutLeResteSeRefuse() {
        val uri = Uri.parse("content://media/external/images/media/42")
        assertNull("un lancement ordinaire", SharedImage.from(Intent(Intent.ACTION_MAIN)))
        assertNull("aucun intent", SharedImage.from(null))
        assertNull("du texte partagé", SharedImage.from(send("text/plain", uri)))
        assertNull("un type absent", SharedImage.from(send(null, uri)))
        assertNull("une image annoncée sans flux", SharedImage.from(send("image/png", null)))
        assertNull("un lot : une seule image à la fois", SharedImage.from(send("image/png", uri, Intent.ACTION_SEND_MULTIPLE)))
    }

    @Test fun uneImagePartageeOuvreLeCadrageEtNeSeRelitPas() {
        assumeTrue("modèle de reconnaissance absent", PieceDetector.shared(context) != null)
        // L'image des fixtures, déposée dans le cache comme le ferait l'app d'origine.
        val file = File(context.cacheDir, "partage.jpg")
        assets.open("lichess_ui_photo_celtic_black.jpg").use { input -> file.outputStream().use { input.copyTo(it) } }
        val uri = Uri.fromFile(file)

        lateinit var model: ScannerViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model = ScannerViewModel(context.applicationContext as Application)
        }
        compose.setContent { ScannerScreen(model = model, sharedImage = uri, onAnalyse = {}) }

        // Selon l'image, la lecture s'enchaîne (capture) ou s'arrête au cadrage (photo) :
        // dans les deux cas l'image reçue est chargée, sans repasser par le sélecteur.
        compose.waitUntil(60_000) { model.ui.image != null && !model.ui.busy }
        val loaded = model.ui.image
        assertNotNull("l'image reçue est affichée", loaded)

        // Revenir sur l'écran ne doit pas relire l'image : la détection, relancée,
        // écraserait le cadrage de l'utilisateur. Une relecture produirait un NOUVEAU bitmap.
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model.loadShared(uri) }
        Thread.sleep(3_000)
        compose.waitForIdle()
        assertTrue("la même image, pas relue", model.ui.image === loaded)
    }
}
