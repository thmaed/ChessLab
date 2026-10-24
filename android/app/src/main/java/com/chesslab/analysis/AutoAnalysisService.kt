package com.chesslab.analysis

import android.app.Application
import android.content.Context
import android.os.PowerManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import chesskit.Piece
import com.chesslab.engine.ThermalMonitor
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * A1 (2.0) — l'analyse AUTOMATIQUE des parties, sans écran. Pendant de
 * `AutoAnalysisService.swift`.
 *
 * Une file de parties, traitées UNE à la fois par un [AnalysisViewModel] que
 * personne ne regarde : il classe la ligne principale, écrit le cache par coup
 * sur le disque et recopie le bilan dans la partie enregistrée. La même passe
 * que l'écran d'analyse, donc les mêmes verdicts.
 *
 * Garde-fous, identiques à iOS : rien sans l'accord de l'utilisateur ; rien en
 * économie d'énergie ni pendant que l'appareil est bridé ; interrompue quand
 * l'app quitte l'avant-plan (reprise au retour) ; arrêtable à tout moment — ce
 * qui est déjà classé reste sur le disque.
 */
object AutoAnalysisService : com.chesslab.engine.EngineService.UserEngineListener {

    init { com.chesslab.engine.EngineService.userListener = this }

    private var resumeJob: Job? = null
    private val failures = HashMap<String, Int>()

    /** Un écran prend le moteur : on s'arrête et on le rend AVANT qu'il ne démarre le sien. */
    override suspend fun userWillUse() {
        resumeJob?.cancel()
        val running = runner ?: return
        running.cancelAndJoin()
    }

    /** Le moteur est rendu ; la reprise attend un peu (on passe d'un écran à l'autre). */
    override fun userDidFinish() {
        resumeJob?.cancel()
        resumeJob = scope.launch {
            delay(3000)
            startIfPossible()
        }
    }


    /** Parties en attente (le PGN fait foi d'identité), la première étant en cours. */
    var queue by mutableStateOf<List<AnalysisJob>>(emptyList())
        private set

    /** Un travail : le PGN fait foi d'identité ; [userColor] = le camp de l'utilisateur (A2). */
    data class AnalysisJob(val pgn: String, val userColor: Piece.Color?)

    /** A2 : au plus ce nombre de puzzles tirés d'une partie, les mats d'abord. */
    const val MAX_PUZZLES_PER_GAME = 3

    /** Puzzles créés depuis la dernière visite des puzzles : la pastille de l'accueil. */
    var newPuzzleCount by mutableStateOf(0)
        private set

    fun loadPending(context: Context) {
        newPuzzleCount = context.getSharedPreferences("auto_analysis", Context.MODE_PRIVATE).getInt("newPuzzles", 0)
    }

    fun acknowledgeNewPuzzles(context: Context) {
        newPuzzleCount = 0
        context.getSharedPreferences("auto_analysis", Context.MODE_PRIVATE).edit().remove("newPuzzles").apply()
    }

    /** Demi-coups classés / total de la partie en cours. */
    var progress by mutableStateOf<Pair<Int, Int>?>(null)
        private set

    var isRunning by mutableStateOf(false)
        private set

    private var foreground = true
    private var app: Application? = null
    private var runner: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** Ajoute une partie à la file (sans doublon) et démarre si possible. */
    fun enqueue(context: Context, pgn: String, userColor: Piece.Color? = null) {
        if (SettingsStore.state.value.autoAnalysis != "on") return
        if (queue.any { it.pgn == pgn }) return
        app = context.applicationContext as Application
        queue = queue + AnalysisJob(pgn, userColor)
        startIfPossible()
    }

    /** Vide la file et interrompt la partie en cours. */
    fun stop() {
        queue = emptyList()
        runner?.cancel()
    }

    /** L'app passe à l'avant-plan ou le quitte. */
    fun setForeground(active: Boolean) {
        foreground = active
        if (active) startIfPossible() else runner?.cancel()
    }

    /** Le réglage vient d'être changé. */
    fun settingChanged() {
        if (SettingsStore.state.value.autoAnalysis == "on") startIfPossible() else stop()
    }

    private fun mayRun(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return SettingsStore.state.value.autoAnalysis == "on" &&
            foreground && !power.isPowerSaveMode && !ThermalMonitor.isThrottling &&
            !com.chesslab.engine.EngineService.isUserActive
    }

    private fun startIfPossible() {
        val application = app ?: return
        if (runner?.isActive == true || queue.isEmpty() || !mayRun(application)) return
        isRunning = true
        runner = scope.launch {
            try {
                drain(application)
            } finally {
                isRunning = false
                progress = null
            }
        }
    }

    private suspend fun drain(application: Application) {
        while (currentCoroutineContext().isActive && queue.isNotEmpty() && mayRun(application)) {
            val job = queue.first()
            val finished = analyze(application, job)
            // Interrompue : la partie reste en tête de file, on la reprendra.
            if (!finished) return
            queue = queue - job
        }
    }

    /** Vrai si la partie est terminée (ou irrécupérable) — faux si interrompue. */
    private suspend fun analyze(application: Application, job: AnalysisJob): Boolean {
        val store = ViewModelStore()
        val viewModel = ViewModelProvider(store, ViewModelProvider.AndroidViewModelFactory(application))[AnalysisViewModel::class.java]
        // AVANT `load()`, qui lance la revue : son moteur cède le pas à tout écran.
        viewModel.isBackground = true
        var finished = false
        var failed = false
        try {
            viewModel.onInputChange(job.pgn)
            viewModel.load()
            // Au plus 10 minutes en tout, et 2 minutes sans le moindre progrès :
            // au-delà, la partie est tenue pour bloquée.
            val deadline = System.currentTimeMillis() + 600_000
            var lastDone = -1
            var lastChange = System.currentTimeMillis()
            while (System.currentTimeMillis() < deadline) {
                if (!currentCoroutineContext().isActive || !mayRun(application)) break
                val ui = viewModel.ui
                if (ui.error != null) { finished = true; break }
                progress = ui.reviewDone to maxOf(1, ui.reviewTotal)
                if (ui.reviewDone != lastDone) { lastDone = ui.reviewDone; lastChange = System.currentTimeMillis() }
                if (System.currentTimeMillis() - lastChange > 120_000) { failed = true; break }
                if (ui.summary?.isComplete == true && !ui.reviewing) {
                    // A2 : ses erreurs et ses mats manqués deviennent des puzzles.
                    job.userColor?.let { color ->
                        val created = viewModel.createOwnPuzzles(color, MAX_PUZZLES_PER_GAME)
                        if (created > 0) {
                            newPuzzleCount += created
                            application.getSharedPreferences("auto_analysis", Context.MODE_PRIVATE)
                                .edit().putInt("newPuzzles", newPuzzleCount).apply()
                        }
                    }
                    finished = true
                    break
                }
                delay(500)
            }
            if (!finished && !failed && System.currentTimeMillis() >= deadline) failed = true
        } finally {
            // Même annulée : vider le magasin annule `viewModelScope`, et la
            // revue sauvegarde ce qu'elle a classé. Le temps laissé à la
            // sauvegarde du bilan (écrite en E/S) ne doit pas être coupé.
            withContext(NonCancellable) {
                delay(300)
                store.clear()
            }
        }
        if (failed) {
            val count = (failures[job.pgn] ?: 0) + 1
            failures[job.pgn] = count
            // Trois échecs : on y renonce, au lieu de réessayer sans fin.
            return count >= 3
        }
        return finished
    }
}
