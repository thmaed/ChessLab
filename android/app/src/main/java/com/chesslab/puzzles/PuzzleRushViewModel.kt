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
import com.chesslab.dailysession.TrainingDays
import com.chesslab.settings.StatsStore
import com.chesslab.sound.Haptics
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class RushPhase { intro, countdown, playing, paused, finished }

/** Un puzzle manqué, pour le bilan : sa position et sa solution (SAN anglais, traduit à l'écran). */
data class RushMissed(val id: String, val fen: String, val sans: List<String>, val whiteToMove: Boolean)

data class PuzzleRushUi(
    val phase: RushPhase = RushPhase.intro,
    val countdown: Int = 3,
    val run: PuzzleRushRun = PuzzleRushRun(startRating = PuzzleRushRun.LOWEST_START),
    val position: Position = Position.standard,
    val orientation: Piece.Color = Piece.Color.white,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    /** La bonne réponse, fléchée un instant après un coup faux. */
    val hint: Pair<Square, Square>? = null,
    val pendingPromotion: Move? = null,
    val busy: Boolean = false,
    /** Le « +1 » : son numéro relance l'animation. */
    val flashId: Int = 0,
    val missed: List<RushMissed> = emptyList(),
    val previousBest: Int = 0,
    val isNewRecord: Boolean = false,
    /** Le lot se prépare (une passe sur la bibliothèque). */
    val preparing: Boolean = true,
    /** Rien à servir : la bibliothèque n'a pas pu être lue. */
    val unavailable: Boolean = false,
    val hasPuzzle: Boolean = false,
)

/**
 * L'écran « Contre la montre ». Pendant de `PuzzleRushViewModel.swift`.
 *
 * Ce que la série NE fait PAS (décision du 17/11/2026) : toucher la cote, la répétition espacée ou « Ratés ».
 * Seul le JOUR d'entraînement compte. Un mat est toujours juste, même hors de la solution enregistrée.
 */
class PuzzleRushViewModel(app: Application) : AndroidViewModel(app) {

    var ui by mutableStateOf(PuzzleRushUi())
        private set

    private var session: Long? = null
    private var pool = PuzzleRushPool(emptyList())
    private var board = Board()
    private var puzzle: Puzzle? = null
    private var step = 0
    private val used = HashSet<String>()
    private var ticker: Job? = null
    private var pending: Job? = null
    private var poolJob: Job? = null

    private val durationMs: Long get() = durationOverrideMs ?: PuzzleRushRun.DURATION_MS
    private fun now() = System.currentTimeMillis()

    /** Une NOUVELLE entrée dans l'écran (la route porte son numéro) : on repart de la règle. */
    fun open(session: Long) {
        if (this.session == session) return
        this.session = session
        reset()
    }

    private fun reset() {
        ticker?.cancel(); pending?.cancel(); poolJob?.cancel()
        used.clear()
        puzzle = null
        ui = PuzzleRushUi(preparing = true)
        poolJob = viewModelScope.launch {
            val app = getApplication<Application>()
            val rating = StatsStore.puzzleRating(app).rating
            val best = StatsStore.rushBest(app)
            val run = PuzzleRushRun.forPlayer(rating, durationMs)
            val loaded = withContext(Dispatchers.IO) {
                runCatching { PuzzleRushPool.load(app.assets, run.startRating) }.getOrDefault(PuzzleRushPool(emptyList()))
            }
            pool = loaded
            ui = ui.copy(run = run, previousBest = best, preparing = false, unavailable = loaded.size == 0)
        }
    }

    /** « Commencer » ou « Rejouer » : décompte, puis le premier puzzle. */
    fun begin() {
        if (ui.phase == RushPhase.finished) {
            // Rejouer : même lot de départ, série neuve.
            used.clear()
            ui = ui.copy(
                run = PuzzleRushRun.forPlayer(0.0, durationMs).copy(startRating = ui.run.startRating),
                missed = emptyList(), isNewRecord = false, hasPuzzle = false, hint = null,
            )
            viewModelScope.launch { ui = ui.copy(previousBest = StatsStore.rushBest(getApplication())) }
        }
        if (ui.phase != RushPhase.intro && ui.phase != RushPhase.finished) return
        if (ui.preparing || ui.unavailable) return
        ui = ui.copy(phase = RushPhase.countdown, countdown = 3)
        pending = viewModelScope.launch {
            for (value in listOf(2, 1)) {
                delay(800)
                ui = ui.copy(countdown = value)
            }
            delay(800)
            ui = ui.copy(phase = RushPhase.playing, run = ui.run.start(now()))
            loadNext()
            startTicker()
        }
    }

    /** L'app quitte le premier plan : temps arrêté, plateau voilé. */
    fun pause() {
        when (ui.phase) {
            RushPhase.playing -> {
                ticker?.cancel()
                ui = ui.copy(phase = RushPhase.paused, run = ui.run.pause(now()))
            }
            RushPhase.countdown -> {
                pending?.cancel()
                ui = ui.copy(phase = RushPhase.intro)
            }
            else -> Unit
        }
    }

    fun resume() {
        if (ui.phase != RushPhase.paused) return
        ui = ui.copy(phase = RushPhase.playing, run = ui.run.start(now()))
        startTicker()
    }

    fun remainingMs(): Long = ui.run.remainingMs(now())

    private fun startTicker() {
        ticker?.cancel()
        ticker = viewModelScope.launch {
            while (isActive) {
                delay(250)
                if (ui.phase == RushPhase.playing && ui.run.remainingMs(now()) <= 0L) finish()
            }
        }
    }

    private fun finish() {
        if (ui.phase != RushPhase.playing && ui.phase != RushPhase.paused) return
        ticker?.cancel(); pending?.cancel()
        val run = ui.run.pause(now())
        ui = ui.copy(run = run, busy = false, selected = null, legalTargets = emptySet(), pendingPromotion = null)
        viewModelScope.launch {
            val app = getApplication<Application>()
            val (previous, isNew) = StatsStore.submitRush(app, run.solved)
            if (run.solved + run.errors > 0) TrainingDays.markToday(app)
            ui = ui.copy(phase = RushPhase.finished, previousBest = previous, isNewRecord = isNew)
            Haptics.gameEnded()
        }
    }

    private fun loadNext() {
        val next = pool.next(ui.run.targetRating, used)
        val position = next?.let { Position.fromFen(it.fen) }
        if (next == null || position == null) {
            finish()
            return
        }
        used += next.id
        puzzle = next
        board = Board(position)
        step = 0
        ui = ui.copy(
            position = board.position, orientation = board.position.sideToMove,
            selected = null, legalTargets = emptySet(), lastMove = null, checkedKing = null,
            hint = null, busy = false, hasPuzzle = true,
        )
    }

    private val acceptsInput: Boolean
        get() = ui.phase == RushPhase.playing && !ui.busy && puzzle != null && ui.pendingPromotion == null

    fun onSquareTap(square: Square) {
        if (!acceptsInput) return
        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            attempt(selected, square)
            return
        }
        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == board.position.sideToMove) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun attempt(from: Square, to: Square) {
        val current = puzzle ?: return
        val expected = current.solution.getOrNull(step) ?: return
        val played = from.notation + to.notation
        val isExpected = expected.startsWith(played)
        if (!isExpected) {
            val promotes = board.position.piece(from)?.kind == Piece.Kind.pawn && to.rank.value in setOf(1, 8)
            if (!promotes && !PuzzleAnswer.deliversMate(board.position, from, to)) {
                wrongMove(expected)
                return
            }
        }
        var move = board.move(pieceAt = from, to = to) ?: return
        if (isExpected && expected.length == 5) {
            move = board.completePromotion(of = move, to = kindOf(expected[4]))
        } else if (board.state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        step++
        advance(move)
    }

    fun cancelPromotion() {
        if (ui.pendingPromotion == null) return
        board = Board(ui.position.copy())
        ui = ui.copy(pendingPromotion = null, selected = null, legalTargets = emptySet())
    }

    fun completePromotion(kind: Piece.Kind) {
        val pendingMove = ui.pendingPromotion ?: return
        val current = puzzle ?: return
        val move = board.completePromotion(of = pendingMove, to = kind)
        ui = ui.copy(pendingPromotion = null)
        val expected = current.solution.getOrNull(step) ?: return
        val played = pendingMove.start.notation + pendingMove.end.notation
        if (!expected.startsWith(played) && board.state !is Board.State.Checkmate) {
            board = Board(ui.position.copy())
            wrongMove(expected)
            return
        }
        step++
        advance(move)
    }

    private fun advance(move: Move) {
        val current = puzzle ?: return
        show(move)
        Haptics.move()
        if (step >= current.solution.size || board.state is Board.State.Checkmate) {
            solved()
            return
        }
        ui = ui.copy(busy = true)
        pending = viewModelScope.launch {
            delay(150)                      // la riposte, vite : la série se joue au rythme du chrono
            val lan = current.solution[step]
            var reply = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            if (reply != null && lan.length == 5) reply = board.completePromotion(of = reply, to = kindOf(lan[4]))
            step++
            if (reply != null) show(reply)
            ui = ui.copy(busy = false)
            if (step >= current.solution.size) solved()
        }
    }

    private fun solved() {
        ui = ui.copy(run = ui.run.recordSolved(puzzle?.rating), flashId = ui.flashId + 1, busy = true)
        pending = viewModelScope.launch {
            delay(350)
            loadNext()
        }
    }

    /**
     * Coup faux : une croix de plus, la bonne réponse fléchée, puis la suite (ou la fin). Comme les puzzles
     * Android, le coup faux n'est pas rejoué sur le plateau (iOS l'anime en rouge, aller-retour : écart déjà
     * propre à l'écran de puzzle, voir PARITE.md).
     */
    private fun wrongMove(expected: String) {
        val current = puzzle ?: return
        Haptics.illegal()
        val run = ui.run.recordError()
        ui = ui.copy(
            run = run, busy = true, selected = null, legalTargets = emptySet(),
            hint = if (expected.length >= 4) Square(expected.substring(0, 2)) to Square(expected.substring(2, 4)) else null,
            missed = ui.missed + RushMissed(
                current.id, current.fen, PuzzleRushSolution.sans(current),
                Position.fromFen(current.fen)?.sideToMove == Piece.Color.white,
            ),
        )
        pending = viewModelScope.launch {
            delay(900)
            if (run.errors >= PuzzleRushRun.MAX_ERRORS) finish() else loadNext()
        }
    }

    private fun show(move: Move) {
        val state = board.state
        val checked = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }
        ui = ui.copy(
            position = board.position, selected = null, legalTargets = emptySet(),
            lastMove = move.start to move.end, checkedKing = checked, hint = null,
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

    companion object {
        /** Crochet de test : raccourcit la série (pendant de `-puzzleRushSeconds`, iOS). */
        @Volatile var durationOverrideMs: Long? = null
    }
}
