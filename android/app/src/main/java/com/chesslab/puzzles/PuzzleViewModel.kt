package com.chesslab.puzzles

import android.app.Application
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.Person
import androidx.compose.ui.graphics.vector.ImageVector
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
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.SettingsStore
import com.chesslab.settings.StatsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.q
import com.chesslab.ui.s

enum class PuzzleOutcome { solving, solved, failed }

/**
 * D'où viennent les puzzles proposés. Pendant de `PuzzleSource` sur iOS, dans
 * le même ordre que ses puces.
 *
 * « Mes parties » regroupe ceux que l'analyse a tirés de vos propres fautes :
 * la position est déjà arrivée sur votre échiquier, et l'erreur est la vôtre.
 */
enum class PuzzleSource(val labelRes: Int) {
    ownGames(R.string.puzzle_source_own),
    lichess(R.string.puzzle_source_lichess);

    /** Les mêmes symboles qu'iOS (`person.fill`, `books.vertical.fill`). */
    val icon: ImageVector
        get() = when (this) {
            ownGames -> Icons.Default.Person
            lichess -> Icons.Default.LibraryBooks
        }
}

data class PuzzleUiState(
    val position: Position = Position.standard,
    val puzzle: Puzzle? = null,
    val orientation: Piece.Color = Piece.Color.white,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val outcome: PuzzleOutcome = PuzzleOutcome.solving,
    val solvedCount: Int = 0,
    val attemptedCount: Int = 0,
    val pendingPromotion: Move? = null,
    val loading: Boolean = true,
    val busy: Boolean = false,
    /** Essais restants sur le puzzle courant (réglage : un ou trois). */
    val attemptsLeft: Int = 1,
    /** Essais permis : ce que le réglage accorde, pour dessiner les pastilles. */
    val allowedAttempts: Int = 1,
    /** Les deux cases du coup soufflé, quand l'utilisateur l'a demandé. */
    val hint: Pair<Square, Square>? = null,
    val filter: PuzzleFilter = PuzzleFilter(),
    /** Le bilan : réussite et thèmes à travailler. `null` tant que rien n'est tenté. */
    val stats: com.chesslab.progression.PuzzleStats? = null,
    /** Combien de puzzles attendent d'être revus. */
    val dueCount: Int = 0,
    /** Le plan du programme Woodpecker joué, `null` pour une série ordinaire. */
    val woodpeckerPlan: WoodpeckerPlan? = null,
)

/**
 * Compose une file de puzzles pour un filtre — la série ordinaire, ou le lot
 * d'un programme Woodpecker ([count]). Pendant de `PuzzleSessionDrawer` (iOS).
 */
object PuzzleDraw {
    suspend fun draw(
        app: Application,
        filter: PuzzleFilter,
        own: List<OwnPuzzle>,
        /** `null` : la série ordinaire (40 de la bibliothèque, tous les vôtres). */
        count: Int? = null,
    ): List<Puzzle> = withContext(Dispatchers.IO) {
        val db = LibraryDatabase.get(app)
        val mine = if (filter.source == PuzzleSource.lichess) emptyList()
            else own.map { it.toPuzzle() }.filter { PuzzleAnswer.accepts(it, filter, isOwn = true) }
        runCatching {
            when {
                // Les ratés, dus ou non : la progression dit lesquels, la
                // bibliothèque et vos puzzles maison disent ce qu'ils sont.
                filter.missedOnly -> {
                    val missed = db.puzzleProgress().missedIds().toSet()
                    val library = if (filter.source == PuzzleSource.ownGames) emptyList()
                        else PuzzleRepository.byIds(app.assets, missed)
                            .filter { PuzzleAnswer.accepts(it, filter, isOwn = false) }
                    val all = (mine.filter { it.id in missed } + library).shuffled()
                    if (count != null) all.take(count) else all
                }
                filter.source == PuzzleSource.ownGames ->
                    if (count != null) mine.shuffled().take(count) else mine
                else -> PuzzleRepository.sample(
                    app.assets,
                    count = count ?: 40,
                    ratings = filter.ratings,
                    theme = filter.theme?.raw,
                    phase = filter.phase?.raw,
                    extra = mine,
                )
            }
        }.getOrDefault(emptyList())
    }
}

/**
 * Résoudre des puzzles. Pendant réduit de `PuzzleSolveViewModel.swift`.
 *
 * Convention de la bibliothèque : la FEN est DÉJÀ au trait du résolveur, et
 * `solutionLANs` commence par SON coup. L'app joue donc les coups d'index
 * impair (les ripostes) et attend ceux d'index pair.
 */
class PuzzleViewModel(app: Application) : AndroidViewModel(app) {

    private var queue: List<Puzzle> = emptyList()
    private var cursor = 0
    private var board = Board()
    private var step = 0

    var ui by mutableStateOf(PuzzleUiState(status = s(R.string.puzzle_loading)))
        private set

    init { load(PuzzleFilter()) }

    /**
     * Une série sur UN thème — l'entrée depuis la progression (« à travailler »).
     * Toutes provenances, comme iOS (`PuzzleSessionFilter(theme:)`).
     */
    fun trainTheme(raw: String) {
        val kind = PuzzleThemeKind.entries.firstOrNull { it.raw == raw } ?: return
        setFilter(PuzzleFilter(theme = kind))
    }

    /** Change de filtre : la file se reconstitue autour de ce qu'on demande. */
    fun setFilter(filter: PuzzleFilter) {
        // Ce view model vit autant que l'activité : sortir d'un programme
        // Woodpecker pour une série ordinaire doit recharger, même à filtre égal.
        if (filter == ui.filter && program == null) return
        load(filter)
    }

    // MARK: Woodpecker

    /** Le programme joué, `null` pour une série ordinaire. Pendant du mode programme d'iOS. */
    private var program: WoodpeckerProgram? = null
    /** Chrono du puzzle courant : temps ACTIF, en pause hors du premier plan. */
    private var clockStartedAt: Long? = null
    private var clockAccumulatedMs = 0L

    /**
     * Ouvre un programme sur son puzzle courant. Un cycle bouclé et laissé là
     * repart sur le suivant : revenir au programme, c'est vouloir continuer.
     */
    fun openWoodpecker(id: String) {
        if (program?.id == id && ui.woodpeckerPlan != null) return
        loading?.cancel()
        loading = viewModelScope.launch {
            val dao = LibraryDatabase.get(getApplication()).woodpecker()
            val stored = withContext(Dispatchers.IO) { dao.byId(id) }
            var plan = stored?.plan
            if (stored == null || plan == null) {
                ui = ui.copy(loading = false, puzzle = null, woodpeckerPlan = null, status = s(R.string.woodpecker_missing))
                return@launch
            }
            program = stored
            if (plan.currentCycle.isComplete) {
                plan = plan.startNextCycle()
                persist(plan)
            }
            ui = ui.copy(loading = false, woodpeckerPlan = plan, hint = null)
            presentWoodpecker()
        }
    }

    private fun presentWoodpecker() {
        val plan = ui.woodpeckerPlan ?: return
        val index = plan.currentItemIndex ?: return
        queue = listOf(plan.items[index].toPuzzle(index))
        present(0)
        clockAccumulatedMs = 0
        clockStartedAt = System.currentTimeMillis()
    }

    /** La réponse va au PROGRAMME — jamais à la répétition espacée, ni aux stats. */
    private fun recordWoodpecker(solved: Boolean) {
        val plan = ui.woodpeckerPlan ?: return
        val seconds = elapsedOnPuzzleMs() / 1000.0
        clockStartedAt = null
        clockAccumulatedMs = 0
        val next = plan.record(solved, seconds)
        ui = ui.copy(woodpeckerPlan = next)
        persist(next)
    }

    private fun persist(plan: WoodpeckerPlan) {
        val current = program ?: return
        val updated = current.copy(planJson = plan.toJson(), updatedAt = System.currentTimeMillis())
        program = updated
        viewModelScope.launch(Dispatchers.IO) {
            LibraryDatabase.get(getApplication()).woodpecker().put(updated)
        }
    }

    /** Lance le cycle suivant sur le même lot, dans un nouvel ordre. */
    fun startNextCycle() {
        val plan = ui.woodpeckerPlan ?: return
        if (!plan.currentCycle.isComplete) return
        val next = plan.startNextCycle()
        ui = ui.copy(woodpeckerPlan = next)
        persist(next)
        presentWoodpecker()
    }

    fun pauseClock() {
        val started = clockStartedAt ?: return
        clockAccumulatedMs += System.currentTimeMillis() - started
        clockStartedAt = null
    }

    fun resumeClock() {
        if (ui.woodpeckerPlan == null || ui.outcome != PuzzleOutcome.solving || clockStartedAt != null) return
        clockStartedAt = System.currentTimeMillis()
    }

    private fun elapsedOnPuzzleMs(now: Long = System.currentTimeMillis()): Long =
        clockAccumulatedMs + (clockStartedAt?.let { now - it } ?: 0L)

    /** Temps actif du cycle, puzzle en cours compris — le chrono affiché. */
    fun cycleElapsedSeconds(now: Long = System.currentTimeMillis()): Double {
        val plan = ui.woodpeckerPlan ?: return 0.0
        val running = if (ui.outcome == PuzzleOutcome.solving) elapsedOnPuzzleMs(now) / 1000.0 else 0.0
        return plan.currentCycle.activeSeconds + running
    }

    /**
     * Le chargement en cours. Un nouveau filtre ANNULE le précédent : `init`
     * charge sans filtre et l'écran pose le sien aussitôt — deux passes sur la
     * bibliothèque, et la plus lente des deux écrasait la file de l'autre.
     */
    private var loading: Job? = null

    private fun load(filter: PuzzleFilter) {
        program = null
        clockStartedAt = null
        ui = ui.copy(woodpeckerPlan = null)
        loading?.cancel()
        loading = viewModelScope.launch { fill(filter) }
    }

    private suspend fun fill(filter: PuzzleFilter) {
        ui = ui.copy(loading = true, filter = filter, hint = null)
        val app = getApplication<Application>()
        val db = LibraryDatabase.get(app)
        val own = withContext(Dispatchers.IO) { runCatching { db.ownPuzzles().all() }.getOrDefault(emptyList()) }
        val due = withContext(Dispatchers.IO) {
            runCatching { db.puzzleProgress().dueCount(System.currentTimeMillis()) }.getOrDefault(0)
        }
        // Le bilan, recalculé depuis la progression — jamais un compteur qui
        // dérive de ce qu'il compte.
        val stats = withContext(Dispatchers.IO) {
            runCatching { com.chesslab.progression.PuzzleStats.compute(db.puzzleProgress().all()) }.getOrNull()
        }
        queue = PuzzleDraw.draw(app, filter, own)
        ui = ui.copy(loading = false, dueCount = due, stats = stats)
        if (queue.isEmpty()) {
            ui = ui.copy(
                puzzle = null,
                status = s(
                    when {
                        filter.missedOnly -> R.string.puzzle_no_missed
                        filter.source == PuzzleSource.ownGames && own.isEmpty() -> R.string.puzzle_no_own
                        !filter.isEmpty -> R.string.puzzle_none_match
                        else -> R.string.puzzle_library_unavailable
                    }
                ),
            )
        } else {
            present(0)
        }
    }

    /**
     * Range le résultat, et programme la prochaine rencontre. Ce qu'on vient
     * de rater revient demain ; ce qu'on a résolu s'éloigne.
     */
    private fun recordProgress(puzzle: Puzzle, success: Boolean) = viewModelScope.launch(Dispatchers.IO) {
        val dao = LibraryDatabase.get(getApplication()).puzzleProgress()
        val now = System.currentTimeMillis()
        val current = dao.byId(puzzle.id) ?: PuzzleProgress(externalId = puzzle.id, theme = puzzle.theme)
        val next = PuzzleSchedule.next(current, success)
        dao.put(next.copy(dueAt = PuzzleSchedule.dueAt(next, now), updatedAt = now, theme = puzzle.theme, rating = puzzle.rating))
        ui = ui.copy(stats = com.chesslab.progression.PuzzleStats.compute(dao.all()))
    }

    private fun present(index: Int) {
        cursor = index.coerceIn(queue.indices)
        val puzzle = queue[cursor]
        val position = Position.fromFen(puzzle.fen) ?: return
        board = Board(position)
        step = 0

        ui = ui.copy(
            puzzle = puzzle,
            position = board.position,
            orientation = board.position.sideToMove,
            selected = null,
            legalTargets = emptySet(),
            lastMove = null,
            checkedKing = null,
            outcome = PuzzleOutcome.solving,
            attemptsLeft = SettingsStore.state.value.puzzleAttempts,
            allowedAttempts = SettingsStore.state.value.puzzleAttempts,
            hint = null,
            // Cote 0 = SANS cote : c'est le cas des puzzles maison, dont la
            // difficulté n'a jamais été mesurée. Afficher « · 0 » donnerait un
            // chiffre pour une chose qu'on ne sait pas.
            status = if (puzzle.rating > 0)
                s(R.string.puzzle_prompt, s(puzzle.themeLabel), puzzle.rating)
            else s(R.string.puzzle_prompt_unrated, s(puzzle.themeLabel)),
        )
    }

    fun next() {
        if (queue.isEmpty()) return
        // Programme : le puzzle suivant DU CYCLE ; en fin de cycle, l'écran
        // montre le bilan et c'est `startNextCycle` qui repart.
        ui.woodpeckerPlan?.let { plan ->
            if (plan.currentItemIndex != null && ui.outcome != PuzzleOutcome.solving) presentWoodpecker()
            return
        }
        // Série « Ratés » : un puzzle réussi n'est plus raté, il quitte la
        // file — iOS ne le retirerait plus de la base.
        if (ui.filter.missedOnly && ui.outcome == PuzzleOutcome.solved) {
            queue = queue.filterIndexed { index, _ -> index != cursor }
            if (queue.isEmpty()) {
                ui = ui.copy(puzzle = null, status = s(R.string.puzzle_no_missed))
                return
            }
            present(cursor % queue.size)
            return
        }
        present((cursor + 1) % queue.size)
    }

    fun onSquareTap(square: Square) {
        val puzzle = ui.puzzle ?: return
        if (ui.outcome != PuzzleOutcome.solving || ui.busy || ui.pendingPromotion != null) return

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            attempt(selected, square, puzzle)
            return
        }

        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == board.position.sideToMove) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun attempt(from: Square, to: Square, puzzle: Puzzle) {
        val expected = puzzle.solution.getOrNull(step) ?: return
        val played = from.notation + to.notation

        // On compare AVANT de jouer : un coup faux ne doit pas salir le plateau.
        // Un autre coup qui mate reste juste (voir `PuzzleAnswer.deliversMate`) ;
        // une promotion hors solution attend le choix de la pièce pour être jugée.
        val isExpected = expected.startsWith(played)
        if (!isExpected) {
            val promotes = board.position.piece(from)?.kind == Piece.Kind.pawn && to.rank.value in setOf(1, 8)
            if (!promotes && !PuzzleAnswer.deliversMate(board.position, from, to)) {
                registerWrongAttempt(expected)
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
        advance(move, puzzle)
    }

    /**
     * Toucher à côté ANNULE : le coup n'est pas joué, et il ne compte pas
     * comme un essai. Promouvoir en dame à la place de quelqu'un qui n'a pas
     * encore choisi serait lui faire rater le puzzle.
     */
    fun cancelPromotion() {
        if (ui.pendingPromotion == null) return
        board = Board(ui.position.copy())
        ui = ui.copy(pendingPromotion = null, selected = null, legalTargets = emptySet())
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val puzzle = ui.puzzle ?: return
        val move = board.completePromotion(of = pending, to = kind)
        ui = ui.copy(pendingPromotion = null)
        val expected = puzzle.solution.getOrNull(step) ?: return
        val played = pending.start.notation + pending.end.notation
        // Promotion hors solution : juste seulement si elle mate. Sinon le
        // plateau revient à la position d'avant, comme pour un coup faux.
        if (!expected.startsWith(played) && board.state !is Board.State.Checkmate) {
            board = Board(ui.position.copy())
            registerWrongAttempt(expected)
            return
        }
        step++
        advance(move, puzzle)
    }

    private fun registerWrongAttempt(expected: String) {
        val left = ui.attemptsLeft - 1
        ui = if (left > 0) {
            ui.copy(
                selected = null, legalTargets = emptySet(),
                attemptsLeft = left,
                status = q(R.plurals.puzzle_wrong_tries, left, left),
            )
        } else {
            com.chesslab.sound.Haptics.illegal()
            if (ui.woodpeckerPlan != null) recordWoodpecker(solved = false)
            else {
                StatsStore.recordPuzzle(getApplication(), solvedIt = false)
                ui.puzzle?.let { recordProgress(it, success = false) }
            }
            ui.copy(
                selected = null, legalTargets = emptySet(),
                outcome = PuzzleOutcome.failed,
                attemptedCount = ui.attemptedCount + 1,
                status = s(R.string.puzzle_wrong_solution, expected),
            )
        }
    }

    /** Le coup du résolveur est joué : on enchaîne la riposte, ou on conclut. */
    private fun advance(move: Move, puzzle: Puzzle) {
        show(move, s(R.string.puzzle_good))

        // Un mat clôt le puzzle même s'il restait des coups à la séquence.
        if (step >= puzzle.solution.size || board.state is Board.State.Checkmate) {
            com.chesslab.sound.Haptics.gameEnded()
            if (ui.woodpeckerPlan != null) recordWoodpecker(solved = true)
            else {
                StatsStore.recordPuzzle(getApplication(), solvedIt = true)
                recordProgress(puzzle, success = true)
            }
            ui = ui.copy(
                outcome = PuzzleOutcome.solved,
                solvedCount = ui.solvedCount + 1,
                attemptedCount = ui.attemptedCount + 1,
                status = s(R.string.puzzle_solved),
            )
            return
        }

        viewModelScope.launch {
            ui = ui.copy(busy = true)
            delay(450)                      // le temps de voir le coup
            val lan = puzzle.solution[step]
            var reply = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            if (reply != null && lan.length == 5) {
                reply = board.completePromotion(of = reply, to = kindOf(lan[4]))
            }
            step++
            ui = ui.copy(busy = false, hint = null)
            if (reply != null) show(reply, s(R.string.your_turn))
        }
    }

    /**
     * Montre le coup à jouer, sans le jouer : l'utilisateur garde la main, et
     * son essai reste entier. C'est un coup de pouce, pas une reddition.
     */
    fun showHint() {
        if (ui.outcome != PuzzleOutcome.solving) return
        val puzzle = ui.puzzle ?: return
        val lan = puzzle.solution.getOrNull(step) ?: return
        if (lan.length < 4) return
        ui = ui.copy(hint = Square(lan.substring(0, 2)) to Square(lan.substring(2, 4)))
    }

    private fun show(move: Move, status: String) {
        val state = board.state
        val checked = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }
        ui = ui.copy(
            position = board.position,
            selected = null,
            legalTargets = emptySet(),
            lastMove = move.start to move.end,
            checkedKing = checked,
            status = if (ui.outcome == PuzzleOutcome.solving) status else ui.status,
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
}
