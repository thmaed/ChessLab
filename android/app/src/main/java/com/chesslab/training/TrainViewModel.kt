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
import com.chesslab.courses.CatalogEntry
import com.chesslab.courses.Course
import com.chesslab.courses.CourseMove
import com.chesslab.courses.CourseRepository
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.SoundPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Ce que la séance sert. */
sealed interface TrainMode {
    /** Les positions dues, puis un quota de neuves, à travers le répertoire. */
    data object Daily : TrainMode
    /** Uniquement les positions déjà ratées. */
    data object Hardest : TrainMode
    /** Une ligne précise, du début à la fin. */
    data class FullLine(val courseId: String) : TrainMode
}

enum class TrainPhase {
    /** À l'utilisateur de jouer. */
    awaiting,
    /** L'adversaire va répondre tout seul. */
    opponentMoving,
    /** Coup du répertoire mais pas la principale : à l'utilisateur de choisir. */
    variation,
    /** Hors répertoire : le bon coup est montré. */
    wrong,
    complete,
    empty,
}

data class TrainUiState(
    val position: Position = Position.standard,
    val orientation: Piece.Color = Piece.Color.white,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val hint: Pair<Square, Square>? = null,
    val phase: TrainPhase = TrainPhase.awaiting,
    val courseName: String = "",
    val comment: String? = null,
    /**
     * Une remarque de l'app, distincte du commentaire du cours : « aussi
     * jouable : b4 ». Elle DOIT survivre à la riposte du partenaire, sinon
     * elle s'affiche 550 ms et disparaît sans avoir été lue.
     */
    val note: String? = null,
    val playedSans: List<String> = emptyList(),
    val reviewed: Int = 0,
    val correct: Int = 0,
    /** Positions restant à voir dans la séance, séance comprise. */
    val remaining: Int = 0,
    val variationPlayed: String? = null,
    val variationMain: String? = null,
    val wrongCorrect: String? = null,
    val pendingPromotion: Move? = null,
    val loading: Boolean = true,
)

/**
 * Le mode ENTRAÎNER : on parcourt une ouverture sur UN seul échiquier
 * continu, sauf que c'est l'utilisateur qui joue SON camp — l'adversaire
 * répond tout seul sur la ligne principale de la branche courante.
 *
 * - Coup principal → accepté, l'adversaire enchaîne, sans clic.
 * - Variante du répertoire → l'utilisateur choisit : la jouer, ou rester sur
 *   la principale.
 * - Coup hors répertoire → erreur : le bon coup s'allume, puis on le joue et
 *   on poursuit la ligne.
 *
 * La répétition espacée reste EN COULISSE : chaque position jouée est notée
 * automatiquement (erreur → Encore, indice → Difficile, sinon Bien) et la
 * planification FSRS se fait sans que l'utilisateur ait à s'en occuper.
 *
 * Pendant réduit d'`OpeningTrainViewModel.swift`.
 */
class TrainViewModel(app: Application) : AndroidViewModel(app) {

    private val dao = LibraryDatabase.get(app).training()
    private val fsrs = Fsrs()

    private var mode: TrainMode = TrainMode.Daily
    private var sessionCourses: List<Pair<Course, String>> = emptyList()   // cours + camp d'étude
    private var courseIndex = 0
    private var board = Board()
    private var currentKey: String = ""
    private var usedHint = false
    private var opponentToken = 0
    private var pendingVariation: Pair<CourseMove, CourseMove>? = null   // joué, principal
    private var wrongMain: CourseMove? = null
    private var plannedSize = 0

    var ui by mutableStateOf(TrainUiState())
        private set

    private val course: Course? get() = sessionCourses.getOrNull(courseIndex)?.first
    private val side: String get() = sessionCourses.getOrNull(courseIndex)?.second ?: "white"

    fun start(mode: TrainMode) {
        this.mode = mode
        viewModelScope.launch {
            ui = ui.copy(loading = true)
            val built = withContext(Dispatchers.IO) { buildSession(mode) }
            sessionCourses = built.first
            plannedSize = built.second
            courseIndex = 0
            if (sessionCourses.isEmpty()) {
                ui = TrainUiState(phase = TrainPhase.empty, loading = false)
            } else {
                ui = ui.copy(loading = false, remaining = plannedSize)
                startCourse()
            }
        }
    }

    /**
     * Les cours de la séance, et combien de positions elle vise.
     *
     * En quotidien et en difficiles, on bâtit la file complète pour savoir
     * QUELS cours ouvrir — et on garde sa taille, qui est le seul compteur
     * honnête de « ce qu'il reste à faire ».
     */
    private fun buildSession(mode: TrainMode): Pair<List<Pair<Course, String>>, Int> {
        val assets = getApplication<Application>().assets
        if (mode is TrainMode.FullLine) {
            val entry = CourseRepository.catalog(assets).firstOrNull { it.id == mode.courseId }
            val course = CourseRepository.course(assets, mode.courseId) ?: return emptyList<Pair<Course, String>>() to 0
            val side = entry?.side ?: "white"
            return listOf(course to side) to TrainingQueue.lineCards(course, side).size
        }

        // Un seul passage sur le catalogue : on ne lit un cours que si le
        // catalogue promet des positions, et on s'arrête à huit cours — une
        // séance, pas un marathon.
        val progress = kotlinx.coroutines.runBlocking { dao.allProgress() }.associate { it.fenKey to it.snapshot }
        val now = System.currentTimeMillis()
        val entries = CourseRepository.catalog(assets)
        val loaded = ArrayList<Pair<Course, String>>()
        val cards = ArrayList<TrainCard>()
        for (entry in entries) {
            val c = CourseRepository.course(assets, entry.id) ?: continue
            val mine = TrainingQueue.trainableCards(c, entry.side)
            val useful = when (mode) {
                TrainMode.Hardest -> TrainingQueue.hardest(mine, progress)
                else -> TrainingQueue.daily(mine, progress, now, newLimit = 20)
            }
            if (useful.isEmpty()) continue
            loaded += c to entry.side
            cards += useful
            if (loaded.size >= 8) break
        }
        val queue = when (mode) {
            TrainMode.Hardest -> TrainingQueue.hardest(cards, progress)
            else -> TrainingQueue.daily(cards, progress, now, newLimit = 20)
        }
        return loaded to queue.size
    }

    // MARK: Marche du graphe

    /** Coups jouables ici : la principale d'abord, puis par popularité. */
    private fun candidates(key: String): List<CourseMove> =
        course?.positions?.get(key).orEmpty()
            .sortedWith(compareByDescending<CourseMove> { it.isMainLine }.thenByDescending { it.popularity ?: 0.0 })

    private val mainEdge: CourseMove? get() = candidates(currentKey).firstOrNull()

    private fun startCourse() {
        val c = course ?: return
        val root = CourseRepository.fenKey(c.rootFEN)
        val position = CourseRepository.position(c.rootFEN) ?: Position.standard
        board = Board(position)
        currentKey = root
        pendingVariation = null
        wrongMain = null
        usedHint = false
        ui = ui.copy(
            position = board.position,
            orientation = if (side == "black") Piece.Color.black else Piece.Color.white,
            courseName = c.name,
            comment = c.summary.ifEmpty { null },
            playedSans = emptyList(), note = null,
            lastMove = null, hint = null, selected = null, legalTargets = emptySet(),
            variationPlayed = null, variationMain = null, wrongCorrect = null,
        )
        advanceTurn()
    }

    /**
     * À qui de jouer : fin de ligne → cours suivant ; trait à l'utilisateur →
     * on attend ; sinon l'adversaire répond après un souffle.
     */
    private fun advanceTurn() {
        if (candidates(currentKey).isEmpty()) { nextCourseOrComplete(); return }
        if (board.position.sideToMove == ui.orientation) {
            ui = ui.copy(phase = TrainPhase.awaiting)
        } else {
            ui = ui.copy(phase = TrainPhase.opponentMoving)
            opponentToken += 1
            val token = opponentToken
            viewModelScope.launch {
                delay(550)
                if (token != opponentToken || ui.phase != TrainPhase.opponentMoving) return@launch
                val edge = mainEdge
                if (edge == null) nextCourseOrComplete() else { apply(edge, isUser = false); advanceTurn() }
            }
        }
    }

    private fun nextCourseOrComplete() {
        courseIndex += 1
        if (courseIndex < sessionCourses.size) startCourse()
        else ui = ui.copy(phase = TrainPhase.complete, remaining = 0)
    }

    /** Joue une arête sur le plateau continu et affiche son commentaire. */
    private fun apply(edge: CourseMove, isUser: Boolean) {
        val from = Square(edge.uci.substring(0, 2))
        val to = Square(edge.uci.substring(2, 4))
        val move = board.move(pieceAt = from, to = to) ?: return
        val played = if (edge.uci.length > 4) {
            val kind = when (edge.uci[4]) {
                'q' -> Piece.Kind.queen; 'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop; else -> Piece.Kind.knight
            }
            board.completePromotion(of = move, to = kind)
        } else move

        currentKey = CourseRepository.fenKey(edge.toFEN)
        val state = board.state
        val checked = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        SoundPlayer.forMove(
            isCapture = played.result is Move.Result.Capture,
            isCastle = played.result is Move.Result.Castle,
            isCheck = checked != null,
        )
        com.chesslab.sound.Haptics.forMove(
            isCapture = played.result is Move.Result.Capture,
            isCastle = played.result is Move.Result.Castle,
            isCheck = checked != null,
        )
        ui = ui.copy(
            position = board.position,
            lastMove = played.start to played.end,
            checkedKing = checked,
            comment = edge.comment,
            playedSans = ui.playedSans + edge.san,
            hint = null, selected = null, legalTargets = emptySet(),
            reviewed = if (isUser) ui.reviewed + 1 else ui.reviewed,
            remaining = if (isUser) maxOf(0, ui.remaining - 1) else ui.remaining,
            // La note survit à la riposte adverse : elle ne s'efface qu'au
            // coup SUIVANT de l'utilisateur.
            note = if (isUser) null else ui.note,
        )
        if (isUser) usedHint = false
    }

    private fun kingSquare(color: Piece.Color): Square? =
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    // MARK: Interaction

    private val isUserTurn: Boolean get() = ui.phase == TrainPhase.awaiting && ui.pendingPromotion == null

    fun tap(square: Square) {
        if (!isUserTurn) return
        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) { attempt(selected, square); return }
        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == board.position.sideToMove) {
            ui.copy(selected = square, legalTargets = board.legalMoves(forPieceAt = square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun attempt(from: Square, to: Square) {
        if (!board.canMove(pieceAt = from, to = to)) {
            ui = ui.copy(selected = null, legalTargets = emptySet()); return
        }
        // Le coup se joue sur une COPIE : tant qu'on ne sait pas s'il est au
        // répertoire, le plateau de la séance ne doit pas bouger.
        val scratch = Board(board.position.copy())
        val move = scratch.move(pieceAt = from, to = to) ?: run {
            ui = ui.copy(selected = null, legalTargets = emptySet()); return
        }
        ui = ui.copy(selected = null, legalTargets = emptySet())
        if (scratch.state is Board.State.Promotion) {
            ui = ui.copy(pendingPromotion = move); return
        }
        evaluate(move.lan)
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        ui = ui.copy(pendingPromotion = null)
        evaluate(pending.lan.take(4) + when (kind) {
            Piece.Kind.queen -> "q"; Piece.Kind.rook -> "r"
            Piece.Kind.bishop -> "b"; else -> "n"
        })
    }

    fun cancelPromotion() { ui = ui.copy(pendingPromotion = null) }

    /** Classe le coup joué : principal, variante, ou hors répertoire. */
    private fun evaluate(uci: String) {
        val cands = candidates(currentKey)
        val main = cands.firstOrNull() ?: return
        val edge = cands.firstOrNull { it.uci == uci }
        when {
            edge == null -> {
                // Le coup est refusé : le doigt le sent avant que l'œil ne lise.
                com.chesslab.sound.Haptics.illegal()
                record(FsrsRating.again)
                wrongMain = main
                ui = ui.copy(
                    phase = TrainPhase.wrong, wrongCorrect = main.san,
                    hint = Square(main.uci.substring(0, 2)) to Square(main.uci.substring(2, 4)),
                    comment = main.comment,
                )
            }
            edge.uci == main.uci -> {
                record(if (usedHint) FsrsRating.hard else FsrsRating.good)
                ui = ui.copy(correct = ui.correct + 1)
                apply(edge, isUser = true)
                advanceTurn()
            }
            else -> {
                pendingVariation = edge to main
                ui = ui.copy(phase = TrainPhase.variation, variationPlayed = edge.san, variationMain = main.san)
            }
        }
    }

    /** « Jouer la variante » : on suit cette branche. */
    fun playVariation() {
        val (played, _) = pendingVariation ?: return
        record(if (usedHint) FsrsRating.hard else FsrsRating.good)
        pendingVariation = null
        ui = ui.copy(correct = ui.correct + 1, variationPlayed = null, variationMain = null)
        apply(played, isUser = true)
        advanceTurn()
    }

    /** « Rester sur la principale » : on joue la principale, la variante est notée. */
    fun keepMainLine() {
        val (played, main) = pendingVariation ?: return
        record(if (usedHint) FsrsRating.hard else FsrsRating.good)
        pendingVariation = null
        ui = ui.copy(correct = ui.correct + 1, variationPlayed = null, variationMain = null)
        apply(main, isUser = true)
        ui = ui.copy(note = "Aussi jouable : ${played.san}.")
        advanceTurn()
    }

    /** Après une erreur : on joue le bon coup et on poursuit la ligne. */
    fun continueAfterWrong() {
        val main = wrongMain ?: return
        wrongMain = null
        ui = ui.copy(wrongCorrect = null, hint = null)
        apply(main, isUser = true)
        advanceTurn()
    }

    fun showHint() {
        if (!isUserTurn) return
        val main = mainEdge ?: return
        usedHint = true
        ui = ui.copy(hint = Square(main.uci.substring(0, 2)) to Square(main.uci.substring(2, 4)))
    }

    fun restart() {
        courseIndex = 0
        ui = ui.copy(reviewed = 0, correct = 0, remaining = plannedSize)
        if (sessionCourses.isEmpty()) ui = ui.copy(phase = TrainPhase.empty) else startCourse()
    }

    // MARK: Progression

    /**
     * Note FSRS auto-dérivée pour la position OÙ l'utilisateur devait jouer.
     * Un indice plafonne la note à « Difficile » : se faire souffler la
     * réponse n'est pas s'en souvenir.
     */
    private fun record(rating: FsrsRating) {
        val effective = if (usedHint && rating.raw > FsrsRating.hard.raw) FsrsRating.hard else rating
        val key = currentKey
        val now = System.currentTimeMillis()
        viewModelScope.launch(Dispatchers.IO) {
            val existing = dao.progress(key) ?: OpeningProgress(fenKey = key)
            val outcome = fsrs.review(existing.card, effective, now)
            dao.put(existing.applying(outcome))
            dao.log(OpeningReviewLog(
                fenKey = key, ratingRaw = effective.raw, reviewedAt = outcome.reviewedAt,
                elapsedDays = outcome.elapsedDays, scheduledDays = outcome.scheduledDays,
                stabilityAfter = outcome.stabilityAfter,
            ))
        }
    }
}
