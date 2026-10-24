package com.chesslab.analysis

import android.app.Application
import android.content.Context
import android.os.PowerManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import com.chesslab.engine.ThermalMonitor
import com.chesslab.settings.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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
object AutoAnalysisService {

    /** Parties en attente (le PGN fait foi d'identité), la première étant en cours. */
    var queue by mutableStateOf<List<String>>(emptyList())
        private set

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
    fun enqueue(context: Context, pgn: String) {
        if (SettingsStore.state.value.autoAnalysis != "on") return
        if (pgn in queue) return
        app = context.applicationContext as Application
        queue = queue + pgn
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
            foreground && !power.isPowerSaveMode && !ThermalMonitor.isThrottling
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
            val pgn = queue.first()
            val finished = analyze(application, pgn)
            // Interrompue : la partie reste en tête de file, on la reprendra.
            if (!finished) return
            queue = queue - pgn
        }
    }

    /** Vrai si la partie est terminée (ou irrécupérable) — faux si interrompue. */
    private suspend fun analyze(application: Application, pgn: String): Boolean {
        val store = ViewModelStore()
        val viewModel = ViewModelProvider(store, ViewModelProvider.AndroidViewModelFactory(application))[AnalysisViewModel::class.java]
        var finished = false
        try {
            viewModel.onInputChange(pgn)
            viewModel.load()
            // Au plus 10 minutes : une partie de 130 demi-coups en prend 4 sur
            // le plus lent des téléphones mesurés.
            val deadline = System.currentTimeMillis() + 600_000
            while (System.currentTimeMillis() < deadline) {
                if (!currentCoroutineContext().isActive || !mayRun(application)) break
                val ui = viewModel.ui
                if (ui.error != null) { finished = true; break }
                progress = ui.reviewDone to maxOf(1, ui.reviewTotal)
                if (ui.summary?.isComplete == true) { finished = true; break }
                delay(500)
            }
            if (!finished && System.currentTimeMillis() >= deadline) finished = true   // trop longue : on renonce
        } finally {
            // La revue ne s'arrête pas d'elle-même : vider le magasin annule
            // `viewModelScope`, et la revue sauvegarde ce qu'elle a classé.
            // Laisser le temps à la sauvegarde du bilan (écrite en E/S).
            delay(300)
            store.clear()
        }
        return finished
    }
}
