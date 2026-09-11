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
import com.chesslab.maia.MaiaOpponent
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class PlayUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "Démarrage…",
    val sanMoves: List<String> = emptyList(),
    val thinking: Boolean = false,
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    /** `null` = Stockfish brut. */
    val opponent: OpponentProfile? = OpponentGallery.all.first(),
    val level: Double = OpponentGallery.all.first().defaultLevel,
    val maiaAvailable: Boolean = true,
)

/**
 * Une partie contre l'ordinateur : un des neuf personnages, ou Stockfish.
 *
 * Pendant réduit de `PlayViewModel.swift`. Les personnages sont Maia-3 — un
 * réseau entraîné sur des parties HUMAINES — recoloré par un style borné ;
 * Stockfish reste disponible pour qui veut un mur.
 */
class PlayViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val humanColor = Piece.Color.white

    /** L'historique des positions : Maia lit les huit dernières. */
    private val history = mutableListOf(Position.standard)

    private var maia: MaiaOpponent? = null

    var ui by mutableStateOf(PlayUiState())
        private set

    init { prepare() }

    private fun prepare() = viewModelScope.launch {
        val loaded = withContext(Dispatchers.IO) {
            MaiaOpponent.shared(getApplication(), EngineService.threads)
        }
        maia = loaded
        // Stockfish sert au filet et au mode « moteur » : on le démarre aussi
        withContext(Dispatchers.IO) { EngineService.use(getApplication()) { EngineService.identity } }
        ui = ui.copy(maiaAvailable = loaded != null)
        refresh(if (loaded == null) "Modèle indisponible — Stockfish prend le relais" else "À vous de jouer")
    }

    fun chooseOpponent(profile: OpponentProfile?) {
        ui = ui.copy(
            opponent = profile,
            level = profile?.defaultLevel ?: 1500.0,
        )
        newGame()
    }

    fun setLevel(value: Double) {
        val clamped = ui.opponent?.clampedLevel(value) ?: value.coerceIn(800.0, 3000.0)
        ui = ui.copy(level = clamped)
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
        ui = if (piece != null && piece.color == humanColor) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun play(from: Square, to: Square) {
        val move = board.move(pieceAt = from, to = to) ?: return
        if (board.state is Board.State.Promotion) {
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
        history += board.position.copy()
        refresh(null, move)
        if (!ui.gameOver && board.position.sideToMove != humanColor) askOpponent()
    }

    private fun askOpponent() = viewModelScope.launch {
        val profile = ui.opponent
        ui = ui.copy(thinking = true, status = thinkingLabel(profile))

        val lan = withContext(Dispatchers.IO) {
            val engine = maia
            if (profile != null && engine != null) {
                // le personnage tel qu'il joue MAINTENANT : sans évaluation
                // continue, on s'en tient à son humeur de repos
                val mood = profile.mood(lastMoverCp = null)
                engine.chooseMove(
                    history = history.toList(),
                    board = Board(board.position.copy()),
                    selfElo = ui.level,
                    oppoElo = ui.level,
                    temperature = mood.temperature,
                    topP = profile.topP,
                    style = mood.style,
                )?.uci
            } else {
                EngineService.use(getApplication()) { e ->
                    e.send("position fen ${board.position.fen}")
                    e.search("go movetime ${SettingsStore.state.value.engineMoveTimeMs}", timeoutMs = 60_000)
                }?.split(" ")?.getOrNull(1)
            }
        }
        ui = ui.copy(thinking = false)

        if (lan == null || lan == "(none)") { refresh("L'adversaire n'a pas répondu"); return@launch }

        val from = Square(lan.substring(0, 2))
        val to = Square(lan.substring(2, 4))
        var move = board.move(pieceAt = from, to = to)
        if (move == null) { refresh("Coup refusé : $lan"); return@launch }

        if (lan.length == 5) {
            val kind = when (lan[4]) {
                'q' -> Piece.Kind.queen
                'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop
                else -> Piece.Kind.knight
            }
            move = board.completePromotion(of = move, to = kind)
        }
        history += board.position.copy()
        refresh(null, move)
    }

    private fun thinkingLabel(profile: OpponentProfile?): String =
        if (profile != null) "${profile.firstName} réfléchit…" else "Le moteur réfléchit…"

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
            else -> if (position.sideToMove == humanColor) "À vous de jouer" else thinkingLabel(ui.opponent)
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
        history.clear()
        history += Position.standard
        ui = ui.copy(
            position = Position.standard,
            selected = null, legalTargets = emptySet(), lastMove = null, checkedKing = null,
            sanMoves = emptyList(), gameOver = false, pendingPromotion = null,
            status = "À vous de jouer",
        )
    }
}
