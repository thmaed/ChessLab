package com.chesslab.play

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.engine.EngineService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class PlayUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "Démarrage du moteur…",
    val sanMoves: List<String> = emptyList(),
    val thinking: Boolean = false,
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
)

/**
 * Une partie contre le moteur. Pendant réduit de `PlayViewModel.swift`.
 *
 * Le joueur a les blancs ; le moteur répond dès que le trait change.
 */
class PlayViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val humanColor = Piece.Color.white

    var ui by mutableStateOf(PlayUiState())
        private set

    init { startEngine() }

    private fun startEngine() = viewModelScope.launch {
        val identity = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { EngineService.identity }
        }
        refresh(if (identity == null) "Moteur indisponible" else "À vous de jouer")
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || ui.pendingPromotion != null) return
        if (board.position.sideToMove != humanColor) return

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            play(selected, square)
            return
        }

        val piece = board.position.piece(square)
        if (piece != null && piece.color == humanColor) {
            ui = ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui = ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun play(from: Square, to: Square) {
        val move = board.move(pieceAt = from, to = to) ?: return
        val state = board.state
        if (state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        recordAndContinue(move)
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val move = board.completePromotion(of = pending, to = kind)
        ui = ui.copy(pendingPromotion = null)
        recordAndContinue(move)
    }

    private fun recordAndContinue(move: Move) {
        refresh(null, move)
        if (!ui.gameOver && board.position.sideToMove != humanColor) askEngine()
    }

    private fun askEngine() = viewModelScope.launch {
        ui = ui.copy(thinking = true, status = "Le moteur réfléchit…")
        val best = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { e ->
                e.send("position fen ${board.position.fen}")
                e.search("go movetime 400", timeoutMs = 20_000)
            }
        }
        ui = ui.copy(thinking = false)

        val lan = best?.split(" ")?.getOrNull(1)
        if (lan == null || lan == "(none)") { refresh("Le moteur n'a pas répondu"); return@launch }

        val from = Square(lan.substring(0, 2))
        val to = Square(lan.substring(2, 4))
        var move = board.move(pieceAt = from, to = to)
        if (move == null) { refresh("Coup du moteur refusé : $lan"); return@launch }

        if (lan.length == 5) {
            val kind = when (lan[4]) {
                'q' -> Piece.Kind.queen
                'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop
                else -> Piece.Kind.knight
            }
            move = board.completePromotion(of = move, to = kind)
        }
        refresh(null, move)
    }

    private fun refresh(status: String?, move: Move? = null) {
        val position = board.position
        val state = board.state

        val checkedKing = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        val text = status ?: when (state) {
            is Board.State.Checkmate ->
                if (state.color == humanColor) "Échec et mat — vous perdez" else "Échec et mat — vous gagnez"
            is Board.State.Draw -> "Nulle — " + drawLabel(state.reason)
            is Board.State.Check -> "Échec"
            else -> if (position.sideToMove == humanColor) "À vous de jouer" else "Le moteur réfléchit…"
        }

        ui = ui.copy(
            position = position,
            selected = null,
            legalTargets = emptySet(),
            lastMove = move?.let { it.start to it.end } ?: ui.lastMove,
            checkedKing = checkedKing,
            status = text,
            sanMoves = if (move != null) ui.sanMoves + move.san else ui.sanMoves,
            gameOver = over,
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

    fun newGame() {
        board = Board()
        ui = PlayUiState(status = "À vous de jouer")
    }

}
