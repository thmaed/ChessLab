package com.chesslab

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.chesslab.variants.VariantAnalysisViewModel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Revoir une partie de VARIANTE, aux règles de la variante.
 *
 * L'analyse ordinaire jugerait une position de Roi de la colline aux règles
 * orthodoxes — son chiffre serait faux, ce qui est pire que pas de chiffre.
 * Le test demande FAIRY-STOCKFISH, donc un appareil ; il vérifie que la
 * partie se rejoue au moteur de variante, qu'une évaluation en sort, et que
 * la passe pose ses pastilles.
 */
@RunWith(AndroidJUnit4::class)
class VariantAnalysisTest {

    private val app: Application = ApplicationProvider.getApplicationContext()

    /** Attend qu'une condition se réalise, en laissant tourner le moteur. */
    private fun await(timeoutMs: Long = 120_000, condition: () -> Boolean) = runBlocking {
        withTimeout(timeoutMs) {
            while (!condition()) kotlinx.coroutines.delay(200)
        }
    }

    @Test fun lePartieDeVarianteSeRejoueAuMoteurDeLaVariante() {
        val model = VariantAnalysisViewModel(app)
        // 1. e4 e5 2. Nf3 — trois demi-coups, assez pour une passe courte.
        model.load("kingofthehill", null, listOf("e2e4", "e7e5", "g1f3"))

        await { model.ui.sanMoves.size == 3 }
        require(!model.ui.engineUnavailable) { "le moteur de variante n'a pas répondu" }

        // La passe de classification tourne et s'achève.
        await { !model.ui.classifying && model.ui.qualities.isNotEmpty() }
        require(model.ui.qualities.size >= 2) {
            "attendu au moins deux coups classés, obtenu ${model.ui.qualities.size}"
        }

        // Et la position affichée porte une évaluation, POV Blancs.
        await { model.ui.evalCp != null || model.ui.evalMate != null }
    }

    /**
     * La courbe et la précision se COMPLÈTENT au fil de la passe, comme sur
     * iOS où ce sont des propriétés calculées lues au cache — au lieu
     * d'apparaître d'un coup à la fin. On guette un instant où la passe
     * tourne et où la courbe est déjà là, mais pas encore entière.
     */
    @Test fun laRevueSeCompleteAuFilDeLaPasse() {
        val model = VariantAnalysisViewModel(app)
        val moves = listOf("e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6", "d2d3", "f8c5")
        model.load("kingofthehill", null, moves)
        await { model.ui.sanMoves.size == moves.size }
        require(!model.ui.engineUnavailable) { "le moteur de variante n'a pas répondu" }

        // La passe démarre d'elle-même au chargement ; on attend qu'elle tourne,
        // puis on relève la taille de la courbe tant qu'elle tourne.
        await { model.ui.classifying }
        val seenWhileRunning = mutableSetOf<Int>()
        await(240_000) {
            val ui = model.ui
            if (ui.classifying) seenWhileRunning += ui.curve.size
            !ui.classifying
        }
        val final = model.ui.curve.size
        require(final > 1) { "la passe n'a laissé aucune courbe" }
        require(seenWhileRunning.any { it in 1 until final }) {
            "la courbe n'est apparue qu'à la fin de la passe, d'un seul coup (vu : $seenWhileRunning, fin : $final)"
        }
        require(model.ui.accuracyWhite != null && model.ui.accuracyBlack != null) {
            "la précision de chaque camp doit être là à la fin"
        }
    }

    /** Naviguer dans la partie change la position ET son évaluation. */
    @Test fun laNavigationRejoueChaquePosition() {
        val model = VariantAnalysisViewModel(app)
        model.load("kingofthehill", null, listOf("e2e4", "e7e5"))
        await { model.ui.sanMoves.size == 2 }

        model.toStart()
        await { model.ui.displayedPly == 0 }
        val start = model.ui.position.fen
        model.next()
        await { model.ui.displayedPly == 1 }
        require(model.ui.position.fen != start) { "la position n'a pas changé" }
    }
}
