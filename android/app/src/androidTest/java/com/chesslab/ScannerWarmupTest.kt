package com.chesslab

import android.app.Application
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.scanner.ScannerViewModel
import com.chesslab.scanner.TemplateSquareClassifier
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Ouvrir le scanner prépare les gabarits en arrière-plan : la première lecture n'attend plus après eux. */
@RunWith(AndroidJUnit4::class)
class ScannerWarmupTest {

    @Test fun openingTheScannerBuildsTheTemplatesInTheBackground() {
        val app = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as Application
        InstrumentationRegistry.getInstrumentation().runOnMainSync { ScannerViewModel(app) }
        val start = System.currentTimeMillis()
        while (!TemplateSquareClassifier.isReady && System.currentTimeMillis() - start < 30_000) Thread.sleep(50)
        assertTrue("les gabarits doivent être prêts sans qu'on ait lancé de lecture", TemplateSquareClassifier.isReady)
    }
}
