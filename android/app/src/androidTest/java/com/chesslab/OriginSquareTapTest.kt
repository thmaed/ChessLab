package com.chesslab

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import chesskit.Board
import chesskit.Game
import chesskit.Piece
import chesskit.Square
import com.chesslab.ui.BoardView
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * La pièce posée sur le coin haut-gauche du plateau — h1 quand on joue les
 * Noirs — répond au doigt. Pendant de `OriginSquareSelectionUITests.swift`.
 *
 * Signalé côté iOS le 22/10/2026 : « ma dame en h1 est soudainement
 * impossible à sélectionner ». Le défaut tenait au hit-testing de SwiftUI en
 * iOS 18 (les cadres des pièces empilés à l'origine du plateau) ; le plateau
 * Compose, qui reçoit chaque toucher par la case elle-même, n'a pas cette
 * construction. Ce test le PROUVE sur la partie exacte du joueur, au lieu de
 * le supposer.
 */
@RunWith(AndroidJUnit4::class)
class OriginSquareTapTest {

    @get:Rule val compose = createComposeRule()

    private val moves = (
        "e4 Nf6 Bc4 Nxe4 Nf3 d5 Bb3 Bg4 h3 Bh5 O-O Ng5 Re1 Nxf3+ gxf3 e6 d3 Qf6 " +
            "Nd2 Qg5+ Kf1 Bc5 c4 O-O cxd5 exd5 Bc2 Qh4 d4 Bxd4 Re2 Qxh3+ Ke1 Qh1+ " +
            "Nf1 Nc6 Ba4 Bxf3 Bxc6 Bxe2 Qxe2 bxc6 Be3 Rfe8 Qd3 Bxe3 fxe3 Rad8 Kd2 d4 " +
            "Kc2 dxe3 Qe2"
        ).split(" ")

    @Test
    fun laDameNoireEnH1RepondAuDoigtPlateauRetourne() {
        val game = Game()
        val end = game.make(moves, game.startingIndex)
        val position = game.position(end)!!
        assertEquals("3rr1k1/p1p2ppp/2p5/8/8/4p3/PPK1Q3/R4N1q b - - 1 27", position.fen)
        // Les règles d'abord : la dame a ses onze coups, comme dans ChessKit.
        assertEquals(11, Board(position).legalMoves(Square.h1).size)

        val taps = mutableListOf<Square>()
        compose.setContent {
            Box(Modifier.size(320.dp).testTag("plateau")) {
                BoardView(
                    position = position,
                    orientation = Piece.Color.black,
                    draggableColor = Piece.Color.black,
                    onSquareTap = { taps += it },
                )
            }
        }
        // Le centre de la case du coin haut-gauche : 1/16 du plateau.
        compose.onNodeWithTag("plateau").performTouchInput {
            click(androidx.compose.ui.geometry.Offset(width / 16f, height / 16f))
        }
        compose.waitForIdle()
        assertEquals(listOf(Square.h1), taps)
    }
}
