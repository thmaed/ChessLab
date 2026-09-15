package com.chesslab.variants

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.analysis.EvalConversion
import com.chesslab.analysis.MoveClassifier
import com.chesslab.analysis.MoveQuality
import com.chesslab.engine.FairyEngine
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class VariantAnalysisUiState(
    val position: Position = Position.standard,
    val walls: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val sanMoves: List<String> = emptyList(),
    /** Le demi-coup affiché. 0 = position de départ. */
    val displayedPly: Int = 0,
    val evalCp: Int? = null,
    val evalMate: Int? = null,
    val evaluation: String = "",
    val thinking: Boolean = false,
    /** La qualité de chaque coup, par index — vide tant que la passe n'a pas tourné. */
    val qualities: Map<Int, MoveQuality> = emptyMap(),
    val classifying: Boolean = false,
    val done: Int = 0,
    val total: Int = 0,
    val variantName: String = "",
    val engineUnavailable: Boolean = false,
) {
    val totalPlies: Int get() = sanMoves.size
    val canGoPrevious: Boolean get() = displayedPly > 0
    val canGoNext: Boolean get() = displayedPly < totalPlies
    val displayedQuality: MoveQuality? get() = qualities[displayedPly - 1]
}

/**
 * Revoir une partie de VARIANTE. Pendant de `VariantAnalysisViewModel.swift`.
 *
 * L'analyse ordinaire ne sait pas faire : elle juge aux règles orthodoxes, et
 * une position de Horde ou de Roi de la colline n'y veut plus rien dire — le
 * chiffre serait faux, ce qui est pire que pas de chiffre. Celle-ci passe donc
 * par Fairy-Stockfish, à qui l'on dit de quelle variante il s'agit.
 *
 * Volontairement plus SIMPLE que l'analyse orthodoxe : pas d'ouvertures ECO
 * (aucune théorie ne porte sur ces jeux), pas de puzzles, pas de coups
 * candidats. On navigue, on lit l'évaluation, et une passe unique pose les
 * pastilles de qualité.
 */
class VariantAnalysisViewModel(app: Application) : AndroidViewModel(app) {

    private var variantId: String = "chess"
    private var startFen: String? = null
    private var uciLog: List<String> = emptyList()

    /** Une position et ses murs par demi-coup — le moteur les rend avec la FEN. */
    private var fens: List<String> = emptyList()
    private var evalJob: Job? = null
    private var passJob: Job? = null

    /** L'évaluation de chaque position, POV Blancs, en probabilité de gain. */
    private val winPercents = HashMap<Int, Double>()

    var ui by mutableStateOf(VariantAnalysisUiState())
        private set

    /**
     * Charge la partie. [uciLog] vient du mode de jeu : c'est la seule chose
     * qu'il sait dire de sûr — les règles vivent dans le moteur, pas ici.
     */
    fun load(variantId: String, startFen: String?, uciLog: List<String>) {
        if (this.variantId == variantId && this.uciLog == uciLog && fens.isNotEmpty()) return
        this.variantId = variantId
        this.startFen = startFen
        this.uciLog = uciLog
        ui = ui.copy(
            variantName = VariantCatalog.byId(variantId)?.let { s(it.titleRes) } ?: variantId,
            sanMoves = emptyList(), qualities = emptyMap(), displayedPly = 0,
        )
        viewModelScope.launch { rebuild() }
    }

    /**
     * Rejoue la partie AU MOTEUR, demi-coup par demi-coup : c'est lui qui rend
     * la position, les murs et la notation. Rejouer avec `chesskit` donnerait
     * un plateau faux dès la première prise atomique ou le premier mur.
     */
    private suspend fun rebuild() {
        val positions = ArrayList<String>()
        val sans = ArrayList<String>()
        val ok = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                for (ply in 0..uciLog.size) {
                    currentCoroutineContext().ensureActive()
                    val query = engine.queryPosition(variantId, startFen, uciLog.take(ply))
                        ?: return@use false
                    positions += query.fen
                    // La notation d'une variante n'est pas celle de `chesskit` :
                    // on garde le coup en LAN, qui ne ment jamais.
                    if (ply > 0) sans += uciLog[ply - 1]
                }
                true
            }
        } ?: false

        if (!ok) { ui = ui.copy(engineUnavailable = true); return }
        fens = positions
        ui = ui.copy(sanMoves = sans, engineUnavailable = false)
        goTo(sans.size)
        classify()
    }

    fun goTo(ply: Int) {
        val target = ply.coerceIn(0, uciLog.size)
        val fen = fens.getOrNull(target) ?: return
        val position = Position.fromFen(fen) ?: return
        val move = uciLog.getOrNull(target - 1)
        ui = ui.copy(
            position = position,
            walls = BarricadesFen.wallSquares(fen).toSet(),
            displayedPly = target,
            lastMove = move?.takeIf { it.length >= 4 }?.let {
                Square(it.substring(0, 2)) to Square(it.substring(2, 4))
            },
            evalCp = null, evalMate = null, evaluation = "",
        )
        evaluate(target)
    }

    fun previous() = goTo(ui.displayedPly - 1)
    fun next() = goTo(ui.displayedPly + 1)
    fun toStart() = goTo(0)
    fun toEnd() = goTo(uciLog.size)

    /** L'évaluation de la position AFFICHÉE, lue au cache quand la passe l'a vue. */
    private fun evaluate(ply: Int) {
        evalJob?.cancel()
        if (ui.classifying) return
        evalJob = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            val eval = try {
                withContext(Dispatchers.IO) {
                    FairyEngine.use(getApplication()) { engine ->
                        engine.evaluate(
                            variantId, startFen, uciLog.take(ply), LIVE_MS,
                            whiteToMove = fens.getOrNull(ply)?.contains(" w ") == true,
                        )
                    }
                }
            } finally {
                ui = ui.copy(thinking = false)
            } ?: return@launch
            if (ui.displayedPly != ply) return@launch
            ui = ui.copy(
                evalCp = eval.cp, evalMate = eval.mate,
                evaluation = scoreText(eval.cp, eval.mate),
            )
        }
    }

    /**
     * La passe de classification : une recherche COURTE par position, puis le
     * même barème que l'analyse orthodoxe — la perte de probabilité de gain du
     * point de vue de celui qui vient de jouer.
     */
    fun classify() {
        if (ui.classifying || uciLog.isEmpty()) return
        evalJob?.cancel()
        passJob?.cancel()
        passJob = viewModelScope.launch {
            ui = ui.copy(classifying = true, done = 0, total = fens.size)
            try {
                withContext(Dispatchers.IO) {
                    FairyEngine.use(getApplication()) { engine ->
                        for (ply in fens.indices) {
                            currentCoroutineContext().ensureActive()
                            val eval = engine.evaluate(
                                variantId, startFen, uciLog.take(ply), PASS_MS,
                                whiteToMove = fens[ply].contains(" w "),
                            )
                            if (eval != null) winPercents[ply] = winPercent(eval.cp, eval.mate)
                            withContext(Dispatchers.Main) { ui = ui.copy(done = ply + 1) }
                        }
                    }
                }
                publishQualities()
            } finally {
                ui = ui.copy(classifying = false)
                evaluate(ui.displayedPly)
            }
        }
    }

    private fun publishQualities() {
        val qualities = HashMap<Int, MoveQuality>()
        for (index in uciLog.indices) {
            val before = winPercents[index] ?: continue
            val after = winPercents[index + 1] ?: continue
            // Le point de vue de CELUI QUI VIENT DE JOUER : une perte se juge
            // pour lui, pas pour les Blancs.
            val whiteMoved = fens[index].contains(" w ")
            val beforeMover = if (whiteMoved) before else 100 - before
            val afterMover = if (whiteMoved) after else 100 - after
            // Le MÊME barème que l'analyse orthodoxe : les seuils ne
            // dépendent pas des règles du jeu, seulement de ce qu'on a perdu.
            // Ni théorie ni sacrifice ici — aucune théorie ne porte sur ces
            // jeux, et reconnaître un sacrifice demanderait des règles que
            // `chesskit` n'a pas.
            qualities[index] = MoveClassifier.classify(
                MoveClassifier.Input(
                    winPercentBefore = beforeMover,
                    winPercentAfter = afterMover,
                )
            )
        }
        ui = ui.copy(qualities = qualities)
    }

    private fun winPercent(cp: Int?, mate: Int?): Double =
        mate?.let { EvalConversion.fromMate(it) } ?: EvalConversion.fromCentipawns(cp ?: 0)

    private fun scoreText(cp: Int?, mate: Int?): String = when {
        mate != null -> if (mate > 0) "+M$mate" else "−M${-mate}"
        cp != null -> {
            val pawns = cp / 100.0
            if (pawns >= 0) "+%.2f".format(pawns) else "−%.2f".format(-pawns)
        }
        else -> "—"
    }

    override fun onCleared() {
        evalJob?.cancel()
        passJob?.cancel()
        super.onCleared()
    }

    private companion object {
        /** La position affichée : court, elle est réévaluée à chaque navigation. */
        const val LIVE_MS = 500

        /** La passe : plus court encore, il y en a une par demi-coup. */
        const val PASS_MS = 300
    }
}
