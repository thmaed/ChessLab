package com.chesslab.twoplayer

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.AndroidViewModel
import android.app.Application
import com.chesslab.library.GameRecorder
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.SoundPlayer
import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.s

data class TwoPlayerUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val sanMoves: List<String> = emptyList(),
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    val orientation: Piece.Color = Piece.Color.white,
    val autoFlip: Boolean = true,
)

/**
 * Deux joueurs sur le même appareil. Pendant réduit de
 * `TwoPlayerViewModel.swift`.
 *
 * Le plateau se retourne à chaque coup quand [TwoPlayerUiState.autoFlip] est
 * actif : c'est ce qui rend le mode jouable à deux autour d'un téléphone.
 */
class TwoPlayerViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val recorder = GameRecorder()

    var ui by mutableStateOf(
        TwoPlayerUiState(
            autoFlip = SettingsStore.state.value.autoFlipTwoPlayer,
            status = s(R.string.white_to_move),
        )
    )
        private set

    fun onSquareTap(square: Square) {
        if (ui.gameOver || ui.pendingPromotion != null) return
        val mover = board.position.sideToMove

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            val move = board.move(pieceAt = selected, to = square) ?: return
            if (board.state is Board.State.Promotion) {
                ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
                return
            }
            refresh(move)
            return
        }

        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == mover) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val move = board.completePromotion(of = pending, to = kind)
        ui = ui.copy(pendingPromotion = null)
        refresh(move)
    }

    fun toggleAutoFlip() {
        ui = ui.copy(autoFlip = !ui.autoFlip)
    }

    fun flip() {
        ui = ui.copy(orientation = ui.orientation.opposite)
    }

    fun newGame() {
        board = Board()
        recorder.reset()
        ui = TwoPlayerUiState(autoFlip = ui.autoFlip)
    }

    private fun refresh(move: Move) {
        recorder.record(move)
        val position = board.position
        val state = board.state

        // le son suit le COUP, pas l'état : une prise reste une prise même
        // quand elle donne échec — c'est l'échec qui l'emporte
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        move.let {
            SoundPlayer.forMove(
                isCapture = it.result is Move.Result.Capture,
                isCastle = it.result is Move.Result.Castle,
                isCheck = state is Board.State.Check || state is Board.State.Checkmate,
            )
        }

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        if (over && !ui.gameOver) {
            recorder.save(
                getApplication(), white = s(R.string.color_white), black = s(R.string.color_black),
                source = "twoPlayer", state = state,
            )
        }

        val status = when (state) {
            is Board.State.Checkmate ->
                s(R.string.checkmate_side, s(if (state.color == Piece.Color.white) R.string.mate_black_wins else R.string.mate_white_wins))
            is Board.State.Draw -> s(R.string.draw_reason, drawLabel(state.reason))
            is Board.State.Check ->
                s(R.string.check_side, s(if (position.sideToMove == Piece.Color.white) R.string.check_white else R.string.check_black))
            else ->
                s(if (position.sideToMove == Piece.Color.white) R.string.white_to_move else R.string.black_to_move)
        }

        val checkedKing = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }

        ui = ui.copy(
            position = position,
            selected = null,
            legalTargets = emptySet(),
            lastMove = move.start to move.end,
            checkedKing = checkedKing,
            status = status,
            sanMoves = ui.sanMoves + move.san,
            gameOver = over,
            orientation = if (ui.autoFlip && !over) position.sideToMove else ui.orientation,
        )
    }

    private fun kingSquare(color: Piece.Color): Square? =
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    private fun drawLabel(reason: Board.State.DrawReason): String = when (reason) {
        Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
        Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
        Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
        Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
        Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
    }
}
