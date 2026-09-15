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
import com.chesslab.play.BlunderAlert
import com.chesslab.play.BlunderSeverity
import com.chesslab.play.PlayerColorChoice
import com.chesslab.ui.BoardArrow
import com.chesslab.ui.HintArrowBuilder
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
    /** Ce qui a été réglé avant de commencer. */
    val settings: VariantSettings = VariantSettings(),
    /** Le camp de l'utilisateur : le plateau se retourne avec lui. */
    val userColor: Piece.Color = Piece.Color.white,
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    /** L'évaluation POV Blancs, pour la barre. */
    val evalCp: Int? = null,
    val evalMate: Int? = null,
    val hints: List<BoardArrow> = emptyList(),
    val hintWanted: Boolean = false,
    val blunderWarning: BlunderSeverity? = null,
    /** Le mot de la fin, quel qu'en soit le motif. */
    val outcome: String? = null,
) {
    /** La partie est finie : roi pris, abandon, ou drapeau tombé. */
    val gameOver: Boolean get() = winner != null || outcome != null
}

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

    private var humanColor = Piece.Color.white
    private var enPassant: Square? = null
    private var legal: List<DuckChessRules.Move> = emptyList()
    private var turn: Job? = null
    private var evalJob: Job? = null
    private var hintJob: Job? = null

    /**
     * La partie, position par position — c'est ce que la revue d'après-partie
     * relit. Un journal de coups ne suffirait pas : ni le canard ni la prise en
     * passant ne se redéduisent des coups joués.
     */
    private val fenLog = ArrayList<String>()
    private val duckLog = ArrayList<Square?>()
    private val lanLog = ArrayList<String>()

    private val clock = VariantClock(viewModelScope).apply {
        onTick = { white, black -> ui = ui.copy(whiteClockMs = white, blackClockMs = black) }
        onFlag = { flagged ->
            val word = s(
                if (flagged == humanColor) R.string.outcome_flag_you else R.string.outcome_flag_opponent
            )
            ui = ui.copy(outcome = word, status = word, phase = DuckPhase.over, hints = emptyList())
        }
    }

    var ui by mutableStateOf(DuckUiState())
        private set

    /** Ce que la revue d'après-partie reçoit : les positions, dans l'ordre. */
    fun analysisFens(): List<String> = fenLog.toList()
    fun analysisMoves(): List<String> = lanLog.toList()

    init { newGame() }

    /** Les réglages arrivent de l'écran d'avant ; les rejouer relancerait la partie. */
    fun apply(settings: VariantSettings) {
        if (ui.settings == settings && fenLog.size > 1) return
        humanColor = when (settings.colorChoice) {
            PlayerColorChoice.white -> Piece.Color.white
            PlayerColorChoice.black -> Piece.Color.black
            PlayerColorChoice.random ->
                if (kotlin.random.Random.nextBoolean()) Piece.Color.white else Piece.Color.black
        }
        ui = ui.copy(settings = settings, userColor = humanColor)
        newGame()
    }

    fun newGame() {
        turn?.cancel()
        evalJob?.cancel()
        hintJob?.cancel()
        enPassant = null
        fenLog.clear()
        duckLog.clear()
        lanLog.clear()
        val settings = ui.settings
        clock.reset(settings.timeControl)
        ui = DuckUiState(
            status = if (humanColor == Piece.Color.white) s(R.string.your_turn)
            else s(R.string.engine_thinking),
            settings = settings,
            userColor = humanColor,
            whiteClockMs = clock.remaining(Piece.Color.white),
            blackClockMs = clock.remaining(Piece.Color.black),
        )
        fenLog += ui.position.fen
        duckLog += null
        refreshLegal()
        clock.startTurn(ui.position.sideToMove)
        if (humanColor != Piece.Color.white) engineTurn() else afterHumanTurnStarts()
    }

    private fun refreshLegal() {
        legal = DuckChessRules.moves(ui.position, ui.duck, enPassant)
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver) return
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
            hintJob?.cancel()
            ui = ui.copy(hints = emptyList(), blunderWarning = null)
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
        val mover = position.sideToMove

        // Poussée double : la case survolée devient prenable en passant.
        val piece = position.piece(move.from)
        enPassant = if (piece?.kind == Piece.Kind.pawn && abs(move.to.rank.value - move.from.rank.value) == 2) {
            Square("${move.from.file.letter}${(move.to.rank.value + move.from.rank.value) / 2}")
        } else {
            null
        }

        lanLog += move.uci

        if (victim != null) {
            // Le roi est tombé : la partie s'arrête AVANT même la pose du
            // canard, qui n'aurait plus d'objet.
            clock.stop()
            val word = s(R.string.duck_king_taken, s(winnerLabel(victim.opposite)))
            fenLog += next.fen
            duckLog += ui.duck
            ui = ui.copy(
                position = next, lastMove = move.from to move.to, selected = null,
                legalTargets = emptySet(), duckTargets = emptySet(),
                phase = DuckPhase.over, winner = victim.opposite, plies = ui.plies + 1,
                status = word, outcome = word, hints = emptyList(),
            )
            return
        }

        ui = ui.copy(
            position = next, lastMove = move.from to move.to, selected = null,
            legalTargets = emptySet(), phase = DuckPhase.placeDuck,
            duckTargets = DuckChessRules.duckTargets(next, ui.duck).toSet(),
            status = if (next.sideToMove == humanColor) s(R.string.duck_place) else s(R.string.duck_engine_places),
        )
        if (mover == humanColor) checkBlunder(position, next)
    }

    /** La pose du canard : c'est ELLE qui rend la main à l'autre camp. */
    private fun placeDuck(square: Square) {
        val flipped = DuckChessFen.flippedSideToMove(ui.position)
        // Le tour est fini : la pendule bascule, incrément compris.
        clock.stopAndIncrement()
        fenLog += flipped.fen
        duckLog += square
        ui = ui.copy(
            duck = square, position = flipped, duckTargets = emptySet(),
            phase = DuckPhase.movePiece, plies = ui.plies + 1,
            status = if (flipped.sideToMove == humanColor) s(R.string.your_turn) else s(R.string.engine_thinking),
        )
        refreshLegal()
        if (ui.gameOver) return
        clock.startTurn(flipped.sideToMove)
        if (flipped.sideToMove != humanColor) engineTurn() else afterHumanTurnStarts()
    }

    /** Le trait revient : la barre se remet à jour, et l'indice avec si on l'a demandé. */
    private fun afterHumanTurnStarts() {
        refreshEvalBar()
        if (ui.hintWanted) startHint()
    }

    /** Le tour de l'ordinateur, en deux temps lui aussi. */
    private fun engineTurn() {
        turn?.cancel()
        turn = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            val budget = clock.movetimeFor(ui.position.sideToMove)
            val move = DuckChessEngine.chooseMove(
                getApplication(), ui.position, ui.duck, enPassant,
                strength = ui.settings.strength, movetimeMs = budget,
            )
            if (move == null) {
                ui = ui.copy(thinking = false, phase = DuckPhase.over, status = s(R.string.game_over))
                return@launch
            }
            play(move)
            if (ui.gameOver) { ui = ui.copy(thinking = false); return@launch }

            val square = DuckChessEngine.chooseDuckSquare(getApplication(), ui.position, ui.duck)
            ui = ui.copy(thinking = false)
            if (square != null) placeDuck(square) else ui = ui.copy(status = s(R.string.game_over))
        }
    }

    // MARK: Aides

    /**
     * La barre d'évaluation. Le moteur ne VOIT PAS le canard : le chiffre est
     * un ordre de grandeur, très sûr sur le matériel, discutable sur le
     * positionnel fin. C'est la même réserve qu'iOS pose sur sa propre analyse.
     */
    private fun refreshEvalBar() {
        if (!ui.settings.showEvalBar) return
        val position = ui.position
        val duck = ui.duck
        val ep = enPassant
        evalJob?.cancel()
        evalJob = viewModelScope.launch {
            val eval = DuckChessEngine.evaluate(getApplication(), position, duck, ep) ?: return@launch
            if (ui.position.fen != position.fen) return@launch
            val sign = if (position.sideToMove == Piece.Color.white) 1 else -1
            ui = ui.copy(evalCp = eval.cp?.let { it * sign }, evalMate = eval.mate?.let { it * sign })
        }
    }

    fun toggleHint() {
        if (!ui.settings.hintsEnabled || ui.gameOver) return
        if (ui.hintWanted) {
            hintJob?.cancel()
            ui = ui.copy(hintWanted = false, hints = emptyList())
            return
        }
        ui = ui.copy(hintWanted = true)
        startHint()
    }

    private fun startHint() {
        if (!ui.hintWanted || ui.gameOver) return
        if (ui.position.sideToMove != humanColor || ui.phase != DuckPhase.movePiece) return
        val position = ui.position
        val duck = ui.duck
        val ep = enPassant
        hintJob?.cancel()
        hintJob = viewModelScope.launch {
            val (lanByRank, scoreByRank) = DuckChessEngine.hintLines(getApplication(), position, duck, ep)
            if (ui.position.fen != position.fen || !ui.hintWanted) return@launch
            ui = ui.copy(hints = HintArrowBuilder.build(lanByRank, scoreByRank))
        }
    }

    /** L'alerte de gaffe, rétroactive : prévenir avant ferait attendre à chaque coup. */
    private fun checkBlunder(before: Position, after: Position) {
        if (!ui.settings.blunderAlertEnabled) return
        val duck = ui.duck
        val ep = enPassant
        viewModelScope.launch {
            val beforeEval = DuckChessEngine.evaluate(getApplication(), before, duck, null) ?: return@launch
            val afterEval = DuckChessEngine.evaluate(getApplication(), after, duck, ep) ?: return@launch
            val severity = BlunderAlert.severity(
                beforeCp = beforeEval.cp ?: 0, beforeMate = beforeEval.mate,
                afterCp = afterEval.cp ?: 0, afterMate = afterEval.mate,
            ) ?: return@launch
            if (ui.gameOver) return@launch
            ui = ui.copy(blunderWarning = severity)
        }
    }

    fun dismissBlunderWarning() { ui = ui.copy(blunderWarning = null) }

    // MARK: Fin de partie

    fun resign() {
        if (ui.gameOver) return
        turn?.cancel()
        clock.stop()
        val word = s(R.string.outcome_resigned)
        ui = ui.copy(outcome = word, status = word, phase = DuckPhase.over, hints = emptyList())
    }

    /** L'écran s'en va : la pendule s'arrête, sinon le drapeau tombe derrière. */
    fun pauseForBackground() {
        if (ui.gameOver) return
        clock.pause()
    }

    /** Et repart au retour — le modèle de vue, lui, survit à la navigation. */
    fun resumeFromBackground() {
        if (ui.gameOver) return
        clock.startTurn(ui.position.sideToMove)
    }

    private fun winnerLabel(color: Piece.Color) =
        if (color == Piece.Color.white) R.string.mate_white_wins else R.string.mate_black_wins

    override fun onCleared() {
        turn?.cancel()
        evalJob?.cancel()
        hintJob?.cancel()
        clock.stop()
        super.onCleared()
    }
}
