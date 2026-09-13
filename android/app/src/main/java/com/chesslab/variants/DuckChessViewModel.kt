package com.chesslab.variants

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.s
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.math.abs

/** Le tour se joue en DEUX temps : on déplace une pièce, puis on pose le canard. */
enum class DuckPhase { movePiece, placeDuck, over }

data class DuckUiState(
    val position: Position = Position.standard,
    /** La case du canard, `null` tant qu'il n'est pas posé. */
    val duck: Square? = null,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val duckTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val phase: DuckPhase = DuckPhase.movePiece,
    val status: String = "",
    val plies: Int = 0,
    /** Le vainqueur, quand un roi est tombé. C'est la SEULE fin de partie. */
    val winner: Piece.Color? = null,
    val thinking: Boolean = false,
)

/**
 * Le Duck Chess. Pendant réduit de `DuckChessViewModel.swift`.
 *
 * La seule variante du hub dont la légalité est calculée dans l'app :
 * [DuckChessRules] les engendre, [DuckChessFen] les applique, et Stockfish
 * n'est qu'un conseiller — borné aux coups que le canard autorise.
 *
 * Le trait ne change PAS au déplacement d'une pièce : le tour n'est pas fini
 * tant que le canard n'est pas posé. C'est la pose qui le passe, et elle
 * seule — faire les deux basculerait le trait deux fois par demi-coup, donc
 * jamais.
 */
class DuckChessViewModel(app: Application) : AndroidViewModel(app) {

    private val humanColor = Piece.Color.white
    private var enPassant: Square? = null
    private var legal: List<DuckChessRules.Move> = emptyList()
    private var turn: Job? = null

    var ui by mutableStateOf(DuckUiState())
        private set

    init { newGame() }

    fun newGame() {
        turn?.cancel()
        enPassant = null
        ui = DuckUiState(status = s(R.string.your_turn))
        refreshLegal()
    }

    private fun refreshLegal() {
        legal = DuckChessRules.moves(ui.position, ui.duck, enPassant)
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.winner != null) return
        if (ui.position.sideToMove != humanColor) return

        if (ui.phase == DuckPhase.placeDuck) {
            if (square in ui.duckTargets) placeDuck(square)
            return
        }

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            // La promotion se fait en DAME, comme dans les autres variantes du
            // hub : proposer les quatre pièces ici alourdirait un écran qui
            // porte déjà un tour en deux temps.
            val move = legal.firstOrNull { it.from == selected && it.to == square && it.promotion == Piece.Kind.queen }
                ?: legal.firstOrNull { it.from == selected && it.to == square }
                ?: return
            play(move)
            return
        }

        val piece = ui.position.piece(square)
        ui = if (piece != null && piece.color == humanColor) {
            ui.copy(
                selected = square,
                legalTargets = legal.filter { it.from == square }.mapTo(HashSet()) { it.to },
            )
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    /** Le déplacement d'une pièce — la moitié d'un tour. */
    private fun play(move: DuckChessRules.Move) {
        val position = ui.position
        val victim = DuckChessRules.capturesKing(move, position)
        val next = DuckChessFen.applied(move, position)

        // Poussée double : la case survolée devient prenable en passant.
        val piece = position.piece(move.from)
        enPassant = if (piece?.kind == Piece.Kind.pawn && abs(move.to.rank.value - move.from.rank.value) == 2) {
            Square("${move.from.file.letter}${(move.to.rank.value + move.from.rank.value) / 2}")
        } else {
            null
        }

        if (victim != null) {
            // Le roi est tombé : la partie s'arrête AVANT même la pose du
            // canard, qui n'aurait plus d'objet.
            ui = ui.copy(
                position = next, lastMove = move.from to move.to, selected = null,
                legalTargets = emptySet(), duckTargets = emptySet(),
                phase = DuckPhase.over, winner = victim.opposite, plies = ui.plies + 1,
                status = s(R.string.duck_king_taken, s(winnerLabel(victim.opposite))),
            )
            return
        }

        ui = ui.copy(
            position = next, lastMove = move.from to move.to, selected = null,
            legalTargets = emptySet(), phase = DuckPhase.placeDuck,
            duckTargets = DuckChessRules.duckTargets(next, ui.duck).toSet(),
            status = if (next.sideToMove == humanColor) s(R.string.duck_place) else s(R.string.duck_engine_places),
        )
    }

    /** La pose du canard : c'est ELLE qui rend la main à l'autre camp. */
    private fun placeDuck(square: Square) {
        val flipped = DuckChessFen.flippedSideToMove(ui.position)
        ui = ui.copy(
            duck = square, position = flipped, duckTargets = emptySet(),
            phase = DuckPhase.movePiece, plies = ui.plies + 1,
            status = if (flipped.sideToMove == humanColor) s(R.string.your_turn) else s(R.string.engine_thinking),
        )
        refreshLegal()
        if (flipped.sideToMove != humanColor) engineTurn()
    }

    /** Le tour de l'ordinateur, en deux temps lui aussi. */
    private fun engineTurn() {
        turn?.cancel()
        turn = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            val move = DuckChessEngine.chooseMove(getApplication(), ui.position, ui.duck, enPassant)
            if (move == null) {
                ui = ui.copy(thinking = false, phase = DuckPhase.over, status = s(R.string.game_over))
                return@launch
            }
            play(move)
            if (ui.winner != null) { ui = ui.copy(thinking = false); return@launch }

            val square = DuckChessEngine.chooseDuckSquare(getApplication(), ui.position, ui.duck)
            ui = ui.copy(thinking = false)
            if (square != null) placeDuck(square) else ui = ui.copy(status = s(R.string.game_over))
        }
    }

    private fun winnerLabel(color: Piece.Color) =
        if (color == Piece.Color.white) R.string.mate_white_wins else R.string.mate_black_wins

    override fun onCleared() {
        turn?.cancel()
        super.onCleared()
    }
}
