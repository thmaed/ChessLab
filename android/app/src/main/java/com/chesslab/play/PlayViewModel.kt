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
import com.chesslab.library.Autosave
import com.chesslab.library.GameRecorder
import com.chesslab.library.LibraryDatabase
import com.chesslab.maia.MaiaOpponent
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.SoundPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.s

data class PlayUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    /** Les deux cases d'un coup soufflé par l'indice. */
    val hint: Pair<Square, Square>? = null,
    val status: String = "",
    val sanMoves: List<String> = emptyList(),
    val thinking: Boolean = false,
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    /** Le mot de la fin : « Échec et mat — vous gagnez », « Abandon »… */
    val outcome: String? = null,
    /** `null` = Stockfish brut. */
    val opponent: OpponentProfile? = null,
    val level: Double = 1500.0,
    val maiaAvailable: Boolean = true,
    /** Le camp de l'utilisateur : le plateau se retourne avec lui. */
    val userColor: Piece.Color = Piece.Color.white,
    val captured: CapturedMaterial = CapturedMaterial(),
    /** Millisecondes restantes, ou `null` sans pendule. */
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    /**
     * Le demi-coup CONSULTÉ. Égal à `sanMoves.size` sur la position vive ;
     * plus petit quand on remonte la partie avec les chevrons.
     */
    val displayedPly: Int = 0,
    val settings: PlayGameSettings = PlayGameSettings(),
    /** Faux tant que l'écran de configuration n'a pas rendu la main. */
    val started: Boolean = false,
) {
    val isReviewing: Boolean get() = displayedPly < sanMoves.size
    val totalPlies: Int get() = sanMoves.size
}

/**
 * Une partie contre l'ordinateur : un des neuf personnages, ou Stockfish.
 *
 * Pendant réduit de `PlayViewModel.swift`. Les personnages sont Maia-3 — un
 * réseau entraîné sur des parties HUMAINES — recoloré par un style borné ;
 * Stockfish reste disponible pour qui veut un mur.
 */
class PlayViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    /** Le camp de l'utilisateur : il change d'une partie à l'autre. */
    private var humanColor = Piece.Color.white

    /** L'historique des positions : Maia lit les huit dernières. */
    private val history = mutableListOf(Position.standard)

    /** La partie, pour la bibliothèque : le plateau ne connaît pas l'histoire. */
    private val recorder = GameRecorder()

    /** Les coups en UCI : ce qu'il faut pour REJOUER la partie à la reprise. */
    private val uciLog = mutableListOf<String>()

    private var maia: MaiaOpponent? = null

    /** Les coups joués, pour les prises et la consultation de la partie. */
    private val moveLog = mutableListOf<Move>()
    private var clock: GameClock? = null
    private var ticker: kotlinx.coroutines.Job? = null
    /** La recherche en cours : une nouvelle partie doit pouvoir l'annuler. */
    private var thinkingJob: kotlinx.coroutines.Job? = null

    var ui by mutableStateOf(PlayUiState(status = s(R.string.starting)))
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
        refresh(s(if (loaded == null) R.string.model_unavailable_stockfish else R.string.your_turn))
    }

    /**
     * Lance une partie avec les réglages de l'écran de configuration.
     *
     * C'est le SEUL point d'entrée d'une partie : la couleur, l'adversaire, le
     * niveau, la cadence et les aides sont décidés avant le premier coup, et
     * ne changent plus en cours de route.
     */
    fun start(settings: PlayGameSettings) {
        val color = when (settings.colorChoice) {
            PlayerColorChoice.white -> Piece.Color.white
            PlayerColorChoice.black -> Piece.Color.black
            PlayerColorChoice.random ->
                if (kotlin.random.Random.nextBoolean()) Piece.Color.white else Piece.Color.black
        }
        humanColor = color
        val profile = settings.opponentId?.let { OpponentGallery.byId(it) }
        clock = if (settings.timeControl.hasClock) GameClock(settings.timeControl) else null
        ui = ui.copy(
            settings = settings, opponent = profile, level = settings.level,
            userColor = color, started = true, outcome = null,
        )
        newGame()
    }

    fun chooseOpponent(profile: OpponentProfile?) {
        ui = ui.copy(opponent = profile, level = profile?.defaultLevel ?: 1500.0)
        newGame()
    }

    fun setLevel(value: Double) {
        val clamped = ui.opponent?.clampedLevel(value) ?: value.coerceIn(800.0, 3000.0)
        ui = ui.copy(level = clamped)
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || ui.pendingPromotion != null) return
        // En consultation d'un coup passé, le plateau est une PHOTO : y jouer
        // écrirait un coup dans une position qui n'est plus celle de la partie.
        if (ui.isReviewing) { reviewLive(); return }
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
        moveLog += move
        recorder.record(move)
        uciLog += move.lan
        clock?.stopAndIncrement(System.currentTimeMillis())
        autosave()
        refresh(null, move)
        if (ui.gameOver) { ticker?.cancel(); return }
        startClockForSideToMove()
        if (board.position.sideToMove != humanColor) askOpponent()
    }

    private fun askOpponent() {
        thinkingJob?.cancel()
        thinkingJob = viewModelScope.launch {
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

            if (lan == null || lan == "(none)") { refresh(s(R.string.rival_silent)); return@launch }

            val from = Square(lan.substring(0, 2))
            val to = Square(lan.substring(2, 4))
            var move = board.move(pieceAt = from, to = to)
            if (move == null) { refresh(s(R.string.move_refused, lan)); return@launch }

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
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            clock?.stopAndIncrement(System.currentTimeMillis())
            autosave()
            refresh(null, move)
            if (!ui.gameOver) startClockForSideToMove() else ticker?.cancel()
            }
        }

    /**
     * Garde la partie en cours. Une seule par mode : reprendre, c'est
     * reprendre LA partie interrompue, pas en choisir une dans une pile.
     */
    private fun autosave() = viewModelScope.launch(Dispatchers.IO) {
        val dao = LibraryDatabase.get(getApplication()).autosaves()
        if (ui.gameOver || uciLog.isEmpty()) { dao.clear(MODE); return@launch }
        dao.put(
            Autosave(
                mode = MODE,
                savedAt = System.currentTimeMillis(),
                moves = uciLog.joinToString(" "),
                opponentId = ui.opponent?.id,
                level = ui.level,
                label = s(R.string.autosave_label, ui.opponent?.firstName ?: s(R.string.stockfish), uciLog.size),
            )
        )
    }

    /** Reprend la partie interrompue, s'il y en a une. */
    fun resumeSaved() = viewModelScope.launch {
        val saved = withContext(Dispatchers.IO) {
            LibraryDatabase.get(getApplication<Application>()).autosaves().byMode(MODE)
        } ?: return@launch
        resume(saved)
    }

    /** Rejoue une partie sauvegardée, coup par coup. */
    fun resume(autosave: Autosave) {
        val profile = autosave.opponentId?.let { OpponentGallery.byId(it) }
        newGame()
        ui = ui.copy(opponent = profile, level = autosave.level)
        for (lan in autosave.moveList) {
            var move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
                ?: break
            if (lan.length == 5) {
                move = board.completePromotion(of = move, to = kindOf(lan[4]))
            }
            history += board.position.copy()
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            ui = ui.copy(sanMoves = ui.sanMoves + move.san, lastMove = move.start to move.end)
        }
        refresh(s(R.string.game_resumed))
        if (!ui.gameOver && board.position.sideToMove != humanColor) askOpponent()
    }

    private fun kindOf(c: Char): Piece.Kind = when (c) {
        'q' -> Piece.Kind.queen
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        else -> Piece.Kind.knight
    }

    private fun thinkingLabel(profile: OpponentProfile?): String =
        if (profile != null) s(R.string.someone_thinking, profile.firstName) else s(R.string.engine_thinking)

    private fun refresh(status: String?, move: Move? = null) {
        val position = board.position
        val state = board.state

        val checkedKing = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }

        // le son suit le COUP, pas l'état : une prise reste une prise même
        // quand elle donne échec — c'est l'échec qui l'emporte
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        move?.let {
            SoundPlayer.forMove(
                isCapture = it.result is Move.Result.Capture,
                isCastle = it.result is Move.Result.Castle,
                isCheck = state is Board.State.Check || state is Board.State.Checkmate,
            )
        }

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        if (over && !ui.gameOver) {
            ticker?.cancel()
            viewModelScope.launch(Dispatchers.IO) {
                LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
            }
            recorder.save(
                getApplication(),
                white = if (humanColor == Piece.Color.white) s(R.string.you) else opponentName(),
                black = if (humanColor == Piece.Color.white) opponentName() else s(R.string.you),
                source = "engine",
                state = state,
            )
        }
        val text = status ?: when (state) {
            is Board.State.Checkmate ->
                s(if (state.color == humanColor) R.string.checkmate_you_lose else R.string.checkmate_you_win)
            is Board.State.Draw -> s(R.string.draw_reason, drawLabel(state.reason))
            is Board.State.Check -> s(R.string.check)
            else -> if (position.sideToMove == humanColor) s(R.string.your_turn) else thinkingLabel(ui.opponent)
        }

        val sans = if (move != null) ui.sanMoves + move.san else ui.sanMoves
        ui = ui.copy(
            position = position,
            selected = null,
            legalTargets = emptySet(),
            hint = null,
            lastMove = move?.let { it.start to it.end } ?: ui.lastMove,
            checkedKing = checkedKing,
            status = text,
            sanMoves = sans,
            displayedPly = sans.size,
            captured = CapturedMaterial.from(moveLog, board),
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            gameOver = over,
            outcome = if (over) text else ui.outcome,
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

    companion object { private const val MODE = "engine" }

    fun newGame() {
        // La recherche en cours vaut pour la position d'AVANT : la laisser
        // vivre, c'est risquer de la voir jouer sur le plateau neuf.
        thinkingJob?.cancel()
        ticker?.cancel()
        board = Board()
        history.clear()
        history += Position.standard
        recorder.reset()
        uciLog.clear()
        moveLog.clear()
        clock = ui.settings.timeControl.takeIf { it.hasClock }?.let { GameClock(it) }
        ui = ui.copy(
            position = Position.standard,
            selected = null, legalTargets = emptySet(), lastMove = null, checkedKing = null,
            hint = null, sanMoves = emptyList(), gameOver = false, outcome = null,
            pendingPromotion = null, thinking = false, displayedPly = 0,
            captured = CapturedMaterial(),
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            status = if (humanColor == Piece.Color.white) s(R.string.your_turn) else thinkingLabel(ui.opponent),
        )
        startClockForSideToMove()
        // L'utilisateur peut avoir les Noirs : c'est alors au moteur d'ouvrir.
        if (board.position.sideToMove != humanColor) askOpponent()
    }

    // MARK: Pendule

    private fun startClockForSideToMove() {
        val c = clock ?: return
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
                if (flagged != null) { flag(flagged); return@launch }
            }
        }
    }

    /** Le drapeau tombe : la partie s'arrête là, et le score le dit. */
    private fun flag(loser: Piece.Color) {
        ticker?.cancel()
        thinkingJob?.cancel()
        finish(
            s(if (loser == humanColor) R.string.outcome_flag_you else R.string.outcome_flag_opponent),
            if (loser == Piece.Color.white) "0-1" else "1-0",
        )
    }

    // MARK: Fin de partie

    /** Termine la partie, l'enregistre, et arrête tout ce qui tourne. */
    private fun finish(message: String, result: String) {
        if (ui.gameOver) return
        ticker?.cancel()
        thinkingJob?.cancel()
        viewModelScope.launch(Dispatchers.IO) {
            LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
        }
        recorder.save(
            getApplication(),
            white = if (humanColor == Piece.Color.white) s(R.string.you) else opponentName(),
            black = if (humanColor == Piece.Color.white) opponentName() else s(R.string.you),
            source = "engine",
            state = board.state,
            forcedResult = result,
        )
        ui = ui.copy(gameOver = true, thinking = false, outcome = message, status = message)
    }

    private fun opponentName(): String =
        ui.opponent?.displayName(getApplication()) ?: s(R.string.stockfish)

    /** L'utilisateur abandonne. */
    fun resign() {
        finish(
            s(R.string.outcome_resigned),
            if (humanColor == Piece.Color.white) "0-1" else "1-0",
        )
    }

    /**
     * L'utilisateur propose nulle. L'ordinateur accepte s'il n'est pas mieux :
     * il n'a pas d'amour-propre, mais il ne concède pas une partie gagnée.
     */
    fun offerDraw() = viewModelScope.launch {
        if (ui.gameOver) return@launch
        val advantage = ui.captured.advantage(humanColor.opposite)
        if (advantage >= 2) {
            ui = ui.copy(status = s(R.string.outcome_draw_refused))
        } else {
            finish(s(R.string.outcome_draw_agreed), "1/2-1/2")
        }
    }

    // MARK: Indice et consultation

    /** Montre — ou cache — le meilleur coup, si les aides sont permises. */
    fun toggleHint() = viewModelScope.launch {
        if (!ui.settings.hintsEnabled || ui.gameOver) return@launch
        if (ui.hint != null) { ui = ui.copy(hint = null); return@launch }
        val best = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { e ->
                e.send("position fen ${board.position.fen}")
                e.search("go movetime 600", timeoutMs = 10_000)
            }
        }?.split(" ")?.getOrNull(1) ?: return@launch
        if (best.length < 4) return@launch
        ui = ui.copy(hint = Square(best.substring(0, 2)) to Square(best.substring(2, 4)))
    }

    /** Remonte d'un demi-coup dans la partie jouée. */
    fun reviewPrevious() = review(ui.displayedPly - 1)

    fun reviewNext() = review(ui.displayedPly + 1)

    /**
     * Affiche la position après [ply] demi-coups, SANS toucher à la partie :
     * le plateau réel reste où il est, seule la vue recule.
     */
    private fun review(ply: Int) {
        val target = ply.coerceIn(0, ui.sanMoves.size)
        if (target == ui.displayedPly) return
        val position = history.getOrNull(target) ?: return
        val move = moveLog.getOrNull(target - 1)
        ui = ui.copy(
            displayedPly = target,
            position = position,
            selected = null, legalTargets = emptySet(), hint = null,
            lastMove = move?.let { it.start to it.end },
        )
    }

    /** Revient à la position vive. */
    fun reviewLive() = review(ui.sanMoves.size)
}
