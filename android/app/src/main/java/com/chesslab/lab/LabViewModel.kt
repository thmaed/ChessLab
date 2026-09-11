package com.chesslab.lab

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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Un camp du laboratoire : un personnage, ou Stockfish à un temps donné. */
data class LabSide(val profile: OpponentProfile?, val level: Double) {
    val label: String get() = profile?.displayName ?: "Stockfish"
}

data class LabUiState(
    val position: Position = Position.standard,
    val lastMove: Pair<Square, Square>? = null,
    val sanMoves: List<String> = emptyList(),
    val sideA: LabSide = LabSide(OpponentGallery.all.first(), 1800.0),
    val sideB: LabSide = LabSide(null, 1500.0),
    val movetimeMs: Int = 200,
    val running: Boolean = false,
    val status: String = "Prêt",
    /** Bilan de la série, du point de vue du camp A. */
    val winsA: Int = 0,
    val draws: Int = 0,
    val winsB: Int = 0,
    val gameNumber: Int = 0,
    /** Les couleurs alternent d'une partie à l'autre, comme sur iOS. */
    val aPlaysWhite: Boolean = true,
)

/**
 * Le laboratoire : l'ordinateur contre lui-même, en série.
 *
 * Pendant réduit de `LabRunView` / `LabGameSettings`. Les couleurs alternent
 * d'une partie à l'autre — sans quoi l'avantage du trait fausserait le bilan.
 */
class LabViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val history = mutableListOf(Position.standard)
    private var maia: MaiaOpponent? = null
    private var loop: Job? = null

    var ui by mutableStateOf(LabUiState())
        private set

    init {
        viewModelScope.launch {
            maia = withContext(Dispatchers.IO) {
                MaiaOpponent.shared(getApplication(), EngineService.threads)
            }
        }
    }

    fun setSideA(profile: OpponentProfile?) { ui = ui.copy(sideA = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setSideB(profile: OpponentProfile?) { ui = ui.copy(sideB = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setMovetime(ms: Int) { ui = ui.copy(movetimeMs = ms) }

    fun toggle() {
        if (ui.running) { stop(); return }
        ui = ui.copy(running = true, status = "En cours…")
        loop = viewModelScope.launch { runSeries() }
    }

    fun stop() {
        loop?.cancel()
        loop = null
        ui = ui.copy(running = false, status = "En pause")
    }

    fun reset() {
        stop()
        newGame()
        ui = ui.copy(winsA = 0, draws = 0, winsB = 0, gameNumber = 0, aPlaysWhite = true, status = "Prêt")
    }

    private fun newGame() {
        board = Board()
        history.clear()
        history += Position.standard
        ui = ui.copy(position = Position.standard, lastMove = null, sanMoves = emptyList())
    }

    private suspend fun runSeries() {
        while (viewModelScope.isActive && ui.running) {
            if (board.state is Board.State.Checkmate || board.state is Board.State.Draw) {
                tally()
                newGame()
                ui = ui.copy(gameNumber = ui.gameNumber + 1, aPlaysWhite = !ui.aPlaysWhite)
                continue
            }
            if (!step()) { stop(); return }
        }
    }

    /** Un demi-coup. `false` si personne n'a su répondre. */
    private suspend fun step(): Boolean {
        val whiteIsA = ui.aPlaysWhite
        val toMove = board.position.sideToMove
        val side = if ((toMove == Piece.Color.white) == whiteIsA) ui.sideA else ui.sideB

        val lan = withContext(Dispatchers.IO) {
            val profile = side.profile
            val engine = maia
            if (profile != null && engine != null) {
                val mood = profile.mood(null)
                engine.chooseMove(
                    history = history.toList(),
                    board = Board(board.position.copy()),
                    selfElo = side.level, oppoElo = side.level,
                    temperature = mood.temperature, topP = profile.topP, style = mood.style,
                )?.uci
            } else {
                EngineService.use(getApplication()) { e ->
                    e.send("position fen ${board.position.fen}")
                    e.search("go movetime ${ui.movetimeMs}", timeoutMs = 60_000)
                }?.split(" ")?.getOrNull(1)
            }
        } ?: return false

        if (lan == "(none)" || lan.length < 4) return false
        var move: Move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            ?: return false
        if (lan.length == 5) {
            move = board.completePromotion(
                of = move,
                to = when (lan[4]) {
                    'q' -> Piece.Kind.queen
                    'r' -> Piece.Kind.rook
                    'b' -> Piece.Kind.bishop
                    else -> Piece.Kind.knight
                },
            )
        }
        history += board.position.copy()

        ui = ui.copy(
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            status = "${side.label} a joué ${move.san}",
        )
        return true
    }

    private fun tally() {
        when (val state = board.state) {
            is Board.State.Checkmate -> {
                // `state.color` est le camp MATÉ
                val loserIsA = (state.color == Piece.Color.white) == ui.aPlaysWhite
                ui = if (loserIsA) ui.copy(winsB = ui.winsB + 1) else ui.copy(winsA = ui.winsA + 1)
            }
            is Board.State.Draw -> ui = ui.copy(draws = ui.draws + 1)
            else -> Unit
        }
    }

    override fun onCleared() {
        loop?.cancel()
        super.onCleared()
    }
}
