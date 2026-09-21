package com.chesslab

import android.app.Application
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Piece
import chesskit.Square
import com.chesslab.variants.DuckChessViewModel
import com.chesslab.variants.DuckPhase
import com.chesslab.variants.VariantSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Les deux choses que le Duck Chess disait de travers, prouvées par une partie
 * jouée par où les doigts passent.
 *
 * La variante n'a ni échec ni mat — sa propre notation l'écrit, en marquant
 * « ++ » et jamais « # ». L'issue, elle, empruntait la phrase du jeu
 * classique. Et le réglage « Deux joueurs », proposé par l'écran d'avant,
 * n'arrivait pas jusqu'au modèle : la machine jouait quand même.
 *
 * Instrumenté et pas JVM : le modèle de vue est un `AndroidViewModel`, il lui
 * faut une vraie `Application` pour ses textes.
 */
class DuckChessOutcomeTest {

    private val app = InstrumentationRegistry.getInstrumentation()
        .targetContext.applicationContext as Application

    /** Un tour entier : déplacer une pièce, PUIS poser le canard. */
    private suspend fun tour(model: DuckChessViewModel, de: String, a: String, canard: String) {
        withContext(Dispatchers.Main) {
            model.onSquareTap(Square(de))
            model.onSquareTap(Square(a))
            model.onSquareTap(Square(canard))
        }
    }

    private suspend fun partieADeux(): DuckChessViewModel {
        val model = withContext(Dispatchers.Main) { DuckChessViewModel(app) }
        withContext(Dispatchers.Main) {
            model.apply(VariantSettings(twoPlayers = true, blunderAlertEnabled = false))
        }
        return model
    }

    /**
     * 1.e4 f6 2.Dh5 a6 3.Dxe8++ — après 1...f6, la diagonale h5-e8 est
     * ouverte, et personne n'est obligé de voir venir la dame : c'est la
     * variante, pas une faute.
     */
    private suspend fun jusquALaPriseDuRoi(model: DuckChessViewModel) {
        tour(model, "e2", "e4", "h3")
        tour(model, "f7", "f6", "h6")
        tour(model, "d1", "h5", "a3")
        tour(model, "a7", "a6", "a4")
        withContext(Dispatchers.Main) {
            model.onSquareTap(Square("h5"))
            model.onSquareTap(Square("e8"))
        }
    }

    @Test
    fun laPriseDuRoiNeSAppellePasEchecEtMat() = runBlocking {
        val model = partieADeux()
        jusquALaPriseDuRoi(model)

        val attendu = app.getString(
            R.string.variant_side_won,
            app.getString(R.string.color_white),
            app.getString(R.string.reason_king_captured),
        )
        assertEquals(
            "coups joués : ${model.analysisSans()}",
            attendu, model.ui.outcome,
        )
        assertEquals(Piece.Color.white, model.ui.winner)
        assertEquals("Qxe8++", model.analysisSans().last())
        // La partie s'arrête AVANT la pose du canard : il n'aurait plus d'objet.
        assertEquals(DuckPhase.over, model.ui.phase)
    }

    @Test
    fun aDeuxLaMachineNeJouePas() = runBlocking {
        val model = partieADeux()
        tour(model, "e2", "e4", "h3")

        // Un coup de moteur prend de 300 à 900 ms : deux secondes suffisent
        // largement à le voir passer s'il se croit encore invité.
        delay(2_000)

        assertEquals(
            "la machine a joué : ${model.analysisSans()}",
            1, model.analysisSans().size,
        )
        assertEquals(Piece.Color.black, model.ui.position.sideToMove)
        assertFalse("le témoin de réflexion ne doit jamais s'allumer", model.ui.thinking)

        // Et les Noirs jouent, par les mêmes doigts.
        tour(model, "e7", "e5", "a3")
        assertEquals(2, model.analysisSans().size)
        assertEquals(Piece.Color.white, model.ui.position.sideToMove)
    }
}
