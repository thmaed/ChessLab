package com.chesslab.twoplayer

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
import com.chesslab.R
import com.chesslab.library.Autosave
import com.chesslab.library.GameRecorder
import com.chesslab.library.LibraryDatabase
import com.chesslab.play.CapturedMaterial
import com.chesslab.play.GameClock
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.Haptics
import com.chesslab.sound.SoundPlayer
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class TwoPlayerUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val sanMoves: List<String> = emptyList(),
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    /** Le mot de la fin, avec les NOMS : « Camille a gagné (échec et mat) ». */
    val outcome: String? = null,
    /** Qui a gagné, `null` pour une nulle — ce qui décide des confettis. */
    val winner: Piece.Color? = null,
    val orientation: Piece.Color = Piece.Color.white,
    val settings: TwoPlayerSettings = TwoPlayerSettings(),
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    val started: Boolean = false,
    /** Les prises de chaque camp, pour les lignes joueurs. */
    val captured: CapturedMaterial = CapturedMaterial(),
    /**
     * Le demi-coup CONSULTÉ. Égal à `sanMoves.size` sur la position vive ;
     * plus petit quand on remonte la partie avec la barre de transport.
     */
    val displayedPly: Int = 0,
    /** Les coups écartés par « Reprendre ici », le temps de pouvoir les rendre. */
    val resumeUndo: ResumeUndo? = null,
    /** Ce que le lecteur d'écran doit dire : le coup joué, puis le résultat. */
    val announcement: com.chesslab.ui.Announcement? = null,
) {
    val isReviewing: Boolean get() = displayedPly < sanMoves.size
    val totalPlies: Int get() = sanMoves.size

    /**
     * Peut-on repartir du coup consulté ? Jamais avec une pendule — on ne
     * rend pas du temps déjà écoulé, et iOS a tranché pareil.
     */
    val canResumeFromReview: Boolean
        get() = isReviewing && !settings.timeControl.hasClock && !gameOver

    /** Une partie sans coup n'a rien à exporter ; la POSITION, elle, toujours. */
    val hasGameToExport: Boolean get() = sanMoves.isNotEmpty()
}

/** Ce que « Reprendre ici » a écarté, et d'où : de quoi le rendre. */
data class ResumeUndo(val discarded: List<String>, val atPly: Int)

/**
 * Deux joueurs sur le même appareil. Pendant de `TwoPlayerViewModel.swift`.
 *
 * Aucune dépendance moteur : ni indice, ni barre d'éval, ni alerte de gaffe —
 * c'est l'esprit « feuille de partie du club », fidèle à ce qui a été
 * réellement joué. Le plateau se retourne à chaque coup en mode « face à
 * face » : c'est ce qui rend le mode jouable à deux autour d'un téléphone.
 * Trois présentations, comme iOS — voir [TwoPlayerSettings.RotationMode].
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

        /** Le délai pendant lequel « Reprendre ici » reste défaisable. */
        const val RESUME_UNDO_MS = 8_000L
    }

    /** La pendule, quand la cadence en demande une. */
    private var clock: GameClock? = null
    private var ticker: Job? = null
    private var undoJob: Job? = null

    /** Les coups en UCI : ce qu'il faut pour REJOUER la partie à la reprise. */
    private val uciLog = mutableListOf<String>()

    /** Les coups joués : ce qu'il faut pour compter les prises. */
    private val moveLog = mutableListOf<Move>()

    /** Les positions successives : la consultation y puise sans rejouer. */
    private val history = mutableListOf<Position>()

    /** Vrai quand le dernier rejeu a buté sur un coup injouable. */
    private var failedResume = false

    /** Le numéro de la prochaine annonce — voir [com.chesslab.ui.Announcement]. */
    private var announcementId = 0

    private fun announce(text: String) {
        announcementId += 1
        ui = ui.copy(announcement = com.chesslab.ui.Announcement(announcementId, text))
    }

    var ui by mutableStateOf(
        TwoPlayerUiState(
            settings = TwoPlayerSettings(
                rotation = if (SettingsStore.state.value.autoFlipTwoPlayer)
                    TwoPlayerSettings.RotationMode.faceToFace
                else TwoPlayerSettings.RotationMode.fixed,
            ),
        )
    )
        private set

    // MARK: Démarrage

    /** Démarre une partie avec les réglages de l'écran de configuration. */
    fun start(settings: TwoPlayerSettings) {
        ui = ui.copy(settings = settings, started = true)
        startPosition = settings.startingPosition
        newGame()
    }

    /**
     * Reprend la partie interrompue — avec ses NOMS, sa position de départ,
     * sa cadence et ses deux pendules. Reprendre une partie de club à temps
     * plein sous « Blancs — Noirs » n'était pas une reprise.
     */
    fun resumeSaved() = viewModelScope.launch {
        val saved = withContext(Dispatchers.IO) {
            LibraryDatabase.get(getApplication<Application>()).autosaves().byMode(MODE)
        } ?: return@launch
        val settings = saved.settingsJson?.let { TwoPlayerSettingsStore.decode(it) }
            ?: ui.settings
        ui = ui.copy(
            settings = settings.copy(startFen = saved.startFen ?: settings.startFen),
            started = true,
        )
        startPosition = ui.settings.startingPosition
        newGame()
        clock?.restore(saved.whiteMs, saved.blackMs)
        rebuild(saved.moveList)
    }

    /**
     * Reprend la partie à la position qu'un autre mode vient d'envoyer.
     * Sans effet si c'est déjà celle qui est sur le plateau : l'écran est
     * recomposé souvent, et repartir de zéro à chaque fois effacerait les
     * coups qu'on vient de jouer.
     */
    fun startFrom(fen: String) {
        val position = Position.fromFen(fen) ?: return
        if (position.fen == startPosition.fen && ui.sanMoves.isEmpty()) return
        startPosition = position
        ui = ui.copy(settings = ui.settings.copy(startFen = fen), started = true)
        newGame()
    }

    fun newGame() {
        ticker?.cancel()
        undoJob?.cancel()
        clock = ui.settings.timeControl.takeIf { it.hasClock }?.let { GameClock(it) }
        uciLog.clear()
        moveLog.clear()
        history.clear()
        board = Board(startPosition)
        history += startPosition
        val custom = startPosition.fen.takeIf { it != Position.standard.fen }
        recorder.reset(startPosition, custom)
        ui = TwoPlayerUiState(
            settings = ui.settings,
            started = true,
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            position = startPosition,
            orientation = if (ui.settings.rotation == TwoPlayerSettings.RotationMode.faceToFace)
                startPosition.sideToMove else Piece.Color.white,
        )
        // La pendule part avec la partie, comme une vraie : on l'a enclenchée
        // en s'asseyant, pas au premier coup.
        startClockForSideToMove()
    }

    /**
     * La revanche : les mêmes réglages, les deux joueurs échangent les
     * couleurs — et on repart de la position STANDARD, pas de celle qu'un
     * autre mode avait imposée à la partie précédente.
     */
    fun rematchSettings(): TwoPlayerSettings = ui.settings.copy(
        whiteName = ui.settings.blackName,
        blackName = ui.settings.whiteName,
        startFen = null,
    )

    // MARK: Pendule

    /**
     * La pendule du camp au trait. Elle s'arrête d'elle-même quand le drapeau
     * tombe, et la partie s'arrête avec.
     */
    private fun startClockForSideToMove() {
        val c = clock ?: return
        if (ui.gameOver) return
        c.start(board.position.sideToMove, System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch { tickLoop(c) }
    }

    private suspend fun tickLoop(c: GameClock) {
        while (true) {
            delay(100)
            val now = System.currentTimeMillis()
            c.tick(now)
            ui = ui.copy(
                whiteClockMs = c.remaining(Piece.Color.white),
                blackClockMs = c.remaining(Piece.Color.black),
            )
            val flagged = Piece.Color.entries.firstOrNull { c.flagged(it) }
            if (flagged != null) { flag(flagged); return }
        }
    }

    /**
     * Le drapeau tombe. Il ne se contentait de rien enregistrer : la partie
     * disparaissait purement et simplement de la bibliothèque.
     */
    private fun flag(loser: Piece.Color) {
        ticker?.cancel()
        finish(loser.opposite, s(R.string.reason_timeout))
    }

    /**
     * L'écran disparaît, ou l'app passe en arrière-plan : la pendule
     * s'arrête. Sans cela le drapeau tombait derrière un autre écran — celui
     * de l'analyse ouvert depuis le menu d'export, par exemple — sans que
     * personne le voie.
     */
    fun pauseForBackground() {
        if (ui.gameOver) return
        clock?.pause(System.currentTimeMillis())
        ticker?.cancel()
        ui = ui.copy(
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
        )
    }

    /** Le retour sur l'écran : la pendule repart où elle en était. */
    fun resumeFromBackground() {
        if (ui.gameOver || !ui.started) return
        val c = clock ?: return
        c.resume(System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch { tickLoop(c) }
    }

    // MARK: Les noms

    /** Le nom d'un camp, ou sa couleur si personne ne s'est nommé. */
    fun whiteName(): String = ui.settings.whiteName.ifBlank { s(R.string.color_white) }
    fun blackName(): String = ui.settings.blackName.ifBlank { s(R.string.color_black) }

    private fun nameOf(color: Piece.Color): String =
        if (color == Piece.Color.white) whiteName() else blackName()

    // MARK: Autosauvegarde

    /**
     * La partie en cours est gardée pour être REPRISE, avec tout ce qu'il
     * faut pour la retrouver telle quelle : les réglages (les noms !), la
     * position de départ, la cadence et les deux temps restants.
     */
    private fun autosave() = viewModelScope.launch(Dispatchers.IO) {
        val dao = LibraryDatabase.get(getApplication()).autosaves()
        if (ui.gameOver || uciLog.isEmpty()) { dao.clear(MODE); return@launch }
        dao.put(
            Autosave(
                mode = MODE,
                moves = uciLog.joinToString(" "),
                opponentId = null,
                level = 0.0,
                label = s(R.string.autosave_two_label, whiteName(), blackName(), uciLog.size),
                savedAt = System.currentTimeMillis(),
                startFen = ui.settings.startFen,
                timeControlId = ui.settings.timeControlId,
                whiteMs = clock?.remaining(Piece.Color.white),
                blackMs = clock?.remaining(Piece.Color.black),
                settingsJson = TwoPlayerSettingsStore.encode(ui.settings),
            )
        )
    }

    // MARK: Interaction

    fun onSquareTap(square: Square) {
        // En consultation, le plateau est une PHOTO : on n'y joue pas.
        if (ui.gameOver || ui.pendingPromotion != null || ui.isReviewing) return
        val mover = board.position.sideToMove

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            val move = board.move(pieceAt = selected, to = square) ?: return
            if (board.state is Board.State.Promotion) {
                ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
                return
            }
            commit(move)
            return
        }

        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == mover) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            if (selected != null && piece == null) Haptics.illegal()
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        ui = ui.copy(pendingPromotion = null)
        // Le drapeau a pu tomber pendant que la fenêtre était ouverte :
        // le coup ne se joue pas sur une partie déjà finie.
        if (ui.gameOver) return
        commit(board.completePromotion(of = pending, to = kind))
    }

    /**
     * Toucher à côté ANNULE le coup : promouvoir en dame par défaut, c'est
     * jouer à la place de quelqu'un qui n'a pas encore choisi. Le plateau a
     * déjà bougé, il faut donc le remettre où il était.
     */
    fun cancelPromotion() {
        if (ui.pendingPromotion == null) return
        ui = ui.copy(pendingPromotion = null, selected = null, legalTargets = emptySet())
        board = Board(history.last())
        ui = ui.copy(position = board.position)
    }

    // La présentation du plateau se choisit AVANT la partie, sur l'écran de
    // réglages, et pas en cours de route : c'est ce que fait iOS, et un
    // interrupteur « retourner à chaque coup » posé sous le plateau invitait
    // à en changer au milieu d'une partie, ce qui n'a pas de sens quand on
    // vient de se passer le téléphone.

    // MARK: Le coup, une fois joué

    private fun commit(move: Move) {
        uciLog += move.lan
        clock?.stopAndIncrement(System.currentTimeMillis())
        moveLog += move
        recorder.record(move)
        history += board.position.copy()
        // Les joueurs ont continué sur la ligne reprise : ils l'ont acceptée.
        clearResumeUndo()

        val position = board.position
        val state = board.state

        // Le son suit le COUP, pas l'état : une prise reste une prise même
        // quand elle donne échec — c'est l'échec qui l'emporte.
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        val isCapture = move.result is Move.Result.Capture
        val isCastle = move.result is Move.Result.Castle
        val isCheck = state is Board.State.Check || state is Board.State.Checkmate
        SoundPlayer.forMove(isCapture, isCastle, isCheck)
        Haptics.forMove(isCapture, isCastle, isCheck)

        // Le coup est ANNONCÉ : sans cela, qui n'a pas le plateau sous les
        // yeux ne sait pas ce que l'autre vient de jouer.
        announce(
            com.chesslab.ui.MoveNarration.announcement(
                getApplication(),
                s(if (move.piece.color == Piece.Color.white) R.string.color_white else R.string.color_black),
                move.san,
            )
        )

        ui = ui.copy(
            position = position,
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            selected = null,
            legalTargets = emptySet(),
            lastMove = move.start to move.end,
            checkedKing = checkedKing(state),
            captured = CapturedMaterial.from(moveLog, board),
            sanMoves = ui.sanMoves + move.san,
            displayedPly = ui.sanMoves.size + 1,
            orientation = if (ui.settings.rotation == TwoPlayerSettings.RotationMode.faceToFace)
                position.sideToMove else ui.orientation,
        )

        when (state) {
            is Board.State.Checkmate -> {
                finish(state.color.opposite, s(R.string.reason_checkmate))
                return
            }
            is Board.State.Draw -> {
                finish(null, drawLabel(state.reason))
                return
            }
            else -> Unit
        }

        startClockForSideToMove()
        autosave()
    }

    private fun checkedKing(state: Board.State): Square? = when (state) {
        is Board.State.Check -> kingSquare(state.color)
        is Board.State.Checkmate -> kingSquare(state.color)
        else -> null
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

    // MARK: Fin de partie

    /**
     * L'un des deux abandonne. Sur un téléphone posé entre deux joueurs, il
     * faut DIRE lequel : c'est l'écran qui pose la question, le modèle reçoit
     * la réponse.
     */
    fun resign(color: Piece.Color) {
        if (ui.gameOver) return
        finish(color.opposite, s(R.string.reason_resignation))
    }

    /** Les deux joueurs se mettent d'accord sur la nulle. */
    fun agreeToDraw() {
        if (ui.gameOver) return
        finish(null, s(R.string.draw_agreement))
    }

    /**
     * Termine la partie, l'ENREGISTRE sous les noms des joueurs, et arrête
     * tout ce qui tourne.
     */
    private fun finish(winner: Piece.Color?, reason: String) {
        if (ui.gameOver) return
        ticker?.cancel()
        undoJob?.cancel()
        clock?.pause(System.currentTimeMillis())
        Haptics.gameEnded()

        val message = if (winner == null) s(R.string.two_outcome_draw, reason)
        else s(R.string.two_outcome_won, nameOf(winner), reason)
        val result = when (winner) {
            Piece.Color.white -> "1-0"
            Piece.Color.black -> "0-1"
            null -> "1/2-1/2"
        }

        viewModelScope.launch(Dispatchers.IO) {
            LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
        }
        recorder.save(
            getApplication(),
            white = whiteName(), black = blackName(),
            source = "twoPlayer", state = board.state, forcedResult = result,
        )
        ui = ui.copy(
            gameOver = true, outcome = message, winner = winner, resumeUndo = null,
            selected = null, legalTargets = emptySet(),
        )
        // Les coups étaient annoncés, la fin de partie non : c'est pourtant
        // celle-là qu'on attend.
        announce(message)
    }

    // MARK: Consultation

    /** Le PGN de la partie en cours, pour « Analyser » et pour l'export. */
    fun currentPgn(): String = recorder.pgn

    /** La FEN de la position AFFICHÉE : en consultation, celle sous les yeux. */
    fun displayedFen(): String = ui.position.fen

    fun reviewPrevious() = review(ui.displayedPly - 1)

    fun reviewNext() = review(ui.displayedPly + 1)

    fun reviewToStart() = review(0)

    fun reviewToLive() = review(ui.sanMoves.size)

    fun reviewTo(ply: Int) = review(ply)

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
            selected = null, legalTargets = emptySet(),
            lastMove = move?.let { it.start to it.end },
        )
    }

    /**
     * Repart du coup CONSULTÉ : la suite est écartée, et la partie continue
     * d'ici. Sans confirmation — les deux joueurs sont d'accord, c'est leur
     * partie — mais avec huit secondes pour se raviser.
     */
    fun resumeFromReview() {
        if (!ui.canResumeFromReview) return
        val ply = ui.displayedPly
        val discarded = uciLog.drop(ply)
        if (discarded.isEmpty()) return
        rebuild(uciLog.take(ply))
        ui = ui.copy(resumeUndo = ResumeUndo(discarded, ply))
        // Sans feuille de confirmation, rien n'annonce la troncature à qui ne
        // voit pas la liste raccourcir.
        announce(s(R.string.two_resume_announce, discarded.size))
        undoJob?.cancel()
        undoJob = viewModelScope.launch {
            delay(RESUME_UNDO_MS)
            ui = ui.copy(resumeUndo = null)
        }
    }

    /** Rend les coups que « Reprendre ici » venait d'écarter. */
    fun cancelResumeFromReview() {
        val undo = ui.resumeUndo ?: return
        if (ui.gameOver) return
        undoJob?.cancel()
        ui = ui.copy(resumeUndo = null)
        rebuild(uciLog.take(undo.atPly) + undo.discarded)
    }

    private fun clearResumeUndo() {
        undoJob?.cancel()
        if (ui.resumeUndo != null) ui = ui.copy(resumeUndo = null)
    }

    /**
     * Reconstruit la partie en ne gardant que [lans].
     *
     * On s'arrête au PREMIER coup injouable : le sauter appliquerait tous les
     * suivants à une position devenue fausse, et l'on ré-enregistrerait
     * par-dessus — la fin de la partie serait perdue sans que personne le
     * sache.
     */
    private fun rebuild(lans: List<String>) {
        failedResume = false
        ticker?.cancel()
        board = Board(startPosition)
        history.clear()
        history += startPosition
        moveLog.clear()
        uciLog.clear()
        val custom = startPosition.fen.takeIf { it != Position.standard.fen }
        recorder.reset(startPosition, custom)
        ui = ui.copy(sanMoves = emptyList(), lastMove = null, gameOver = false, outcome = null, winner = null)

        for (lan in lans) {
            if (lan.length < 4) { failedResume = true; break }
            var move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            if (move == null) { failedResume = true; break }
            if (lan.length == 5) move = board.completePromotion(of = move, to = kindOf(lan[4]))
            history += board.position.copy()
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            ui = ui.copy(sanMoves = ui.sanMoves + move.san, lastMove = move.start to move.end)
        }

        val state = board.state
        ui = ui.copy(
            position = board.position,
            captured = CapturedMaterial.from(moveLog, board),
            checkedKing = checkedKing(state),
            displayedPly = ui.sanMoves.size,
            selected = null, legalTargets = emptySet(),
            orientation = if (ui.settings.rotation == TwoPlayerSettings.RotationMode.faceToFace)
                board.position.sideToMove else ui.orientation,
        )

        if (failedResume) {
            // La sauvegarde est inutilisable : on l'efface plutôt que de la
            // réécrire tronquée.
            viewModelScope.launch(Dispatchers.IO) {
                LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
            }
            return
        }

        when (state) {
            is Board.State.Checkmate -> { finish(state.color.opposite, s(R.string.reason_checkmate)); return }
            is Board.State.Draw -> { finish(null, drawLabel(state.reason)); return }
            else -> Unit
        }
        startClockForSideToMove()
        autosave()
    }

    private fun kindOf(c: Char): Piece.Kind = when (c) {
        'q' -> Piece.Kind.queen
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        else -> Piece.Kind.knight
    }
}
