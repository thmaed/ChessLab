package com.chesslab.variants

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Board
import chesskit.FenParser
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.engine.EngineService
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class StolenMoveUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val sanMoves: List<String> = emptyList(),
    val status: String = "",
    /** Les jetons en stock, par camp — jamais plus d'un (règle 2). */
    val tokens: Map<Piece.Color, Int> = mapOf(Piece.Color.white to 0, Piece.Color.black to 0),
    /** Le camp qui doit encore jouer son SECOND coup, s'il y en a un. */
    val awaitingSecondMoveBy: Piece.Color? = null,
    /** Le joueur a annoncé qu'il dépensait son jeton : son prochain coup ouvre un tour double. */
    val wantsToSpend: Boolean = false,
    val tokenInterval: Int = StolenMoveRules.defaultTokenInterval,
    val thinking: Boolean = false,
    val outcome: String? = null,
) {
    /** Celui à qui appartient VRAIMENT le trait : le tour double le garde. */
    val mover: Piece.Color get() = awaitingSecondMoveBy ?: position.sideToMove
}

/**
 * Le Coup Volé. Pendant réduit de `StolenMovePlayViewModel.swift`.
 *
 * `chesskit` arbitre chaque coup, Stockfish joue les Noirs, et le TOUR DOUBLE
 * est tenu ici, par [StolenMoveRules] : aucun moteur ne sait l'exprimer.
 */
class StolenMoveViewModel(app: Application) : AndroidViewModel(app) {

    private val humanColor = Piece.Color.white
    private val engineColor = Piece.Color.black

    private var board = Board()
    private var movesPlayed = HashMap<Piece.Color, Int>()
    /**
     * La prise en passant ouverte AVANT le premier coup d'un tour double :
     * on la rend au second coup (règle 5).
     */
    private var enPassantAtTurnStart: String? = null
    private var turn: Job? = null

    var ui by mutableStateOf(StolenMoveUiState())
        private set

    init { newGame() }

    fun newGame() {
        turn?.cancel()
        board = Board()
        movesPlayed = HashMap()
        enPassantAtTurnStart = null
        ui = StolenMoveUiState(status = s(R.string.your_turn), tokenInterval = ui.tokenInterval)
    }

    /** L'intervalle se règle entre deux parties : le changer en cours fausserait le compte. */
    fun setInterval(interval: Int) {
        if (interval !in StolenMoveRules.tokenIntervalRange) return
        ui = ui.copy(tokenInterval = interval)
        newGame()
    }

    /**
     * Le plateau sur lequel on JOUE : celui de la partie, sauf pendant un tour
     * double où le trait doit revenir à celui qui n'a pas fini.
     */
    private fun interactionBoard(): Board {
        val awaiting = ui.awaitingSecondMoveBy ?: return board
        val fen = StolenMoveRules.fenForSecondMove(board.position.fen, awaiting, enPassantAtTurnStart)
            ?: return board
        val position = FenParser.parse(fen) ?: return board
        return Board(position)
    }

    /** Le joueur annonce qu'il dépense son jeton : son prochain coup en ouvrira deux. */
    fun spendToken() {
        if (!canSpend()) return
        ui = ui.copy(wantsToSpend = true, status = s(R.string.stolen_spending))
    }

    private fun canSpend(): Boolean =
        ui.outcome == null && !ui.thinking && ui.mover == humanColor &&
            ui.awaitingSecondMoveBy == null &&
            StolenMoveRules.canSpend(
                hasToken = (ui.tokens[humanColor] ?: 0) > 0,
                inCheck = isInCheck(interactionBoard(), humanColor),
            )

    val canSpendNow: Boolean get() = canSpend()

    fun onSquareTap(square: Square) {
        if (ui.outcome != null || ui.thinking || ui.mover != humanColor) return
        val playable = interactionBoard()

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            commit(selected, square)
            if (ui.outcome == null && ui.mover == engineColor) engineTurn()
            return
        }
        val piece = playable.position.piece(square)
        ui = if (piece != null && piece.color == humanColor) {
            ui.copy(selected = square, legalTargets = playable.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    /** Joue un coup et fait avancer le tour. Rend `false` si le coup est refusé. */
    private fun commit(from: Square, to: Square): Boolean {
        val mover = ui.mover
        val second = ui.awaitingSecondMoveBy != null
        val working = if (second) interactionBoard() else board
        val beforeFen = board.position.fen

        // Le jeton se dépense au PREMIER coup, et seulement hors échec.
        val spends = !second && ui.wantsToSpend &&
            StolenMoveRules.canSpend((ui.tokens[mover] ?: 0) > 0, isInCheck(working, mover))

        var move: Move = working.move(from, to) ?: run {
            ui = ui.copy(selected = null, legalTargets = emptySet(), wantsToSpend = ui.wantsToSpend)
            return false
        }
        if (working.state is Board.State.Promotion) {
            move = working.completePromotion(move, Piece.Kind.queen)
        }

        val count = (movesPlayed[mover] ?: 0) + 1
        movesPlayed[mover] = count
        val tokens = HashMap(ui.tokens)
        if (spends) tokens[mover] = 0
        // Règle 2 : un nouveau jeton EFFACE l'ancien s'il traîne encore.
        if (StolenMoveRules.earnsToken(count, ui.tokenInterval)) tokens[mover] = 1

        val gaveCheck = working.state is Board.State.Check
        val awaiting = when {
            second -> null                                   // le second coup finit toujours le tour
            spends && StolenMoveRules.turnContinues(gaveCheck) -> mover
            else -> null
        }
        enPassantAtTurnStart = if (awaiting != null) StolenMoveRules.enPassantTarget(beforeFen) else null

        board = working
        publish(
            tokens = tokens, awaiting = awaiting, lastMove = from to to,
            san = ui.sanMoves + move.san,
        )
        return true
    }

    private fun publish(
        tokens: Map<Piece.Color, Int>,
        awaiting: Piece.Color?,
        lastMove: Pair<Square, Square>?,
        san: List<String>,
    ) {
        val position = board.position
        val state = board.state
        val outcome = when (state) {
            is Board.State.Checkmate -> s(
                if (state.color == Piece.Color.black) R.string.mate_white_wins else R.string.mate_black_wins
            )
            is Board.State.Draw -> s(R.string.game_over)
            else -> null
        }
        val mover = awaiting ?: position.sideToMove
        ui = ui.copy(
            position = position, selected = null, legalTargets = emptySet(),
            lastMove = lastMove, sanMoves = san, tokens = tokens,
            awaitingSecondMoveBy = awaiting, wantsToSpend = false,
            checkedKing = (state as? Board.State.Check)?.let { kingSquare(position, it.color) },
            outcome = outcome,
            status = when {
                outcome != null -> outcome
                awaiting != null -> s(R.string.stolen_second_move)
                mover == humanColor -> s(R.string.your_turn)
                else -> s(R.string.engine_thinking)
            },
        )
    }

    /**
     * L'ordinateur joue un tour COMPLET : un coup, et un second s'il détient
     * un jeton hors échec. Heuristique volontairement simple — il dépense
     * TOUJOURS un jeton disponible plutôt que de le garder : non dépensé, il
     * sera de toute façon perdu au prochain (règle 2).
     */
    private fun engineTurn() {
        turn?.cancel()
        turn = viewModelScope.launch {
            if ((ui.tokens[engineColor] ?: 0) > 0 && !isInCheck(board, engineColor)) {
                ui = ui.copy(wantsToSpend = true)
            }
            if (!engineMove()) return@launch
            // Le premier coup n'a pas mis échec : le second suit, sans que
            // l'utilisateur n'ait rien à faire entre les deux.
            if (ui.outcome == null && ui.mover == engineColor) engineMove()
        }
    }

    private suspend fun engineMove(): Boolean {
        if (ui.outcome != null || ui.mover != engineColor) return false
        ui = ui.copy(thinking = true, status = s(R.string.engine_thinking))
        val fen = interactionBoard().position.fen
        val best = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { engine ->
                engine.send("position fen $fen")
                engine.search("go movetime 400", timeoutMs = 30_000)
            }
        }?.split(" ")?.getOrNull(1)
        ui = ui.copy(thinking = false)
        if (best == null || best.length < 4 || best == "(none)") {
            ui = ui.copy(status = s(R.string.engine_silent))
            return false
        }
        return commit(Square(best.substring(0, 2)), Square(best.substring(2, 4)))
    }

    private fun isInCheck(board: Board, color: Piece.Color): Boolean =
        (board.state as? Board.State.Check)?.color == color

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    override fun onCleared() {
        turn?.cancel()
        super.onCleared()
    }
}
