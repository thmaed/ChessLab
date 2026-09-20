package com.chesslab

import android.app.Application
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Square
import com.chesslab.variants.VariantPlayViewModel
import com.chesslab.variants.VariantSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * La PHRASE de fin de partie, produite par une partie réellement jouée.
 *
 * `VariantEndingsTest` prouve que le verdict est juste : il interroge le
 * moteur sur une position terminale. Il ne prouve pas que la phrase ARRIVE —
 * entre le verdict et l'écran il y a le modèle de vue et sa mise en mots, et
 * c'est là qu'Android se taisait : « Partie terminée », sans vainqueur.
 *
 * On joue donc une partie entière, coup par coup, par où les doigts passent
 * (`onSquareTap`), avec le vrai moteur comme arbitre — et on lit la phrase.
 *
 * Roi de la colline, à deux sur l'appareil : c'est la fin la plus courte
 * qu'on puisse forcer, et personne n'y joue contre nous.
 */
class VariantVictoryTest {

    private val app = InstrumentationRegistry.getInstrumentation()
        .targetContext.applicationContext as Application

    /** Attend, et DIT ce qu'on voyait quand ça n'arrive pas. */
    private suspend fun attendre(quoi: String, model: VariantPlayViewModel, condition: () -> Boolean) {
        try {
            withTimeout(60_000) { while (!condition()) delay(100) }
        } catch (e: Exception) {
            val u = model.ui
            throw AssertionError(
                "attente de « $quoi » : prêt=${u.ready} fini=${u.gameOver} " +
                    "trait=${u.position.sideToMove} coups=${u.sanMoves} " +
                    "sélection=${u.selected} cibles=${u.legalTargets.size} état=${u.status}"
            )
        }
    }

    @Test
    fun leRoiSurLaCollineGagneEtLeDit() = runBlocking {
        val model = withContext(Dispatchers.Main) { VariantPlayViewModel(app) }
        withContext(Dispatchers.Main) {
            model.load(
                "kingofthehill", chess960Number = null, twoPlayer = true,
                settings = VariantSettings(twoPlayers = true, blunderAlertEnabled = false),
            )
        }
        attendre("plateau prêt", model) { model.ui.ready }

        // Le roi blanc marche jusqu'à e4 pendant que les cavaliers noirs
        // s'écartent de son chemin. Le pion e libère la case au deuxième coup.
        val partie = listOf(
            "e2" to "e4", "g8" to "f6",
            "e4" to "e5", "f6" to "d5",
            "e1" to "e2", "d5" to "b6",
            "e2" to "e3", "b8" to "c6",
            "e3" to "e4",
        )
        for ((depuis, vers) in partie) {
            val avant = model.ui.uciLog.size
            withContext(Dispatchers.Main) {
                model.onSquareTap(Square(depuis))
                model.onSquareTap(Square(vers))
            }
            attendre("$depuis-$vers joué", model) { model.ui.uciLog.size > avant || model.ui.gameOver }
            // `ready` ne retombe PAS pendant un rafraîchissement : il reste vrai
            // depuis la position d'avant. C'est `thinking` qui dit que le moteur
            // est encore en train de rendre les coups légaux — sans l'attendre,
            // le coup suivant tombe sur la liste de la position précédente et
            // ne sélectionne rien.
            attendre("$depuis-$vers rendu", model) { !model.ui.thinking || model.ui.gameOver }
        }

        assertEquals(
            "la partie devrait être finie (coups : ${model.ui.sanMoves})",
            true, model.ui.gameOver,
        )
        assertEquals("Blancs a gagné (roi au centre)", model.ui.outcome)
    }
}
