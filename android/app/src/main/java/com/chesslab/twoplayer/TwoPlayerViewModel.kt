package com.chesslab.twoplayer

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.AndroidViewModel
import android.app.Application
import com.chesslab.library.GameRecorder
import com.chesslab.library.LibraryDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import androidx.lifecycle.viewModelScope
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.SoundPlayer
import chesskit.Board
import chesskit.Move
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.ui.s

data class TwoPlayerUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val sanMoves: List<String> = emptyList(),
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    val orientation: Piece.Color = Piece.Color.white,
    val settings: TwoPlayerSettings = TwoPlayerSettings(),
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    val started: Boolean = false,
    /** Les prises de chaque camp, pour les lignes joueurs. */
    val captured: com.chesslab.play.CapturedMaterial = com.chesslab.play.CapturedMaterial(),
)

/**
 * Deux joueurs sur le même appareil. Pendant réduit de
 * `TwoPlayerViewModel.swift`.
 *
 * Le plateau se retourne à chaque coup en mode « face à face » : c'est ce qui
 * rend le mode jouable à deux autour d'un téléphone. Trois présentations, comme
 * iOS — voir [TwoPlayerSettings.RotationMode].
 */
class TwoPlayerViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val recorder = GameRecorder()

    /**
     * La position d'où la partie part : standard, sauf quand « Changer de
     * mode » a envoyé ici la position d'un autre écran.
     */
    private var startPosition: Position = Position.standard

    private companion object {
        /** La clé d'autosauvegarde du mode, distincte de celle de « Jouer ». */
        const val MODE = "twoPlayer"
    }

    /** La pendule, quand la cadence en demande une. */
    private var clock: com.chesslab.play.GameClock? = null
    private var ticker: kotlinx.coroutines.Job? = null

    /** Les coups en UCI : ce qu'il faut pour REJOUER la partie à la reprise. */
    private val uciLog = mutableListOf<String>()

    /** Les coups joués : ce qu'il faut pour compter les prises. */
    private val moveLog = mutableListOf<Move>()

    var ui by mutableStateOf(
        TwoPlayerUiState(
            settings = TwoPlayerSettings(
                rotation = if (SettingsStore.state.value.autoFlipTwoPlayer)
                    TwoPlayerSettings.RotationMode.faceToFace
                else TwoPlayerSettings.RotationMode.fixed,
            ),
            status = s(R.string.white_to_move),
        )
    )
        private set

    /**
     * Reprend la partie à la position qu'un autre mode vient d'envoyer.
     * Sans effet si c'est déjà celle qui est sur le plateau : l'écran est
     * recomposé souvent, et repartir de zéro à chaque fois effacerait les
     * coups qu'on vient de jouer.
     */
    /** Démarre une partie avec les réglages de l'écran de configuration. */
    fun start(settings: TwoPlayerSettings) {
        ui = ui.copy(settings = settings, started = true)
        startPosition = settings.startFen?.let { Position.fromFen(it) } ?: Position.standard
        newGame()
    }

    /** Reprend la partie interrompue. */
    fun resumeSaved() = viewModelScope.launch {
        val saved = withContext(Dispatchers.IO) {
            LibraryDatabase.get(getApplication<Application>()).autosaves().byMode(MODE)
        } ?: return@launch
        ui = ui.copy(started = true)
        startPosition = Position.standard
        newGame()
        for (lan in saved.moveList) {
            var move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: break
            if (lan.length == 5) move = board.completePromotion(move, kindOf(lan[4]))
            refresh(move)
        }
    }

    /**
     * La pendule du camp au trait. Elle s'arrête d'elle-même quand le drapeau
     * tombe, et la partie s'arrête avec.
     */
    private fun startClockForSideToMove() {
        val c = clock ?: return
        if (ui.gameOver) return
        c.start(board.position.sideToMove, System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch {
            while (true) {
                kotlinx.coroutines.delay(100)
                val now = System.currentTimeMillis()
                c.tick(now)
                ui = ui.copy(
                    whiteClockMs = c.remaining(Piece.Color.white),
                    blackClockMs = c.remaining(Piece.Color.black),
                )
                val flagged = Piece.Color.entries.firstOrNull { c.flagged(it) }
                if (flagged != null) {
                    ticker?.cancel()
                    val nom = if (flagged == Piece.Color.white) whiteName() else blackName()
                    ui = ui.copy(
                        gameOver = true,
                        status = s(R.string.two_flag_fell, nom),
                    )
                    return@launch
                }
            }
        }
    }

    /** Le nom d'un camp, ou sa couleur si personne ne s'est nommé. */
    private fun whiteName(): String = ui.settings.whiteName.ifBlank { s(R.string.color_white) }
    private fun blackName(): String = ui.settings.blackName.ifBlank { s(R.string.color_black) }

    /**
     * La partie en cours est gardée pour être REPRISE. Une partie à deux
     * s'interrompt comme une autre — on pose le téléphone — et rien ne la
     * rattrapait jusqu'ici.
     */
    private fun autosave() = viewModelScope.launch(Dispatchers.IO) {
        val dao = LibraryDatabase.get(getApplication()).autosaves()
        if (ui.gameOver || uciLog.isEmpty()) { dao.clear(MODE); return@launch }
        dao.put(
            com.chesslab.library.Autosave(
                mode = MODE,
                moves = uciLog.joinToString(" "),
                opponentId = null,
                level = 0.0,
                label = s(R.string.autosave_two_label, whiteName(), blackName(), uciLog.size),
                savedAt = System.currentTimeMillis(),
            )
        )
    }

    private fun kindOf(c: Char): Piece.Kind = when (c) {
        'q' -> Piece.Kind.queen
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        else -> Piece.Kind.knight
    }

    fun startFrom(fen: String) {
        val position = Position.fromFen(fen) ?: return
        if (position.fen == startPosition.fen && ui.sanMoves.isEmpty()) return
        startPosition = position
        newGame()
    }

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
        val next = if (ui.settings.rotation == TwoPlayerSettings.RotationMode.faceToFace)
            TwoPlayerSettings.RotationMode.fixed else TwoPlayerSettings.RotationMode.faceToFace
        ui = ui.copy(settings = ui.settings.copy(rotation = next))
    }

    fun flip() {
        ui = ui.copy(orientation = ui.orientation.opposite)
    }

    fun newGame() {
        ticker?.cancel()
        clock = ui.settings.timeControl.takeIf { it.hasClock }
            ?.let { com.chesslab.play.GameClock(it) }
        uciLog.clear()
        board = Board(startPosition)
        val custom = startPosition.fen.takeIf { it != Position.standard.fen }
        recorder.reset(startPosition, custom)
        moveLog.clear()
        ui = TwoPlayerUiState(
            settings = ui.settings,
            started = true,
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            position = startPosition,
            status = s(
                if (startPosition.sideToMove == Piece.Color.white) R.string.white_to_move
                else R.string.black_to_move
            ),
        )
        // La pendule part avec la partie, comme une vraie : on l'a enclenchée
        // en s'asseyant, pas au premier coup.
        startClockForSideToMove()
    }

    private fun refresh(move: Move) {
        uciLog += move.lan
        clock?.stopAndIncrement(System.currentTimeMillis())
        moveLog += move
        recorder.record(move)
        val position = board.position
        val state = board.state

        // le son suit le COUP, pas l'état : une prise reste une prise même
        // quand elle donne échec — c'est l'échec qui l'emporte
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        val isCapture = move.result is Move.Result.Capture
        val isCastle = move.result is Move.Result.Castle
        val isCheck = state is Board.State.Check || state is Board.State.Checkmate
        SoundPlayer.forMove(isCapture, isCastle, isCheck)
        com.chesslab.sound.Haptics.forMove(isCapture, isCastle, isCheck)

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        if (over && !ui.gameOver) {
            recorder.save(
                getApplication(), white = s(R.string.color_white), black = s(R.string.color_black),
                source = "twoPlayer", state = state,
            )
        }

        val status = when (state) {
            is Board.State.Checkmate ->
                s(R.string.checkmate_side, s(if (state.color == Piece.Color.white) R.string.mate_black_wins else R.string.mate_white_wins))
            is Board.State.Draw -> s(R.string.draw_reason, drawLabel(state.reason))
            is Board.State.Check ->
                s(R.string.check_side, s(if (position.sideToMove == Piece.Color.white) R.string.check_white else R.string.check_black))
            else ->
                s(if (position.sideToMove == Piece.Color.white) R.string.white_to_move else R.string.black_to_move)
        }

        val checkedKing = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }

        startClockForSideToMove()
        autosave()
        ui = ui.copy(
            position = position,
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            selected = null,
            legalTargets = emptySet(),
            lastMove = move.start to move.end,
            checkedKing = checkedKing,
            status = status,
            captured = com.chesslab.play.CapturedMaterial.from(moveLog, board),
            sanMoves = ui.sanMoves + move.san,
            gameOver = over,
            orientation = if (ui.settings.rotation == TwoPlayerSettings.RotationMode.faceToFace && !over)
                position.sideToMove else ui.orientation,
        )
    }

    private fun kingSquare(color: Piece.Color): Square? =
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    private fun drawLabel(reason: Board.State.DrawReason): String = when (reason) {
        Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
        Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
        Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
        Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
        Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
    }
}
