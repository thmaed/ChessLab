package com.chesslab.puzzles

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
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class PuzzleOutcome { solving, solved, failed }

data class PuzzleUiState(
    val position: Position = Position.standard,
    val puzzle: Puzzle? = null,
    val orientation: Piece.Color = Piece.Color.white,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "Chargement de la bibliothèque…",
    val outcome: PuzzleOutcome = PuzzleOutcome.solving,
    val solvedCount: Int = 0,
    val attemptedCount: Int = 0,
    val pendingPromotion: Move? = null,
    val loading: Boolean = true,
    val busy: Boolean = false,
    /** Essais restants sur le puzzle courant (réglage : un ou trois). */
    val attemptsLeft: Int = 1,
)

/**
 * Résoudre des puzzles. Pendant réduit de `PuzzleSolveViewModel.swift`.
 *
 * Convention de la bibliothèque : la FEN est DÉJÀ au trait du résolveur, et
 * `solutionLANs` commence par SON coup. L'app joue donc les coups d'index
 * impair (les ripostes) et attend ceux d'index pair.
 */
class PuzzleViewModel(app: Application) : AndroidViewModel(app) {

    private var queue: List<Puzzle> = emptyList()
    private var cursor = 0
    private var board = Board()
    private var step = 0

    var ui by mutableStateOf(PuzzleUiState())
        private set

    init {
        viewModelScope.launch {
            val sampled = withContext(Dispatchers.IO) {
                runCatching { PuzzleRepository.sample(getApplication<Application>().assets, count = 40) }
                    .getOrDefault(emptyList())
            }
            queue = sampled
            if (queue.isEmpty()) {
                ui = ui.copy(loading = false, status = "Bibliothèque indisponible")
            } else {
                ui = ui.copy(loading = false)
                present(0)
            }
        }
    }

    private fun present(index: Int) {
        cursor = index.coerceIn(queue.indices)
        val puzzle = queue[cursor]
        val position = Position.fromFen(puzzle.fen) ?: return
        board = Board(position)
        step = 0

        ui = ui.copy(
            puzzle = puzzle,
            position = board.position,
            orientation = board.position.sideToMove,
            selected = null,
            legalTargets = emptySet(),
            lastMove = null,
            checkedKing = null,
            outcome = PuzzleOutcome.solving,
            attemptsLeft = SettingsStore.state.value.puzzleAttempts,
            status = "${puzzle.themeLabel} · ${puzzle.rating} — trouvez le meilleur coup",
        )
    }

    fun next() {
        if (queue.isEmpty()) return
        present((cursor + 1) % queue.size)
    }

    fun onSquareTap(square: Square) {
        val puzzle = ui.puzzle ?: return
        if (ui.outcome != PuzzleOutcome.solving || ui.busy || ui.pendingPromotion != null) return

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            attempt(selected, square, puzzle)
            return
        }

        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == board.position.sideToMove) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun attempt(from: Square, to: Square, puzzle: Puzzle) {
        val expected = puzzle.solution.getOrNull(step) ?: return
        val played = from.notation + to.notation

        // On compare AVANT de jouer : un coup faux ne doit pas salir le plateau.
        if (!expected.startsWith(played)) {
            val left = ui.attemptsLeft - 1
            ui = if (left > 0) {
                ui.copy(
                    selected = null, legalTargets = emptySet(),
                    attemptsLeft = left,
                    status = "Ce n'est pas le coup — il vous reste $left essai" + (if (left > 1) "s" else ""),
                )
            } else {
                ui.copy(
                    selected = null, legalTargets = emptySet(),
                    outcome = PuzzleOutcome.failed,
                    attemptedCount = ui.attemptedCount + 1,
                    status = "Ce n'est pas le coup — la solution commençait par $expected",
                )
            }
            return
        }

        var move = board.move(pieceAt = from, to = to) ?: return
        if (expected.length == 5) {
            move = board.completePromotion(of = move, to = kindOf(expected[4]))
        } else if (board.state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        step++
        advance(move, puzzle)
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val puzzle = ui.puzzle ?: return
        val move = board.completePromotion(of = pending, to = kind)
        ui = ui.copy(pendingPromotion = null)
        step++
        advance(move, puzzle)
    }

    /** Le coup du résolveur est joué : on enchaîne la riposte, ou on conclut. */
    private fun advance(move: Move, puzzle: Puzzle) {
        show(move, "Bien joué — continuez")

        if (step >= puzzle.solution.size) {
            ui = ui.copy(
                outcome = PuzzleOutcome.solved,
                solvedCount = ui.solvedCount + 1,
                attemptedCount = ui.attemptedCount + 1,
                status = "Résolu",
            )
            return
        }

        viewModelScope.launch {
            ui = ui.copy(busy = true)
            delay(450)                      // le temps de voir le coup
            val lan = puzzle.solution[step]
            var reply = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            if (reply != null && lan.length == 5) {
                reply = board.completePromotion(of = reply, to = kindOf(lan[4]))
            }
            step++
            ui = ui.copy(busy = false)
            if (reply != null) show(reply, "À vous")
        }
    }

    private fun show(move: Move, status: String) {
        val state = board.state
        val checked = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }
        ui = ui.copy(
            position = board.position,
            selected = null,
            legalTargets = emptySet(),
            lastMove = move.start to move.end,
            checkedKing = checked,
            status = if (ui.outcome == PuzzleOutcome.solving) status else ui.status,
        )
    }

    private fun kingSquare(color: Piece.Color): Square? =
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    private fun kindOf(c: Char): Piece.Kind = when (c) {
        'q' -> Piece.Kind.queen
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        else -> Piece.Kind.knight
    }
}
