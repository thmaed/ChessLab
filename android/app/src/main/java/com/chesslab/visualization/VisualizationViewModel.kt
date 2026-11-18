package com.chesslab.visualization

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.chesslab.sound.Haptics
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.random.Random

enum class VisualizationPhase { setup, playing, finished }

/** Le retour sur une réponse, affiché un instant avant la question suivante. */
data class VFeedback(val given: VAnswer?, val isCorrect: Boolean)

data class VisualizationUi(
    val phase: VisualizationPhase = VisualizationPhase.setup,
    val settings: VisualizationSettings = VisualizationSettings(),
    val stats: VisualizationStats = VisualizationStats(),
    val question: VQuestion? = null,
    val answered: List<VAnswered> = emptyList(),
    val feedback: VFeedback? = null,
    /** Rafraîchi pendant la série, pour les chronos. */
    val now: Long = 0,
    /** Marche 5 : la position est montrée — le chrono de la question attend que le joueur la cache. */
    val isMemorizing: Boolean = false,
    /** Marche 5 : la case de départ touchée sur le plateau caché. */
    val selectedFrom: VSquare? = null,
    /** La bibliothèque de puzzles se charge (marche 5). */
    val preparing: Boolean = false,
) {
    val correctCount: Int get() = answered.count { it.isCorrect }
    val misses: List<VAnswered> get() = answered.filter { !it.isCorrect }
    val reviewCount: Int get() = stats.reviewKeys(settings.kinds).size

    /** Le bilan, exercice par exercice : (exercice, justes, posées), dans l'ordre de l'échelle. */
    val summaryByKind: List<Triple<VisualizationKind, Int, Int>>
        get() = VisualizationKind.entries.mapNotNull { kind ->
            val items = answered.filter { it.question.kind == kind }
            if (items.isEmpty()) null else Triple(kind, items.count { it.isCorrect }, items.size)
        }
}

/**
 * Une série de Visualisation. Pendant de `VisualizationViewModel.swift` : mêmes pauses après une réponse (0,45 s
 * juste, 1,6 s faux), même chrono par question, même minute qui tranche, temps arrêté hors du premier plan.
 */
class VisualizationViewModel(app: Application) : AndroidViewModel(app) {
    var ui by mutableStateOf(VisualizationUi())
        private set

    private var session: Long? = null
    private val rng = Random.Default
    private var seriesElapsedBefore = 0L
    private var questionElapsedBefore = 0L
    private var runningSince: Long? = null
    private var questionSince: Long? = null
    private var ticker: Job? = null
    private var advanceJob: Job? = null
    private var nextId = 0
    /** La bibliothèque de puzzles (marche 5), chargée au premier besoin. */
    private var pool: com.chesslab.puzzles.PuzzleRushPool? = null
    private var puzzleTarget = 900
    private val usedPuzzles = HashSet<String>()

    private fun now() = System.currentTimeMillis()

    /** Une NOUVELLE entrée dans l'écran : les réglages, relus. */
    fun open(session: Long) {
        if (this.session == session) return
        this.session = session
        val app = getApplication<Application>()
        ui = VisualizationUi(settings = VisualizationStore.loadSettings(app), stats = VisualizationStore.loadStats(app))
    }

    // Réglages

    fun updateSettings(settings: VisualizationSettings) {
        ui = ui.copy(settings = settings)
        VisualizationStore.save(getApplication(), settings)
    }

    fun toggle(step: VisualizationStep) {
        val steps = ui.settings.steps
        if (step in steps) {
            // Jamais aucune marche : la dernière reste cochée.
            if (steps.size == 1) return
            updateSettings(ui.settings.copy(steps = steps - step))
        } else {
            updateSettings(ui.settings.copy(steps = steps + step))
        }
    }

    // Le temps

    private fun seriesElapsed(at: Long): Long = seriesElapsedBefore + (runningSince?.let { at - it } ?: 0L)

    /** Série d'une minute : ce qu'il reste, en millisecondes. `null` pour une série en nombre de questions. */
    fun seriesRemainingMs(): Long? {
        val duration = ui.settings.length.durationMs ?: return null
        return (duration - seriesElapsed(ui.now)).coerceAtLeast(0)
    }

    /** Chrono par question : la fraction de temps restante (1 → 0). `null` sans chrono. */
    fun questionTimeFraction(): Float? {
        val base = ui.settings.secondsPerQuestion ?: return null
        if (ui.phase != VisualizationPhase.playing) return null
        val seconds = ui.question?.kind?.seconds(base) ?: return null
        if (ui.isMemorizing) return 1f
        val elapsed = questionElapsedBefore + (questionSince?.let { ui.now - it } ?: 0L)
        return (1f - elapsed / (seconds * 1000f)).coerceAtLeast(0f)
    }

    // La série

    fun start() {
        // Marche 5 : la bibliothèque se charge une fois, en arrière-plan, avant la première question.
        if (ui.settings.steps.contains(VisualizationStep.calculation) && pool == null) {
            if (ui.preparing) return
            ui = ui.copy(preparing = true)
            viewModelScope.launch {
                val app = getApplication<Application>()
                puzzleTarget = maxOf(600, Math.round(com.chesslab.settings.StatsStore.puzzleRating(app).rating).toInt() - 300)
                pool = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    runCatching { com.chesslab.puzzles.PuzzleRushPool.load(app.assets, puzzleTarget) }.getOrNull()
                }
                ui = ui.copy(preparing = false)
                beginSeries()
            }
            return
        }
        beginSeries()
    }

    private fun beginSeries() {
        ticker?.cancel(); advanceJob?.cancel()
        usedPuzzles.clear()
        nextId = 0
        seriesElapsedBefore = 0
        val t = now()
        runningSince = t
        ui = ui.copy(phase = VisualizationPhase.playing, answered = emptyList(), feedback = null, question = null, now = t)
        serveNext()
        startTicker()
    }

    fun answer(given: VAnswer) {
        val question = ui.question ?: return
        if (ui.phase != VisualizationPhase.playing || ui.feedback != null) return
        settle(question, given)
    }

    /** L'app quitte le premier plan : le temps s'arrête. */
    fun pause() {
        val since = runningSince ?: return
        val t = now()
        seriesElapsedBefore += t - since
        questionSince?.let { questionElapsedBefore += t - it }
        runningSince = null
        questionSince = null
        ui = ui.copy(now = t)
    }

    fun resume() {
        if (ui.phase != VisualizationPhase.playing || runningSince != null) return
        val t = now()
        runningSince = t
        questionSince = if (ui.isMemorizing) null else t
        ui = ui.copy(now = t)
    }

    /** Quitter la série en cours : ce qui a été répondu reste compté. */
    fun stop() {
        if (ui.phase == VisualizationPhase.playing) finish()
    }

    fun backToSetup() {
        ticker?.cancel(); advanceJob?.cancel()
        ui = ui.copy(phase = VisualizationPhase.setup, question = null, feedback = null)
    }

    private fun serveNext() {
        val question = VisualizationDrawer.next(ui.settings.kinds, ui.stats, ui.question, rng) { puzzleQuestion(it) }
        val memorizing = question.kind.step == VisualizationStep.calculation
        questionElapsedBefore = 0
        questionSince = if (runningSince != null && !memorizing) now() else null
        ui = ui.copy(question = question, feedback = null, isMemorizing = memorizing, selectedFrom = null)
    }

    // Marche 5

    /** « J'ai mémorisé » : les pièces disparaissent, le chrono de la question part. */
    fun hidePosition() {
        if (!ui.isMemorizing || ui.phase != VisualizationPhase.playing) return
        if (runningSince != null) questionSince = now()
        ui = ui.copy(isMemorizing = false)
    }

    /** Un toucher sur le plateau caché : la case de départ, puis la case d'arrivée qui joue le coup. */
    fun tapCalculationSquare(square: VSquare) {
        val question = ui.question ?: return
        if (ui.phase != VisualizationPhase.playing || ui.feedback != null || ui.isMemorizing ||
            question.kind.step != VisualizationStep.calculation) return
        val from = ui.selectedFrom
        if (from == null) {
            ui = ui.copy(selectedFrom = square)
            return
        }
        ui = ui.copy(selectedFrom = null)
        if (from == square) return
        settle(question, VisualizationCalc.judge(from, square, question))
    }

    /** Un puzzle de la bibliothèque : court, un peu sous le niveau du joueur, jamais deux fois dans la série. */
    private fun puzzleQuestion(kind: VisualizationKind): VQuestion? {
        val pool = pool ?: return null
        repeat(8) {
            val puzzle = pool.next(puzzleTarget, usedPuzzles) ?: return null
            usedPuzzles += puzzle.id
            VisualizationCalc.question(kind, puzzle.fen, puzzle.solution)?.let { return it }
        }
        return null
    }

    private fun settle(question: VQuestion, given: VAnswer?) {
        val item = VAnswered(nextId++, question, given)
        val stats = ui.stats.record(question, item.isCorrect)
        VisualizationStore.save(getApplication(), stats)
        ui = ui.copy(answered = ui.answered + item, stats = stats, feedback = VFeedback(given, item.isCorrect))
        if (item.isCorrect) Haptics.move() else Haptics.illegal()
        advanceJob?.cancel()
        advanceJob = viewModelScope.launch {
            delay(if (item.isCorrect) CORRECT_PAUSE_MS else WRONG_PAUSE_MS)
            advance()
        }
    }

    private fun advance() {
        if (ui.phase != VisualizationPhase.playing) return
        val count = ui.settings.length.questionCount
        val remaining = seriesRemainingMs()
        when {
            count != null && ui.answered.size >= count -> finish()
            remaining != null && remaining <= 0 -> finish()
            else -> serveNext()
        }
    }

    private fun startTicker() {
        ticker?.cancel()
        ticker = viewModelScope.launch {
            while (isActive) {
                delay(100)
                tick()
            }
        }
    }

    private fun tick() {
        if (ui.phase != VisualizationPhase.playing || runningSince == null) return
        ui = ui.copy(now = now())
        val remaining = seriesRemainingMs()
        if (remaining != null && remaining <= 0) {
            // La minute est écoulée : la question en cours ne compte pas.
            finish()
            return
        }
        val fraction = questionTimeFraction()
        val question = ui.question
        if (ui.feedback == null && !ui.isMemorizing && fraction != null && fraction <= 0f && question != null) settle(question, null)
    }

    private fun finish() {
        ticker?.cancel(); advanceJob?.cancel()
        runningSince?.let { seriesElapsedBefore += now() - it }
        runningSince = null
        questionSince = null
        ui = ui.copy(phase = VisualizationPhase.finished, question = null, feedback = null)
        if (ui.answered.isNotEmpty()) Haptics.gameEnded()
    }

    companion object {
        /** Un juste passe vite ; une erreur laisse le temps de lire la bonne réponse. Comme iOS. */
        const val CORRECT_PAUSE_MS = 450L
        const val WRONG_PAUSE_MS = 1_600L
    }
}
