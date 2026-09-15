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
    /** Ce qui a été réglé avant de commencer. */
    val settings: VariantSettings = VariantSettings(),
    /** Le camp de l'utilisateur : le plateau se retourne avec lui. */
    val userColor: Piece.Color = Piece.Color.white,
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    /** L'évaluation POV Blancs, pour la barre. */
    val evalCp: Int? = null,
    val evalMate: Int? = null,
    val hints: List<com.chesslab.ui.BoardArrow> = emptyList(),
    val hintWanted: Boolean = false,
    val blunderWarning: com.chesslab.play.BlunderSeverity? = null,
    /** Le moteur vient de refuser la nulle — l'écran le dit, puis l'efface. */
    val drawDeclined: Boolean = false,
) {
    /** Celui à qui appartient VRAIMENT le trait : le tour double le garde. */
    val mover: Piece.Color get() = awaitingSecondMoveBy ?: position.sideToMove

    val gameOver: Boolean get() = outcome != null
}

/**
 * Le Coup Volé. Pendant réduit de `StolenMovePlayViewModel.swift`.
 *
 * `chesskit` arbitre chaque coup, Stockfish joue les Noirs, et le TOUR DOUBLE
 * est tenu ici, par [StolenMoveRules] : aucun moteur ne sait l'exprimer.
 */
class StolenMoveViewModel(app: Application) : AndroidViewModel(app) {

    private var humanColor = Piece.Color.white
    private var engineColor = Piece.Color.black

    private var board = Board()
    private var movesPlayed = HashMap<Piece.Color, Int>()

    /**
     * La partie, position par position — ce que la revue d'après-partie relit.
     * Les coups seuls ne suffiraient pas : un tour double fait jouer deux fois
     * le même camp, et rejouer la liste au moteur s'arrêterait au second.
     */
    private val fenLog = ArrayList<String>()
    private val lanLog = ArrayList<String>()

    private var evalJob: Job? = null
    private var hintJob: Job? = null

    /** Dernière évaluation du MOTEUR, de son point de vue, pour la nulle. */
    private var lastEngineEvalCp: Int? = null

    private val clock = VariantClock(viewModelScope).apply {
        onTick = { white, black -> ui = ui.copy(whiteClockMs = white, blackClockMs = black) }
        onFlag = { flagged ->
            val word = s(
                if (flagged == humanColor) R.string.outcome_flag_you else R.string.outcome_flag_opponent
            )
            ui = ui.copy(outcome = word, status = word, hints = emptyList())
        }
    }
    /**
     * La prise en passant ouverte AVANT le premier coup d'un tour double :
     * on la rend au second coup (règle 5).
     */
    private var enPassantAtTurnStart: String? = null
    private var turn: Job? = null

    var ui by mutableStateOf(StolenMoveUiState())
        private set

    init { newGame() }

    /** Les réglages arrivent de l'écran d'avant ; les rejouer relancerait la partie. */
    fun apply(settings: VariantSettings) {
        if (ui.settings == settings && fenLog.size > 1) return
        humanColor = when (settings.colorChoice) {
            com.chesslab.play.PlayerColorChoice.white -> Piece.Color.white
            com.chesslab.play.PlayerColorChoice.black -> Piece.Color.black
            com.chesslab.play.PlayerColorChoice.random ->
                if (kotlin.random.Random.nextBoolean()) Piece.Color.white else Piece.Color.black
        }
        engineColor = humanColor.opposite
        ui = ui.copy(
            settings = settings, userColor = humanColor,
            tokenInterval = settings.tokenInterval,
        )
        newGame()
    }

    /** Ce que la revue d'après-partie reçoit : les positions, dans l'ordre. */
    fun analysisFens(): List<String> = fenLog.toList()
    fun analysisMoves(): List<String> = lanLog.toList()

    fun newGame() {
        turn?.cancel()
        evalJob?.cancel()
        hintJob?.cancel()
        board = Board()
        movesPlayed = HashMap()
        enPassantAtTurnStart = null
        fenLog.clear()
        lanLog.clear()
        fenLog += board.position.fen
        lastEngineEvalCp = null
        val settings = ui.settings
        clock.reset(settings.timeControl)
        ui = StolenMoveUiState(
            status = if (humanColor == Piece.Color.white) s(R.string.your_turn)
            else s(R.string.engine_thinking),
            tokenInterval = ui.tokenInterval,
            settings = settings,
            userColor = humanColor,
            whiteClockMs = clock.remaining(Piece.Color.white),
            blackClockMs = clock.remaining(Piece.Color.black),
        )
        clock.startTurn(Piece.Color.white)
        if (humanColor != Piece.Color.white) engineTurn() else afterHumanTurnStarts()
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
            hintJob?.cancel()
            val before = playable.position.fen
            ui = ui.copy(hints = emptyList(), blunderWarning = null)
            if (commit(selected, square)) checkBlunder(before, interactionBoard().position.fen)
            if (ui.outcome == null && ui.mover == engineColor) engineTurn()
            else if (ui.outcome == null) afterHumanTurnStarts()
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
        lanLog += from.notation + to.notation
        publish(
            tokens = tokens, awaiting = awaiting, lastMove = from to to,
            san = ui.sanMoves + move.san,
        )
        // La position d'où partira le coup SUIVANT : pendant un tour double,
        // c'est celle où le trait revient à celui qui n'a pas fini.
        fenLog += interactionBoard().position.fen
        // Le tour est fini : la pendule bascule, incrément compris. Pendant un
        // tour double elle continue de tourner pour le même camp — deux coups
        // d'affilée ne donnent pas deux incréments.
        if (awaiting == null) {
            clock.stopAndIncrement()
            if (ui.outcome == null) clock.startTurn(board.position.sideToMove)
        }
        if (ui.outcome != null) clock.stop()
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
        val strength = ui.settings.strength
        val budget = clock.movetimeFor(engineColor)
        var cp: Int? = null
        val best = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { engine ->
                // Le bridage part AVANT le `go` : sans lui, choisir « 1200 »
                // sur l'écran de réglage ne changeait rien du tout.
                for (command in strength.setupCommands) engine.send(command)
                engine.send("position fen $fen")
                val go = strength.maxDepth?.let { "go depth $it" } ?: "go movetime $budget"
                engine.search(go, timeoutMs = 30_000) { line ->
                    if (line.startsWith("info ") && line.contains(" score cp ")) {
                        line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                            ?.let { cp = it }
                    }
                }
            }
        }?.split(" ")?.getOrNull(1)
        ui = ui.copy(thinking = false)
        cp?.let { lastEngineEvalCp = it }
        if (best == null || best.length < 4 || best == "(none)") {
            ui = ui.copy(status = s(R.string.engine_silent))
            return false
        }
        return commit(Square(best.substring(0, 2)), Square(best.substring(2, 4)))
    }

    // MARK: Aides

    /** Le trait revient : la barre se remet à jour, et l'indice avec si on l'a demandé. */
    private fun afterHumanTurnStarts() {
        refreshEvalBar()
        if (ui.hintWanted) startHint()
    }

    private fun refreshEvalBar() {
        if (!ui.settings.showEvalBar) return
        val fen = interactionBoard().position.fen
        evalJob?.cancel()
        evalJob = viewModelScope.launch {
            val eval = scoreOf(fen) ?: return@launch
            if (interactionBoard().position.fen != fen) return@launch
            val sign = if (fen.contains(" w ")) 1 else -1
            ui = ui.copy(evalCp = eval.first?.let { it * sign }, evalMate = eval.second?.let { it * sign })
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
        if (!ui.hintWanted || ui.gameOver || ui.mover != humanColor) return
        val fen = interactionBoard().position.fen
        hintJob?.cancel()
        hintJob = viewModelScope.launch {
            val lanByRank = HashMap<Int, String>()
            val scoreByRank = HashMap<Int, Double>()
            withContext(Dispatchers.IO) {
                EngineService.use(getApplication()) { engine ->
                    engine.send("setoption name MultiPV value 3")
                    engine.send("position fen $fen")
                    engine.search("go movetime 1500", timeoutMs = 30_000) { line ->
                        if (!line.startsWith("info ") || !line.contains(" multipv ")) return@search
                        val rank = line.substringAfter(" multipv ", "").substringBefore(" ").toIntOrNull()
                            ?: return@search
                        val first = line.substringAfter(" pv ", "").substringBefore(" ")
                        if (first.isBlank()) return@search
                        lanByRank[rank] = first
                        val mate = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                        val cp = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                        when {
                            mate != null -> scoreByRank[rank] = if (mate > 0) 10_000.0 - mate else -10_000.0 - mate
                            cp != null -> scoreByRank[rank] = cp.toDouble()
                        }
                    }
                    engine.send("setoption name MultiPV value 1")
                }
            }
            if (interactionBoard().position.fen != fen || !ui.hintWanted) return@launch
            ui = ui.copy(hints = com.chesslab.ui.HintArrowBuilder.build(lanByRank, scoreByRank))
        }
    }

    /** L'alerte de gaffe, rétroactive : prévenir avant ferait attendre à chaque coup. */
    private fun checkBlunder(beforeFen: String, afterFen: String) {
        if (!ui.settings.blunderAlertEnabled) return
        viewModelScope.launch {
            val before = scoreOf(beforeFen) ?: return@launch
            val after = scoreOf(afterFen) ?: return@launch
            val severity = com.chesslab.play.BlunderAlert.severity(
                beforeCp = before.first ?: 0, beforeMate = before.second,
                afterCp = after.first ?: 0, afterMate = after.second,
            ) ?: return@launch
            if (ui.gameOver || interactionBoard().position.fen != afterFen) return@launch
            ui = ui.copy(blunderWarning = severity)
        }
    }

    fun dismissBlunderWarning() { ui = ui.copy(blunderWarning = null) }

    /** Le score d'une position, POV du camp au trait : (centipions, mat). */
    private suspend fun scoreOf(fen: String, movetimeMs: Int = 250): Pair<Int?, Int?>? {
        var cp: Int? = null
        var mate: Int? = null
        withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { engine ->
                engine.send("position fen $fen")
                engine.search("go movetime $movetimeMs", timeoutMs = 30_000) { line ->
                    if (!line.startsWith("info ") || !line.contains(" score ")) return@search
                    line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                        ?.let { cp = it; mate = null }
                    line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                        ?.let { mate = it }
                }
            }
        }
        if (cp == null && mate == null) return null
        return cp to mate
    }

    // MARK: Abandon et nulle

    fun resign() {
        if (ui.gameOver) return
        turn?.cancel()
        clock.stop()
        val word = s(R.string.outcome_resigned)
        ui = ui.copy(outcome = word, status = word, hints = emptyList())
    }

    /**
     * Même règle qu'en mode « Contre l'ordinateur » : il accepte s'il ne se
     * voit pas mieux qu'une quasi-égalité sur son dernier coup, refuse sinon —
     * et refuse tant qu'il n'a pas joué, faute d'avoir un avis.
     */
    fun offerDraw() {
        if (ui.gameOver || ui.thinking) return
        val cp = lastEngineEvalCp
        if (cp == null || kotlin.math.abs(cp) > DRAW_ACCEPTANCE_CP) {
            ui = ui.copy(drawDeclined = true)
            return
        }
        turn?.cancel()
        clock.stop()
        val word = s(R.string.outcome_draw_agreed)
        ui = ui.copy(outcome = word, status = word, hints = emptyList())
    }

    fun dismissDrawDeclined() { ui = ui.copy(drawDeclined = false) }

    /** L'écran s'en va : la pendule s'arrête, sinon le drapeau tombe derrière. */
    fun pauseForBackground() {
        if (ui.gameOver) return
        clock.pause()
    }

    /** Et repart au retour — le modèle de vue, lui, survit à la navigation. */
    fun resumeFromBackground() {
        if (ui.gameOver) return
        clock.startTurn(ui.mover)
    }

    private fun isInCheck(board: Board, color: Piece.Color): Boolean =
        (board.state as? Board.State.Check)?.color == color

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    override fun onCleared() {
        turn?.cancel()
        evalJob?.cancel()
        hintJob?.cancel()
        clock.stop()
        super.onCleared()
    }

    private companion object {
        /** Écart d'évaluation en deçà duquel l'ordinateur accepte une nulle. */
        const val DRAW_ACCEPTANCE_CP = 50
    }
}
