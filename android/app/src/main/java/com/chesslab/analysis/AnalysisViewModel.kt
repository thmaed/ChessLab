package com.chesslab.analysis

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Board
import chesskit.FenParser
import chesskit.Move
import chesskit.MoveTree
import chesskit.PgnParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.engine.EngineService
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.s

data class AnalysisUiState(
    val position: Position = Position.standard,
    val sanMoves: List<String> = emptyList(),
    /** -1 = position de départ ; sinon l'index du coup joué. */
    val cursor: Int = -1,
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val evaluation: String = "",
    val depth: Int = 0,
    val bestLine: String = "",
    val thinking: Boolean = false,
    val input: String = "",
    val error: String? = null,
)

/**
 * Analyser une partie : charger un PGN ou une FEN, parcourir les coups, et
 * lire l'évaluation du moteur à chaque position.
 *
 * Pendant réduit d'`AnalysisViewModel.swift`. Le filet de `PGNLoader` n'a PAS
 * d'équivalent ici : les deux bugs qu'il contourne côté iOS sont corrigés dans
 * le port, donc rien n'est perdu à l'import — ni variantes, ni commentaires.
 */
class AnalysisViewModel(app: Application) : AndroidViewModel(app) {

    private var positions: List<Position> = listOf(Position.standard)
    private var moves: List<Move> = emptyList()
    private var evalJob: Job? = null

    var ui by mutableStateOf(AnalysisUiState(status = s(R.string.analysis_paste)))
        private set

    /** Les parties enregistrées, les plus récentes d'abord. */
    val savedGames: Flow<List<GameRecord>> =
        LibraryDatabase.get(app).games().all()

    /** Charge une partie de la bibliothèque comme si on collait son PGN. */
    fun open(record: GameRecord) {
        ui = ui.copy(input = record.pgn)
        load()
    }

    fun onInputChange(text: String) { ui = ui.copy(input = text, error = null) }

    fun load() {
        val text = ui.input.trim()
        if (text.isEmpty()) return

        // une FEN d'abord — c'est plus court et sans ambiguïté
        FenParser.parse(text)?.let { position ->
            positions = listOf(position)
            moves = emptyList()
            ui = ui.copy(
                position = position, sanMoves = emptyList(), cursor = -1,
                lastMove = null, status = s(R.string.analysis_position_loaded), error = null,
            )
            evaluate()
            return
        }

        val game = try {
            PgnParser.parse(text)
        } catch (e: Exception) {
            ui = ui.copy(error = "PGN illisible : ${e.message}")
            return
        }

        val mainline = game.moves.indices
            .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
            .sorted()

        if (mainline.isEmpty()) {
            ui = ui.copy(error = s(R.string.analysis_no_moves))
            return
        }

        val start = game.startingPosition ?: Position.standard
        positions = listOf(start) + mainline.mapNotNull { game.position(it) }
        moves = mainline.mapNotNull { game.moves[it] }

        val label = listOfNotNull(
            game.tags.white.ifEmpty { null },
            game.tags.black.ifEmpty { null },
        ).joinToString(" — ").ifEmpty { s(R.string.analysis_game_loaded) }

        ui = ui.copy(
            sanMoves = moves.map { it.san },
            cursor = moves.size - 1,
            status = label,
            error = null,
        )
        goTo(moves.size - 1)
    }

    fun goTo(index: Int) {
        val clamped = index.coerceIn(-1, moves.size - 1)
        val position = positions.getOrNull(clamped + 1) ?: return
        val move = moves.getOrNull(clamped)

        val board = Board(position.copy())
        val checked = when (val state = board.state) {
            is Board.State.Check -> kingSquare(position, state.color)
            is Board.State.Checkmate -> kingSquare(position, state.color)
            else -> null
        }

        ui = ui.copy(
            position = position,
            cursor = clamped,
            lastMove = move?.let { it.start to it.end },
            checkedKing = checked,
            evaluation = "", depth = 0, bestLine = "",
        )
        evaluate()
    }

    fun previous() = goTo(ui.cursor - 1)
    fun next() = goTo(ui.cursor + 1)

    private fun evaluate() {
        evalJob?.cancel()
        val fen = ui.position.fen
        val sideToMove = ui.position.sideToMove

        evalJob = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            withContext(Dispatchers.IO) {
                EngineService.use(getApplication()) { e ->
                    e.send("position fen $fen")
                    e.search("go depth 18", timeoutMs = 30_000) { line ->
                        if (line.startsWith("info ") && line.contains(" score ")) {
                            parseInfo(line, sideToMove)?.let { (score, depth, pv) ->
                                ui = ui.copy(evaluation = score, depth = depth, bestLine = pv)
                            }
                        }
                    }
                }
            }
            ui = ui.copy(thinking = false)
        }
    }

    /**
     * Une ligne `info` du moteur → score lisible, profondeur, meilleure ligne.
     *
     * Le score UCI est TOUJOURS du point de vue du camp au trait ; on le
     * ramène au point de vue des blancs, comme le fait l'app iOS, sans quoi
     * l'évaluation changerait de signe à chaque coup.
     */
    private fun parseInfo(line: String, sideToMove: Piece.Color): Triple<String, Int, String>? {
        val depth = line.substringAfter(" depth ", "").substringBefore(" ").toIntOrNull() ?: return null
        val pv = line.substringAfter(" pv ", "").trim()

        val mate = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
        val cp = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()

        val sign = if (sideToMove == Piece.Color.white) 1 else -1
        val text = when {
            mate != null -> {
                val plies = mate * sign
                (if (plies > 0) "+M$plies" else "−M${-plies}")
            }
            cp != null -> {
                val pawns = cp * sign / 100.0
                (if (pawns >= 0) "+%.2f" else "−%.2f").format(kotlin.math.abs(pawns))
            }
            else -> return null
        }
        return Triple(text, depth, pv)
    }

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square
}
