package com.chesslab

import android.app.Application
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Square
import com.chesslab.library.Autosave
import com.chesslab.play.BlindfoldLevel
import com.chesslab.play.PlayGameSettings
import com.chesslab.play.PlayViewModel
import com.chesslab.play.VoiceMoves.Decision
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * COUPS À LA VOIX dans une vraie partie (19/11/2026) : ce que le modèle de partie fait de ce que le micro a entendu,
 * sans micro. Pendant de `VoiceMovesGameTests` (iOS) ; la décision elle-même est couverte sur la JVM
 * (`VoiceMovesTest`), la lecture des phrases par `VoiceMoveParserTest` (dont les 51 essais réels de l'iPhone).
 */
@RunWith(AndroidJUnit4::class)
class VoiceMovesGameTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val app = instrumentation.targetContext.applicationContext as Application

    private fun game(settings: PlayGameSettings): PlayViewModel {
        lateinit var model: PlayViewModel
        instrumentation.runOnMainSync {
            model = PlayViewModel(app)
            model.start(settings)
        }
        return model
    }

    private fun <T> main(block: () -> T): T {
        var result: T? = null
        instrumentation.runOnMainSync { result = block() }
        @Suppress("UNCHECKED_CAST")
        return result as T
    }

    /** Pas de partie laissée en cours pour les tests suivants (« Commencer » demanderait de la remplacer). */
    @After fun noGameLeft() = runBlocking {
        Thread.sleep(300)
        LibraryDatabase.get(app).autosaves().clear("engine")
    }

    private val voice = PlayGameSettings(voiceMoves = true, hintsEnabled = false, blunderAlertEnabled = false)

    @Test fun leCoupComprisEstJoueToutDeSuite() {
        val model = game(voice)
        assertTrue(main { model.ui.isVoiceTurn })
        val decision = main { model.handleVoice(listOf("Cavalier F3"), "fr", speaks = false) }
        assertEquals("Nf3", (decision as Decision.Play).move.san)
        assertEquals("Nf3", main { model.ui.sanMoves.last() })
        assertEquals(false, main { model.ui.voiceNotice?.isError })
        assertFalse("après mon coup, c'est à l'ordinateur : le micro n'écoute plus", main { model.ui.isVoiceTurn })
    }

    @Test fun lePlateauJoueAussiVoixAllumee() {
        val model = game(voice)
        main { model.onSquareTap(Square("e2")); model.onSquareTap(Square("e4")) }
        assertEquals("e4", main { model.ui.sanMoves.last() })
        assertEquals("une phrase en retard ne joue pas un second coup", Decision.Ignored,
            main { model.handleVoice(listOf("cavalier f6"), "fr", speaks = false) })
    }

    @Test fun microCoupePlusDEcouteMaisLePlateauJoue() {
        val model = game(voice)
        main { model.setVoiceMic(false) }
        assertFalse(main { model.ui.voiceMicOn })
        assertFalse(main { model.ui.isVoiceTurn })
        assertEquals(Decision.Ignored, main { model.handleVoice(listOf("e4"), "fr", speaks = false) })
        assertTrue(main { model.ui.sanMoves.isEmpty() })
        main { model.onSquareTap(Square("d2")); model.onSquareTap(Square("d4")) }
        assertEquals("d4", main { model.ui.sanMoves.last() })
    }

    @Test fun unCoupImpossibleSeDitEtNeSeJouePas() {
        val model = game(voice)
        assertEquals(Decision.Illegal, main { model.handleVoice(listOf("fou c4"), "fr", speaks = false) })
        assertTrue(main { model.ui.sanMoves.isEmpty() })
        assertEquals(true, main { model.ui.voiceNotice?.isError })
        assertEquals(main { app.getString(R.string.blind_illegal) }, main { model.ui.lastSpokenVoiceText })
    }

    @Test fun annuleReprendLeCoup() {
        val model = game(voice)
        main { model.handleVoice(listOf("e4"), "fr", speaks = false) }
        // L'ordinateur répond : on attend qu'il ait fini (au plus 30 s), puis « annule » reprend les deux coups.
        val deadline = System.currentTimeMillis() + 30_000
        while (System.currentTimeMillis() < deadline && !main { model.ui.isVoiceTurn }) Thread.sleep(100)
        assertTrue("c'est de nouveau à moi", main { model.ui.isVoiceTurn })
        assertEquals(Decision.Undo, main { model.handleVoice(listOf("annule"), "fr", speaks = false) })
        assertTrue(main { model.ui.sanMoves.isEmpty() })
    }

    @Test fun aLAveugleVoixAllumeeLeCoupEstRepete() {
        val model = game(voice.copy(blindfold = BlindfoldLevel.allHidden, blindfoldVoice = true))
        main { model.handleVoice(listOf("cavalier f3"), "fr", speaks = false) }
        assertEquals(main { com.chesslab.ui.MoveNarration.describe(app, "Nf3") }, main { model.ui.lastSpokenVoiceText })
        main { com.chesslab.play.BlindfoldVoice.stop() }
    }

    @Test fun sansLaVoixDeLAveugleLeCoupEstSeulementAffiche() {
        val model = game(voice)
        main { model.handleVoice(listOf("cavalier f3"), "fr", speaks = false) }
        assertEquals(null, main { model.ui.lastSpokenVoiceText })
        assertEquals(main { com.chesslab.ui.MoveNarration.describe(app, "Nf3") }, main { model.ui.voiceNotice?.text })
    }

    @Test fun lInterrupteurMicroVoyageAvecLaPartie() {
        val saved = Autosave(
            mode = "engine", savedAt = 0, moves = "e2e4 e7e5", label = "test", userColor = "white",
            settingsJson = org.json.JSONObject().put("voiceMoves", true).put("voiceMicOff", true).toString(),
        )
        lateinit var model: PlayViewModel
        instrumentation.runOnMainSync { model = PlayViewModel(app); model.resume(saved) }
        assertTrue(main { model.ui.settings.voiceMoves })
        assertFalse("on retrouve le micro coupé en revenant à la partie", main { model.ui.voiceMicOn })

        val before = saved.copy(settingsJson = null)
        instrumentation.runOnMainSync { model = PlayViewModel(app); model.resume(before) }
        assertTrue("sauvegarde sans l'interrupteur : micro allumé", main { model.ui.voiceMicOn })
    }
}
