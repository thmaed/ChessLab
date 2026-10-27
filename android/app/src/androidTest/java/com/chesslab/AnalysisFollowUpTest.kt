package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.analysis.AnalysisFollowUpService
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Les suites d'une analyse (A2, A3) ne se jouent qu'une fois par partie. Pendant de `AnalysisFollowUpServiceTests` (iOS). */
@RunWith(AndroidJUnit4::class)
class AnalysisFollowUpTest {

    @Test fun uneParties_neSeTraiteQuUneFois_etLaMemoireResteBornee() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        context.getSharedPreferences("auto_analysis", android.content.Context.MODE_PRIVATE).edit().remove("followUpDone").apply()
        assertFalse(AnalysisFollowUpService.hasProcessed(context, "k1"))
        AnalysisFollowUpService.markProcessed(context, "k1")
        AnalysisFollowUpService.markProcessed(context, "k1")
        assertTrue(AnalysisFollowUpService.hasProcessed(context, "k1"))
        assertFalse(AnalysisFollowUpService.hasProcessed(context, "k2"))
        for (i in 0 until 400) AnalysisFollowUpService.markProcessed(context, "g$i")
        assertTrue(AnalysisFollowUpService.hasProcessed(context, "g399"))
        assertFalse(AnalysisFollowUpService.hasProcessed(context, "g0"))
    }
}
