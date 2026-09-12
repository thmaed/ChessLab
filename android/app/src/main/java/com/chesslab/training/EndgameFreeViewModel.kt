package com.chesslab.training

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
import com.chesslab.courses.CourseRepository
import com.chesslab.engine.EngineService
import com.chesslab.ui.BoardArrow
import com.chesslab.ui.HintArrowBuilder
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Où en est la séance. */
enum class FreePhase {
    /** Le verdict de la position courante est en cours de calcul. */
    preparing,
    awaiting,
    arbitrating,
    opponentMoving,
    slipped,
    finished,
    unavailable,
}

/** Le coup de promotion en attente, avec le plateau d'essai qui le porte. */
data class PendingPromotion(val scratch: Board, val move: Move)

data class EndgameFreeUiState(
    val position: Position = Position.standard,
    val orientation: Piece.Color = Piece.Color.white,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val phase: FreePhase = FreePhase.preparing,
    /**
     * Le verdict de la position COURANTE, du point de vue de l'utilisateur :
     * c'est l'objectif à tenir, et il se recalcule à chaque tour.
     */
    val baseline: EndgameVerdict? = null,
    /** Vrai quand l'arbitre connaît le meilleur coup d'ici : le bouton s'active. */
    val bestKnown: Boolean = false,
    /** Le verdict lâché, quand un coup a fait chuter la position. */
    val slipFrom: EndgameVerdict? = null,
    val slipTo: EndgameVerdict? = null,
    val slipCount: Int = 0,
    /** La flèche du coup qu'il fallait jouer, montrée après un faux pas. */
    val hints: List<BoardArrow> = emptyList(),
    val pendingPromotion: PendingPromotion? = null,
    val sanMoves: List<String> = emptyList(),
    /** Le résultat, en toutes lettres, quand la partie est finie. */
    val outcome: String? = null,
    /** Vrai si la fin est au moins à la hauteur du verdict de départ. */
    val success: Boolean = false,
)

/**
 * L'entraînement LIBRE d'une finale. Pendant d'`EndgameFreeTrainViewModel`.
 *
 * **Ce n'est pas le mode guidé.** Le guidé demande « est-ce LE coup de la
 * leçon ? » ; celui-ci demande « ce coup préserve-t-il le verdict théorique ? ».
 * Tout coup qui garde le gain est accepté, même s'il n'est pas le plus rapide —
 * c'est ce qui fait la différence entre réciter une leçon et savoir conclure.
 *
 * Un coup qui lâche est REPRIS, avec le verdict d'avant et d'après en toutes
 * lettres, et la flèche de ce qu'il fallait jouer.
 *
 * Deux détails de mécanique méritent d'être dits, parce qu'ils ne se voient
 * pas et que les rater fait un mode qui a l'air juste et ne l'est pas :
 *
 * - le coup de l'utilisateur s'arbitre sur un plateau d'ESSAI. Le vrai plateau
 *   ne bouge qu'une fois le coup accepté, si bien que « réessayer » n'a rien à
 *   défaire. Ici `Board` est une classe (l'original Swift est une `struct`
 *   copiée à chaque affectation) : sans cette copie explicite, le plateau
 *   bougeait quand même et la correction pointait le coup de l'ADVERSAIRE ;
 * - le verdict à tenir se RECALCULE après chaque riposte. Le garder figé sur
 *   la position de départ laisserait gâcher un gain obtenu en route — la
 *   nulle améliorée en gain est acceptée, et devient alors l'objectif.
 */
class EndgameFreeViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private var root: Position = Position.standard
    private var userColor = Piece.Color.white
    private var judge: EndgameJudge = StockfishEndgameJudge(app)

    /**
     * Le jeton d'ÉPOQUE : incrémenté à chaque arbitrage et à chaque reprise.
     * Toute suite qui revient d'une attente vérifie qu'elle appartient encore
     * à l'époque courante, sans quoi un « Rejouer » pendant la réflexion de la
     * défense laisserait la riposte de l'ANCIENNE partie s'appliquer.
     */
    private var token = 0

    /** Le meilleur coup d'ici, connu de l'arbitrage : la correction. */
    private var bestLanAtBaseline: String? = null

    var ui by mutableStateOf(EndgameFreeUiState())
        private set

    /** Pour les tests : un arbitre qui ne demande rien au moteur. */
    fun replaceJudge(other: EndgameJudge) { judge = other }

    private val isUserTurn: Boolean
        get() = ui.phase == FreePhase.awaiting && ui.pendingPromotion == null &&
            board.position.sideToMove == userColor

    fun start(courseId: String) = viewModelScope.launch {
        ui = ui.copy(phase = FreePhase.preparing)
        val course = withContext(Dispatchers.IO) {
            runCatching { CourseRepository.course(getApplication<Application>().assets, courseId) }.getOrNull()
        } ?: run { ui = ui.copy(phase = FreePhase.unavailable); return@launch }

        root = CourseRepository.position(course.rootFEN) ?: Position.standard
        userColor = if (course.side == "black") Piece.Color.black else Piece.Color.white
        board = Board(root)
        ui = EndgameFreeUiState(position = board.position, orientation = userColor)

        refreshBaseline()
        if (ui.phase == FreePhase.unavailable) return@launch
        // Rare mais légal : un cours dont la racine est au trait adverse.
        if (board.position.sideToMove != userColor && ui.outcome == null) reply(null)
    }

    // MARK: Interaction plateau

    fun onSquareTap(square: Square) {
        if (!isUserTurn) return

        val selected = ui.selected
        if (selected != null) {
            if (square == selected) { clearSelection(); return }
            if (square in ui.legalTargets) { attempt(selected, square); return }
        }
        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == board.position.sideToMove) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun clearSelection() { ui = ui.copy(selected = null, legalTargets = emptySet()) }

    /**
     * Le coup se joue sur une COPIE : le vrai plateau ne bouge qu'à
     * l'acceptation, ce qui rend « réessayer » gratuit et exact.
     */
    private fun attempt(from: Square, to: Square) {
        val scratch = Board(board.position)
        val move = scratch.move(from, to) ?: run { clearSelection(); return }
        clearSelection()
        if (scratch.state is Board.State.Promotion) {
            ui = ui.copy(pendingPromotion = PendingPromotion(scratch, move))
            return
        }
        viewModelScope.launch { arbitrate(scratch, move) }
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        ui = ui.copy(pendingPromotion = null)
        val move = pending.scratch.completePromotion(pending.move, kind)
        viewModelScope.launch { arbitrate(pending.scratch, move) }
    }

    fun cancelPromotion() { ui = ui.copy(pendingPromotion = null) }

    // MARK: Arbitrage

    /**
     * Le cœur du mode : le coup est-il théoriquement à la hauteur ?
     *
     * Un verdict qui S'AMÉLIORE est accepté sans commentaire : sous jeu
     * optimal c'est impossible, donc c'est l'ARBITRE qui se corrige (bruit du
     * moteur aux frontières). On ne félicite pas d'un artefact, et on
     * n'accuse surtout pas.
     *
     * Interne plutôt que privé : c'est la couture de test — les tests
     * construisent le plateau d'essai eux-mêmes et attendent l'arbitrage.
     */
    internal suspend fun arbitrate(scratch: Board, move: Move) {
        val baseline = ui.baseline ?: return
        ui = ui.copy(phase = FreePhase.arbitrating)
        token++
        val mine = token

        // Fin de partie par les RÈGLES : pas besoin d'arbitre.
        val state = scratch.state
        if (state is Board.State.Checkmate || state is Board.State.Draw) {
            // Le pat en position gagnante EST le coup qui lâche — le cas
            // d'école de la dame contre roi dépouillé. Il se voit sans moteur.
            val pat = state is Board.State.Draw && state.reason == Board.State.DrawReason.stalemate
            if (pat && baseline == EndgameVerdict.win) {
                slip(baseline, EndgameVerdict.draw)
                return
            }
            commit(scratch, move)
            finish()
            return
        }

        val after = judge.assess(scratch.position.fen)
        if (after == null) {
            if (mine == token) ui = ui.copy(phase = FreePhase.unavailable)
            return
        }
        if (mine != token) return

        // `after` est du point de vue de l'ADVERSAIRE, c'est à lui de jouer.
        val achieved = after.verdict.flipped
        if (EndgameVerdictRule.isDegradation(baseline, achieved)) {
            slip(baseline, achieved)
            return
        }

        commit(scratch, move)
        // L'arbitrage a DÉJÀ calculé le meilleur coup du camp au trait —
        // c'est-à-dire la riposte de la défense. La rejouer épargne une
        // seconde recherche identique (≈ 500 ms par coup accepté).
        reply(after.bestLan)
    }

    /** Le coup lâche : il n'est pas joué, et on montre ce qu'il fallait jouer. */
    private fun slip(from: EndgameVerdict, to: EndgameVerdict) {
        com.chesslab.sound.Haptics.illegal()
        ui = ui.copy(
            phase = FreePhase.slipped,
            slipFrom = from,
            slipTo = to,
            slipCount = ui.slipCount + 1,
            hints = bestLanAtBaseline?.let { listOf(arrow(it)) } ?: emptyList(),
        )
    }

    /** « Réessayer » : le plateau n'a jamais bougé, on efface la correction. */
    fun retry() {
        ui = ui.copy(
            phase = FreePhase.awaiting,
            slipFrom = null, slipTo = null, hints = emptyList(),
        )
    }

    /** « Jouer le meilleur coup » : l'arbitre l'applique et la partie suit. */
    fun playBest() = viewModelScope.launch {
        val best = bestLanAtBaseline
        val move = best?.let { applyLan(it) }
        if (move == null) { retry(); return@launch }
        ui = ui.copy(
            slipFrom = null, slipTo = null, hints = emptyList(),
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            checkedKing = checkedKing(),
        )
        val state = board.state
        if (state is Board.State.Checkmate || state is Board.State.Draw) { finish(); return@launch }
        reply(null)
    }

    /** « Rejouer » : la finale reprend à zéro, verdict compris. */
    fun restart() = viewModelScope.launch {
        token++                                   // invalide toute suite en vol
        board = Board(root)
        bestLanAtBaseline = null
        ui = EndgameFreeUiState(position = board.position, orientation = userColor)
        refreshBaseline()
        if (ui.phase == FreePhase.unavailable) return@launch
        if (board.position.sideToMove != userColor && ui.outcome == null) reply(null)
    }

    // MARK: Verdict et défense

    /**
     * (Re)calcule le verdict de la position courante — l'objectif affiché, et
     * la référence du prochain arbitrage. Pendant ce calcul l'utilisateur ne
     * peut pas jouer, ce qui évite d'arbitrer contre une référence périmée.
     */
    private suspend fun refreshBaseline() {
        ui = ui.copy(phase = FreePhase.preparing)
        token++
        val mine = token
        val assessment = judge.assess(board.position.fen)
        if (assessment == null) {
            if (mine == token) ui = ui.copy(phase = FreePhase.unavailable)
            return
        }
        if (mine != token) return
        val mover = board.position.sideToMove
        bestLanAtBaseline = if (mover == userColor) assessment.bestLan else null
        ui = ui.copy(
            phase = FreePhase.awaiting,
            baseline = if (mover == userColor) assessment.verdict else assessment.verdict.flipped,
            bestKnown = bestLanAtBaseline != null,
        )
    }

    /** La défense joue, puis le verdict se recalcule. */
    private suspend fun reply(preferred: String?) {
        ui = ui.copy(phase = FreePhase.opponentMoving)
        token++
        val mine = token

        val lan = preferred ?: judge.reply(board.position.fen)
        if (lan == null) {
            if (mine == token) ui = ui.copy(phase = FreePhase.unavailable)
            return
        }
        if (mine != token) return
        val move = applyLan(lan) ?: run {
            ui = ui.copy(phase = FreePhase.unavailable); return
        }
        com.chesslab.sound.Haptics.forMove(
            move.result is Move.Result.Capture,
            move.result is Move.Result.Castle,
            board.state is Board.State.Check,
        )
        ui = ui.copy(
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            checkedKing = checkedKing(),
            hints = emptyList(),
        )

        val state = board.state
        if (state is Board.State.Checkmate || state is Board.State.Draw) finish() else refreshBaseline()
    }

    private fun commit(scratch: Board, move: Move) {
        board = scratch
        com.chesslab.sound.Haptics.forMove(
            move.result is Move.Result.Capture,
            move.result is Move.Result.Castle,
            board.state is Board.State.Check,
        )
        ui = ui.copy(
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            checkedKing = checkedKing(),
            hints = emptyList(),
        )
    }

    /**
     * La fin, dite dans les mots du reste de l'app, et jugée honnêtement :
     * « réussi » veut dire avoir fait AU MOINS aussi bien que le verdict à
     * tenir — gagné quand c'était gagnant, au moins nul quand c'était nul.
     */
    private fun finish() {
        val state = board.state
        val mated = state as? Board.State.Checkmate
        val success = when {
            mated != null -> mated.color != userColor
            else -> ui.baseline != EndgameVerdict.win
        }
        val text = when {
            mated != null ->
                if (mated.color != userColor) s(R.string.checkmate_you_win) else s(R.string.checkmate_you_lose)
            state is Board.State.Draw -> s(R.string.draw_reason, drawLabel(state.reason))
            else -> s(R.string.endgame_free_drawn)
        }
        ui = ui.copy(phase = FreePhase.finished, outcome = text, success = success)
    }

    private fun drawLabel(reason: Board.State.DrawReason): String = when (reason) {
        Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
        Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
        Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
        Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
        Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
    }

    /** Joue un coup UCI sur le VRAI plateau, promotion comprise. */
    private fun applyLan(lan: String): Move? {
        if (lan.length < 4) return null
        val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return null
        if (board.state !is Board.State.Promotion) return move
        val kind = when (lan.drop(4)) {
            "r" -> Piece.Kind.rook
            "b" -> Piece.Kind.bishop
            "n" -> Piece.Kind.knight
            else -> Piece.Kind.queen
        }
        return board.completePromotion(move, kind)
    }

    private fun arrow(lan: String) = BoardArrow(
        Square(lan.substring(0, 2)), Square(lan.substring(2, 4)),
        HintArrowBuilder.tint(1.0), 1f,
    )

    private fun checkedKing(): Square? {
        val state = board.state
        val color = when (state) {
            is Board.State.Check -> state.color
            is Board.State.Checkmate -> state.color
            else -> return null
        }
        return board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square
    }
}

/** L'arbitre par défaut : Stockfish à pleine force, sur un temps court. */
private class StockfishEndgameJudge(private val app: Application) : EndgameJudge {

    override suspend fun assess(fen: String): EndgameAssessment? = withContext(Dispatchers.IO) {
        EngineService.use(app) { e ->
            e.send("position fen $fen")
            var cp: Int? = null
            val best = e.search("go movetime 500", timeoutMs = 10_000) { line ->
                if (!line.startsWith("info ") || !line.contains(" score ")) return@search
                line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                    ?.let { cp = if (it > 0) 10_000 else -10_000 }
                    ?: line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                        ?.let { cp = it }
            }?.removePrefix("bestmove ")?.trim()?.substringBefore(" ")
            val score = cp ?: return@use null
            EndgameAssessment(EndgameVerdictRule.verdict(score), best?.takeIf { it.length >= 4 })
        }
    }

    override suspend fun reply(fen: String): String? = withContext(Dispatchers.IO) {
        EngineService.use(app) { e ->
            e.send("position fen $fen")
            e.search("go movetime 500", timeoutMs = 10_000)
                ?.removePrefix("bestmove ")?.trim()?.substringBefore(" ")
        }?.takeIf { it.length >= 4 }
    }
}
