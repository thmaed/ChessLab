package com.chesslab.twoplayer

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square

data class TwoPlayerUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "Aux blancs de jouer",
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
class TwoPlayerViewModel : ViewModel() {

    private var board = Board()

    var ui by mutableStateOf(TwoPlayerUiState())
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
        ui = TwoPlayerUiState(autoFlip = ui.autoFlip)
    }

    private fun refresh(move: Move) {
        val position = board.position
        val state = board.state
        val over = state is Board.State.Checkmate || state is Board.State.Draw

        val status = when (state) {
            is Board.State.Checkmate ->
                "Échec et mat — " + (if (state.color == Piece.Color.white) "les noirs gagnent" else "les blancs gagnent")
            is Board.State.Draw -> "Nulle — " + drawLabel(state.reason)
            is Board.State.Check ->
                "Échec — " + (if (position.sideToMove == Piece.Color.white) "aux blancs" else "aux noirs")
            else ->
                if (position.sideToMove == Piece.Color.white) "Aux blancs de jouer" else "Aux noirs de jouer"
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
        Board.State.DrawReason.stalemate -> "pat"
        Board.State.DrawReason.fiftyMoves -> "règle des cinquante coups"
        Board.State.DrawReason.insufficientMaterial -> "matériel insuffisant"
        Board.State.DrawReason.repetition -> "triple répétition"
        Board.State.DrawReason.agreement -> "accord"
    }
}
