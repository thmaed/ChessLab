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
import com.chesslab.library.GameRecorder
import com.chesslab.maia.MaiaOpponent
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.s

/** Un camp du laboratoire : un personnage, ou Stockfish à un temps donné. */
data class LabSide(val profile: OpponentProfile?, val level: Double) {
    /** Le nom affiché demande un contexte : le surnom est une ressource. */
    fun label(context: android.content.Context): String =
        profile?.displayName(context) ?: context.getString(R.string.stockfish)
}

data class LabUiState(
    val position: Position = Position.standard,
    val lastMove: Pair<Square, Square>? = null,
    val sanMoves: List<String> = emptyList(),
    val sideA: LabSide = LabSide(OpponentGallery.all.first(), 1800.0),
    val sideB: LabSide = LabSide(null, 1500.0),
    val movetimeMs: Int = 200,
    val running: Boolean = false,
    val status: String = "",
    /** Les parties TERMINÉES de la série : c'est d'elles que tout se déduit. */
    val completed: List<LabCompletedGame> = emptyList(),
    val gameNumber: Int = 0,
    /** Les couleurs alternent d'une partie à l'autre, comme sur iOS. */
    val aPlaysWhite: Boolean = true,
    /** La position imposée à la série, quand elle n'est pas la position standard. */
    val startFen: String? = null,
) {
    /**
     * Le bilan, RECALCULÉ à partir des parties plutôt que compté au fil de
     * l'eau : un compteur et une liste finissent par diverger, et c'est le
     * genre de divergence qu'on ne voit pas — les chiffres restent
     * plausibles.
     */
    val stats: LabStats
        get() = LabStats.of(completed.map { it.labResult }, completed.map { it.plyCount })

    val winsA: Int get() = stats.winsA
    val draws: Int get() = stats.draws
    val winsB: Int get() = stats.winsB
}

/**
 * Le laboratoire : l'ordinateur contre lui-même, en série.
 *
 * Pendant réduit de `LabRunView` / `LabGameSettings`. Les couleurs alternent
 * d'une partie à l'autre — sans quoi l'avantage du trait fausserait le bilan.
 */
class LabViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val history = mutableListOf(Position.standard)

    /** La position de départ de CHAQUE partie de la série. */
    private var startPosition: Position = Position.standard

    /**
     * L'HISTOIRE de la partie en cours, et pas seulement sa position : c'est
     * elle qui rend un PGN, donc l'export. Le plateau, lui, ne sait rien du
     * chemin parcouru.
     */
    private var recorder = GameRecorder()
    private var maia: MaiaOpponent? = null
    private var loop: Job? = null

    var ui by mutableStateOf(LabUiState(status = s(R.string.lab_ready)))
        private set

    init {
        viewModelScope.launch {
            maia = withContext(Dispatchers.IO) {
                MaiaOpponent.shared(getApplication(), EngineService.threads)
            }
        }
    }

    /**
     * Impose la position de départ de la série. Sans effet en cours de
     * série : changer le point de départ au milieu d'un bilan le fausserait.
     */
    fun startFrom(fen: String) {
        val position = Position.fromFen(fen) ?: return
        if (ui.running || position.fen == startPosition.fen) return
        startPosition = position
        ui = ui.copy(startFen = position.fen.takeIf { it != Position.standard.fen })
        reset()
    }

    /** Revenir à la position standard : la série repart de zéro. */
    fun clearStartPosition() {
        if (ui.running || ui.startFen == null) return
        startPosition = Position.standard
        ui = ui.copy(startFen = null)
        reset()
    }

    fun setSideA(profile: OpponentProfile?) { ui = ui.copy(sideA = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setSideB(profile: OpponentProfile?) { ui = ui.copy(sideB = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setMovetime(ms: Int) { ui = ui.copy(movetimeMs = ms) }

    fun toggle() {
        if (ui.running) { stop(); return }
        ui = ui.copy(running = true, status = s(R.string.lab_running))
        loop = viewModelScope.launch { runSeries() }
    }

    fun stop() {
        loop?.cancel()
        loop = null
        ui = ui.copy(running = false, status = s(R.string.lab_paused))
    }

    fun reset() {
        stop()
        ui = ui.copy(completed = emptyList(), gameNumber = 0, aPlaysWhite = true, status = s(R.string.lab_ready))
        newGame()
    }

    private fun newGame() {
        board = Board(startPosition)
        history.clear()
        history += startPosition
        recorder.reset(startPosition, startFen = ui.startFen)
        ui = ui.copy(position = startPosition, lastMove = null, sanMoves = emptyList())
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
        recorder.record(move)

        ui = ui.copy(
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            status = s(R.string.lab_played, side.label(getApplication()), move.san),
        )
        return true
    }

    /**
     * La partie qui vient de finir entre au bilan, avec son PGN.
     *
     * Le résultat est rangé côté ÉCHIQUIER (« 1-0 ») et non côté A : c'est ce
     * qu'attend un PGN, et `LabCompletedGame` sait retrouver le point de vue
     * de A à partir de la couleur qu'il avait dans cette partie-là. Compter
     * directement pour A, comme on le faisait, rendait l'export impossible.
     */
    private fun tally() {
        val state = board.state
        val result = when (state) {
            is Board.State.Checkmate -> if (state.color == Piece.Color.white) "0-1" else "1-0"
            is Board.State.Draw -> "1/2-1/2"
            else -> return
        }
        ui = ui.copy(
            completed = ui.completed + LabCompletedGame(
                index = ui.completed.size,
                aWasWhite = ui.aPlaysWhite,
                pgnResult = result,
                reasonLabel = reasonLabel(state),
                plyCount = ui.sanMoves.size,
                pgn = recorder.pgn,
            )
        )
    }

    private fun reasonLabel(state: Board.State): String = when (state) {
        is Board.State.Checkmate -> s(R.string.lab_end_checkmate)
        is Board.State.Draw -> when (state.reason) {
            Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
            Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
            Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
            Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
            Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
        }
        else -> ""
    }

    /** Le PGN de toute la série, pour l'export. */
    fun exportPgn(): String = LabExport.pgn(
        ui.completed,
        nameA = ui.sideA.label(getApplication()),
        nameB = ui.sideB.label(getApplication()),
    )

    /** Le CSV de toute la série : une ligne par partie. */
    fun exportCsv(): String = LabExport.csv(ui.completed)

    override fun onCleared() {
        loop?.cancel()
        super.onCleared()
    }
}
