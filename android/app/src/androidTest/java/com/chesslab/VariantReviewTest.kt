package com.chesslab

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Square
import com.chesslab.variants.VariantPlayScreen
import com.chesslab.variants.VariantPlayViewModel
import com.chesslab.variants.VariantSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test

/**
 * La consultation dans une variante contre l'ordinateur — que l'écran
 * Android n'avait pas du tout (PARITE.md, 24/10/2026) : remonter la partie
 * PAR COUP COMPLET, en repartir avec « Reprendre ici », et se raviser.
 * Roi de la colline : une variante ordinaire, arbitrée par Fairy-Stockfish.
 */
class VariantReviewTest {

    @get:Rule val compose = createComposeRule()

    private val app = InstrumentationRegistry.getInstrumentation()
        .targetContext.applicationContext as Application

    private fun play(model: VariantPlayViewModel, from: String, to: String, pliesAfterReply: Int) {
        compose.waitUntil(60_000) { model.ui.ready && !model.ui.thinking }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            model.onSquareTap(Square(from))
            model.onSquareTap(Square(to))
        }
        // Notre coup, puis la réponse du moteur.
        compose.waitUntil(60_000) { model.ui.plies == pliesAfterReply && !model.ui.thinking }
    }

    @Test fun laConsultationAvanceParCoupCompletEtLaRepriseSAnnule() {
        lateinit var model: VariantPlayViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = VariantPlayViewModel(app) }
        val settings = VariantSettings(blunderAlertEnabled = false, showEvalBar = false)
        compose.setContent { VariantPlayScreen(variantId = "kingofthehill", settings = settings, model = model) }

        play(model, "e2", "e4", pliesAfterReply = 2)
        play(model, "d2", "d4", pliesAfterReply = 4)

        // UN recul = un coup COMPLET : la position d'avant 2. d4, à nous de jouer.
        compose.onNodeWithTag("precedent").performClick()
        compose.waitUntil(5_000) { model.ui.review != null }
        assertEquals(2, model.ui.review?.ply)

        // Et l'on en repart : la suite est écartée, c'est à nous.
        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 2 && !model.ui.thinking }
        assertNull(model.ui.review)
        assertEquals(2, model.ui.sanMoves.size)
        assertEquals(model.ui.userColor, model.ui.position.sideToMove)

        // Se raviser : les deux demi-coups écartés reviennent.
        compose.waitUntil(5_000) { compose.onAllNodesWithTag("annuler-reprise").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 4 && !model.ui.thinking }
        assertEquals(4, model.ui.sanMoves.size)

        // Deux reculs depuis le direct : le départ.
        compose.onNodeWithTag("precedent").performClick()
        compose.onNodeWithTag("precedent").performClick()
        compose.waitUntil(5_000) { model.ui.review?.ply == 0 }
        // Et « suivant » ramène jusqu'au direct, coup complet par coup complet.
        compose.onNodeWithTag("suivant").performClick()
        compose.waitUntil(5_000) { model.ui.review?.ply == 2 }
        compose.onNodeWithTag("suivant").performClick()
        compose.waitUntil(5_000) { model.ui.review == null }
    }

    /** Joue le premier coup légal trouvé — aux murs tirés au sort, on ne choisit pas. */
    private fun playAnyMove(model: VariantPlayViewModel, pliesAfterReply: Int) {
        compose.waitUntil(60_000) { model.ui.ready && !model.ui.thinking }
        val mine = model.ui.position.pieces.filter { it.color == model.ui.userColor }.map { it.square }
        var played = false
        for (from in mine) {
            InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(from) }
            val target = model.ui.legalTargets.firstOrNull()
            if (target != null) {
                InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(target) }
                played = true
                break
            }
            InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(from) }
        }
        assert(played) { "aucun coup légal trouvé" }
        compose.waitUntil(60_000) { model.ui.plies == pliesAfterReply && !model.ui.thinking }
    }

    /**
     * Barricades ALÉATOIRES : les murs bougent à chaque coup, et la reprise doit
     * repartir de la position CONSULTÉE, murs compris — aucun « départ + coups »
     * ne les reproduirait.
     */
    @Test fun auxBarricadesAleatoiresLaRepriseGardeLesMursConsultes() {
        lateinit var model: VariantPlayViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = VariantPlayViewModel(app) }
        val settings = VariantSettings(blunderAlertEnabled = false, showEvalBar = false)
        compose.setContent {
            VariantPlayScreen(
                variantId = com.chesslab.variants.BarricadesConfiguration.randomVariantId,
                settings = settings, model = model,
            )
        }
        playAnyMove(model, pliesAfterReply = 2)
        playAnyMove(model, pliesAfterReply = 4)

        compose.onNodeWithTag("precedent").performClick()
        compose.waitUntil(5_000) { model.ui.review?.ply == 2 }
        val wallsThen = model.ui.review!!.walls
        val positionThen = model.ui.review!!.position.fen

        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 2 && model.ui.review == null && !model.ui.thinking }
        assertEquals(wallsThen, model.ui.walls)
        assertEquals(positionThen, model.ui.position.fen)
        assertEquals(model.ui.userColor, model.ui.position.sideToMove)

        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 4 && !model.ui.thinking }
        assertEquals(4, model.ui.sanMoves.size)
    }

    /** Duck Chess : un tour = un coup ET la pose du canard. */
    @Test fun leDuckChessSeConsulteEtSeReprend() {
        lateinit var model: com.chesslab.variants.DuckChessViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = com.chesslab.variants.DuckChessViewModel(app) }
        val settings = VariantSettings(blunderAlertEnabled = false, showEvalBar = false)
        compose.setContent { com.chesslab.variants.DuckChessScreen(settings = settings, model = model) }

        // Le canard bloque des cases au hasard des poses : on joue le premier
        // coup légal trouvé plutôt qu'un coup fixé d'avance.
        fun turn(pliesAfterReply: Int) {
            compose.waitUntil(60_000) { !model.ui.thinking && model.ui.phase == com.chesslab.variants.DuckPhase.movePiece }
            val mine = model.ui.position.pieces.filter { it.color == model.ui.userColor }.map { it.square }
            for (from in mine) {
                InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(from) }
                val target = model.ui.legalTargets.firstOrNull()
                if (target != null) {
                    InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(target) }
                    break
                }
            }
            compose.waitUntil(10_000) { model.ui.phase == com.chesslab.variants.DuckPhase.placeDuck }
            val duck = model.ui.duckTargets.first()
            InstrumentationRegistry.getInstrumentation().runOnMainSync { model.onSquareTap(duck) }
            compose.waitUntil(90_000) { model.ui.plies == pliesAfterReply && !model.ui.thinking }
        }
        turn(2)
        turn(4)

        compose.onNodeWithTag("precedent").performClick()
        compose.waitUntil(5_000) { model.ui.review?.ply == 2 }
        val duckThen = model.ui.review!!.duck
        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 2 && model.ui.review == null && !model.ui.thinking }
        assertEquals(duckThen, model.ui.duck)
        assertEquals(model.ui.userColor, model.ui.position.sideToMove)

        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitUntil(30_000) { model.ui.plies == 4 && !model.ui.thinking }
    }

    /** Coup Volé : la reprise rejoue la partie jusque-là, jetons compris. */
    @Test fun leCoupVoleSeConsulteEtSeReprend() {
        lateinit var model: com.chesslab.variants.StolenMoveViewModel
        InstrumentationRegistry.getInstrumentation().runOnMainSync { model = com.chesslab.variants.StolenMoveViewModel(app) }
        val settings = VariantSettings(blunderAlertEnabled = false, showEvalBar = false)
        compose.setContent { com.chesslab.variants.StolenMoveScreen(settings = settings, model = model) }

        fun move(from: String, to: String, pliesAfterReply: Int) {
            compose.waitUntil(60_000) { !model.ui.thinking && model.ui.mover == model.ui.userColor }
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                model.onSquareTap(Square(from))
                model.onSquareTap(Square(to))
            }
            compose.waitUntil(90_000) { model.ui.sanMoves.size == pliesAfterReply && !model.ui.thinking }
        }
        move("e2", "e4", 2)
        move("d2", "d4", 4)

        compose.onNodeWithTag("precedent").performClick()
        compose.waitUntil(5_000) { model.ui.review?.ply == 2 }
        val positionThen = model.ui.review!!.position.fen
        compose.onNodeWithTag("reprendre-ici").performClick()
        compose.waitUntil(30_000) { model.ui.sanMoves.size == 2 && model.ui.review == null && !model.ui.thinking }
        assertEquals(positionThen, model.ui.position.fen)
        assertEquals(model.ui.userColor, model.ui.mover)

        compose.onNodeWithTag("annuler-reprise").performClick()
        compose.waitUntil(30_000) { model.ui.sanMoves.size == 4 && !model.ui.thinking }
    }
}

