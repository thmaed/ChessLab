package com.chesslab.lab

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
import com.chesslab.engine.EngineService
import com.chesslab.library.GameRecorder
import com.chesslab.maia.MaiaOpponent
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.s

/** Un camp du laboratoire : un personnage, ou Stockfish à un temps donné. */
data class LabSide(val profile: OpponentProfile?, val level: Double) {
    /** Le nom affiché demande un contexte : le surnom est une ressource. */
    fun label(context: android.content.Context): String =
        profile?.displayName(context) ?: context.getString(R.string.stockfish)
}

data class LabUiState(
    val position: Position = Position.standard,
    val lastMove: Pair<Square, Square>? = null,
    val sanMoves: List<String> = emptyList(),
    val sideA: LabSide = LabSide(OpponentGallery.all.first(), 1800.0),
    val sideB: LabSide = LabSide(null, 1500.0),
    val movetimeMs: Int = 200,
    /**
     * Le nombre de parties de la série. La série S'ARRÊTE quand il est
     * atteint : sans borne, on lançait un laboratoire qui tournait jusqu'à ce
     * qu'on y repense, et le bilan ne voulait plus rien dire — deux séries ne
     * se comparaient pas.
     */
    val gameCount: Int = 20,
    /**
     * Alterner la couleur de A d'une partie à l'autre. Recommandé : sans
     * cela, l'avantage du trait se glisse entier dans l'écart mesuré.
     */
    val alternateColors: Boolean = true,
    /**
     * L'abandon d'un camp nettement perdant, plutôt que de jouer jusqu'au
     * mat. Sur une série de cent parties, les finales jouées jusqu'au bout
     * coûtent plus de temps que tout le reste.
     */
    val resignationEnabled: Boolean = true,
    /** La nulle par accord sur une position durablement nulle. */
    val drawAgreementEnabled: Boolean = true,
    /**
     * Animer le plateau coup par coup. Décoché, la série défile au plus vite —
     * c'est le mode « je veux le chiffre, pas le spectacle ».
     */
    val liveVisualization: Boolean = true,
    /**
     * Le livre d'ouvertures, camp par camp. Sans lui, deux moteurs rejouent
     * indéfiniment la même ouverture et la série mesure une seule position
     * plutôt qu'une force.
     */
    val bookA: Boolean = true,
    val bookB: Boolean = true,
    /** L'ampleur du livre : lignes principales, ou variantes comprises. */
    val bookWidth: com.chesslab.play.BookWidth = com.chesslab.play.BookWidth.includeSidelines,
    /**
     * Empêcher la mise en veille pendant la série. `null` = le défaut suit la
     * LONGUEUR : au-delà d'une vingtaine de parties l'appareil s'endormirait à
     * coup sûr avant la fin ; en deçà, on ne prend pas la main sur un réglage
     * système que personne n'a demandé. Renseigné dès que l'utilisateur y
     * touche — et son choix tient alors, même s'il change la longueur.
     */
    val keepAwakeSetting: Boolean? = null,
    val running: Boolean = false,
    val status: String = "",
    /** Les parties TERMINÉES de la série : c'est d'elles que tout se déduit. */
    val completed: List<LabCompletedGame> = emptyList(),
    val gameNumber: Int = 0,
    /** Les couleurs alternent d'une partie à l'autre, comme sur iOS. */
    val aPlaysWhite: Boolean = true,
    /** La position imposée à la série, quand elle n'est pas la position standard. */
    val startFen: String? = null,
    /**
     * Une série de CHESS960 : Stockfish seul (ni livre ni personnage), une position
     * par paire de parties — ou le numéro [chess960Number] pour toutes. Pendant de
     * `LabGameSettings.chess960Enabled`.
     */
    val chess960: Boolean = false,
    val chess960Number: Int? = null,
    val chess960Seed: Long = 0L,
    /** Le numéro de la position de la partie EN COURS, pour l'afficher. */
    val chess960Current: Int? = null,
    /**
     * Une série INTERROMPUE retrouvée sur le disque : une bannière propose de
     * la reprendre. `null` dès qu'on a tranché — repris ou écarté.
     */
    val resumable: LabAutosave.Snapshot? = null,
) {
    /**
     * Le bilan, RECALCULÉ à partir des parties plutôt que compté au fil de
     * l'eau : un compteur et une liste finissent par diverger, et c'est le
     * genre de divergence qu'on ne voit pas — les chiffres restent
     * plausibles.
     */
    val keepAwake: Boolean get() = keepAwakeSetting ?: (gameCount > 20)

    /** Les réglages seuls, tels qu'ils s'écrivent sur le disque. */
    val seriesSettings: LabSeriesSettings
        get() = LabSeriesSettings(
            sideAProfileId = sideA.profile?.id, sideBProfileId = sideB.profile?.id,
            sideALevel = sideA.level, sideBLevel = sideB.level,
            movetimeMs = movetimeMs, gameCount = gameCount,
            alternateColors = alternateColors, resignationEnabled = resignationEnabled,
            drawAgreementEnabled = drawAgreementEnabled, liveVisualization = liveVisualization,
            bookA = bookA, bookB = bookB, bookWidth = bookWidth,
            keepAwakeSetting = keepAwakeSetting, startFen = startFen,
            chess960 = chess960, chess960Number = chess960Number, chess960Seed = chess960Seed,
        )

    /**
     * Un camp proche du maximum ET moins d'une demi-seconde par coup : le
     * temps court bride surtout le camp fort, et l'écart réel sera plus petit
     * que l'écart affiché. L'écran le dit plutôt que de laisser conclure.
     */
    val shortTimeWarning: Boolean
        get() = movetimeMs < 500 &&
            (sideA.profile == null && sideA.level >= 2800 || sideB.profile == null && sideB.level >= 2800)

    val stats: LabStats
        get() = LabStats.of(completed.map { it.labResult }, completed.map { it.plyCount })

    val winsA: Int get() = stats.winsA
    val draws: Int get() = stats.draws
    val winsB: Int get() = stats.winsB
}

/**
 * Le laboratoire : l'ordinateur contre lui-même, en série.
 *
 * Pendant réduit de `LabRunView` / `LabGameSettings`. Les couleurs alternent
 * d'une partie à l'autre — sans quoi l'avantage du trait fausserait le bilan.
 */
class LabViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    private val history = mutableListOf(Position.standard)

    /** La position de départ de CHAQUE partie de la série. */
    private var startPosition: Position = Position.standard

    /**
     * L'HISTOIRE de la partie en cours, et pas seulement sa position : c'est
     * elle qui rend un PGN, donc l'export. Le plateau, lui, ne sait rien du
     * chemin parcouru.
     */
    private var recorder = GameRecorder()
    private var maia: MaiaOpponent? = null
    private var loop: Job? = null

    var ui by mutableStateOf(LabUiState(status = s(R.string.lab_ready)))
        private set

    init {
        viewModelScope.launch {
            maia = withContext(Dispatchers.IO) {
                MaiaOpponent.shared(getApplication(), EngineService.threads)
            }
        }
    }

    /**
     * Impose la position de départ de la série. Sans effet en cours de
     * série : changer le point de départ au milieu d'un bilan le fausserait.
     */
    fun startFrom(fen: String) {
        val position = Position.fromFen(fen) ?: return
        if (ui.running || position.fen == startPosition.fen) return
        startPosition = position
        ui = ui.copy(startFen = position.fen.takeIf { it != Position.standard.fen }, chess960 = false, chess960Current = null)
        reset()
    }

    /** Revenir à la position standard : la série repart de zéro. */
    fun clearStartPosition() {
        if (ui.running || ui.startFen == null) return
        startPosition = Position.standard
        ui = ui.copy(startFen = null)
        reset()
    }

    fun setSideA(profile: OpponentProfile?) { ui = ui.copy(sideA = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setSideB(profile: OpponentProfile?) { ui = ui.copy(sideB = LabSide(profile, profile?.defaultLevel ?: 1500.0)) }
    fun setLevelA(level: Double) { ui = ui.copy(sideA = ui.sideA.copy(level = level)) }
    fun setLevelB(level: Double) { ui = ui.copy(sideB = ui.sideB.copy(level = level)) }
    fun setMovetime(ms: Int) { ui = ui.copy(movetimeMs = ms.coerceIn(50, 5_000)) }
    fun setGameCount(count: Int) { ui = ui.copy(gameCount = count.coerceIn(1, 500)) }
    fun setBookA(on: Boolean) { ui = ui.copy(bookA = on) }
    fun setBookB(on: Boolean) { ui = ui.copy(bookB = on) }
    fun setBookWidth(width: com.chesslab.play.BookWidth) { ui = ui.copy(bookWidth = width) }
    fun setAlternateColors(on: Boolean) { ui = ui.copy(alternateColors = on) }
    fun setResignation(on: Boolean) { ui = ui.copy(resignationEnabled = on) }
    fun setDrawAgreement(on: Boolean) { ui = ui.copy(drawAgreementEnabled = on) }
    fun setLiveVisualization(on: Boolean) { ui = ui.copy(liveVisualization = on) }
    fun setKeepAwake(on: Boolean) { ui = ui.copy(keepAwakeSetting = on) }

    /**
     * Chess960 : un choix de série, sans effet en cours de route (changer de jeu
     * au milieu d'un bilan le fausserait). Il remplace la position personnalisée,
     * et la graine est tirée ICI — une série reprise rejoue les mêmes positions.
     */
    fun setChess960(on: Boolean) {
        if (ui.running || ui.chess960 == on) return
        if (on) {
            startPosition = Position.standard
            ui = ui.copy(chess960 = true, startFen = null, chess960Seed = kotlin.random.Random.nextLong())
        } else {
            ui = ui.copy(chess960 = false, chess960Current = null)
        }
        reset()
    }

    /** `null` : une position différente par paire de parties. */
    fun setChess960Number(number: Int?) {
        if (ui.running) return
        ui = ui.copy(chess960Number = number?.coerceIn(0, 959))
        reset()
    }

    fun toggle() {
        if (ui.running) { stop(); return }
        ui = ui.copy(running = true, status = s(R.string.lab_running))
        loop = viewModelScope.launch { if (ui.chess960) runChess960Series() else runSeries() }
    }

    fun stop() {
        loop?.cancel()
        loop = null
        ui = ui.copy(running = false, status = s(R.string.lab_paused))
    }

    fun reset() {
        stop()
        LabAutosave.clear(getApplication())
        c960Start = null
        ui = ui.copy(
            completed = emptyList(), gameNumber = 0, aPlaysWhite = true,
            resumable = null, status = s(R.string.lab_ready),
        )
        if (ui.chess960) previewChess960(0) else newGame()
    }

    private fun newGame() {
        recentEvals.clear()
        board = Board(startPosition)
        history.clear()
        history += startPosition
        recorder.reset(startPosition, startFen = ui.startFen)
        ui = ui.copy(position = startPosition, lastMove = null, sanMoves = emptyList())
    }

    private suspend fun runSeries() {
        while (viewModelScope.isActive && ui.running) {
            // La série s'arrête d'elle-même : c'est ce qui rend deux bilans
            // comparables.
            if (ui.completed.size >= ui.gameCount) {
                ui = ui.copy(running = false, status = s(R.string.lab_series_done, ui.completed.size))
                return
            }
            val forced = forcedOutcome()
            if (forced != null || board.state is Board.State.Checkmate || board.state is Board.State.Draw) {
                tally(forced)
                newGame()
                ui = ui.copy(
                    gameNumber = ui.gameNumber + 1,
                    aPlaysWhite = if (ui.alternateColors) !ui.aPlaysWhite else ui.aPlaysWhite,
                )
                continue
            }
            if (!step()) { stop(); return }
            // Mode rapide : sans animation, la série défile au plus vite. Avec,
            // on laisse le temps de VOIR le coup.
            if (ui.liveVisualization) kotlinx.coroutines.delay(120)
        }
    }

    /**
     * L'abandon et la nulle par accord — ce qu'un moteur ne déclare pas tout
     * seul. Le critère est l'évaluation SOUTENUE : un camp à moins de huit
     * pions pendant plusieurs coups abandonne, deux camps à zéro pendant
     * plusieurs coups conviennent d'une nulle. Sans cela, une série de cent
     * parties passe l'essentiel de son temps sur des finales déjà jouées.
     */
    private fun forcedOutcome(): String? = agreedOutcome(recentEvals, ui.sanMoves.size)

    /**
     * L'abandon et la nulle par accord sur des évaluations au point de vue des BLANCS — comme iOS
     * (`resignationOrAgreedDraw`) : fenêtre de 6 demi-coups à ±8 pions pour l'abandon, de 10 à ±15 cp
     * après 60 demi-coups pour la nulle. Les évaluations arrivaient au point de vue du camp AU TRAIT,
     * donc de signe alternant : « toutes ≤ −800 » n'était jamais vrai, et l'abandon ne se déclenchait
     * pas (revue du 08/11/2026).
     */
    private fun agreedOutcome(whiteEvals: List<Int>, plies: Int): String? =
        AgreedOutcome.of(whiteEvals, plies, ui.resignationEnabled, ui.drawAgreementEnabled)

    /** Les dernières évaluations, DU POINT DE VUE du camp au trait. */
    private val recentEvals = ArrayDeque<Int>()

    /** Un demi-coup. `false` si personne n'a su répondre. */
    private suspend fun step(): Boolean {
        val whiteIsA = ui.aPlaysWhite
        val toMove = board.position.sideToMove
        val isA = (toMove == Piece.Color.white) == whiteIsA
        val side = if (isA) ui.sideA else ui.sideB

        // Le LIVRE d'abord : tant qu'on est dans l'arbre connu, le coup vient
        // de là et le moteur ne cherche pas. C'est ce qui VARIE les ouvertures
        // d'une partie à l'autre — sans lui, deux Stockfish rejouent la même
        // et la série mesure une position, pas une force.
        bookMove(side, isA)?.let { bookLan ->
            if (applyMove(bookLan, side)) return true
        }

        val lan = withContext(Dispatchers.IO) {
            val profile = side.profile
            val engine = maia
            if (profile != null && engine != null) {
                val mood = profile.mood(null)
                engine.chooseMove(
                    history = history.toList(),
                    board = Board(board.position.copy()),
                    selfElo = side.level, oppoElo = side.level,
                    temperature = mood.temperature, topP = profile.topP, style = mood.style,
                )?.uci
            } else {
                EngineService.use(getApplication()) { e ->
                    e.send("position fen ${board.position.fen}")
                    // Une série fait tourner le moteur des minutes durant :
                    // c'est l'usage qui fait le plus chauffer l'appareil, et
                    // celui où lever le pied soi-même vaut mieux que se
                    // faire brider par le système.
                    val budget = com.chesslab.engine.ThermalMonitor.movetimeMs(ui.movetimeMs)
                    e.search("go movetime $budget", timeoutMs = 60_000)
                }?.split(" ")?.getOrNull(1)
            }
        } ?: return false

        return applyMove(lan, side)
    }

    /**
     * Le coup du livre pour ce camp, ou `null` — livre coupé, position de
     * départ personnalisée (le livre part de la position initiale et n'aurait
     * aucun sens ailleurs), ou position sortie de l'arbre connu.
     *
     * Un personnage a SON répertoire : c'est son caractère, pas un réglage, et
     * il ne se coupe donc pas — même règle qu'en mode « Contre l'ordinateur ».
     */
    private fun bookMove(side: LabSide, isA: Boolean): String? {
        if (ui.startFen != null) return null
        val assets = getApplication<Application>().assets
        val own = side.profile?.id?.let { com.chesslab.play.OpeningBookStore.forOpponent(assets, it) }
        val roots: List<com.chesslab.play.BookNode>
        val width: com.chesslab.play.BookWidth
        if (own != null && maia != null) {
            roots = own
            width = com.chesslab.play.BookWidth.includeSidelines
        } else {
            val enabled = if (isA) ui.bookA else ui.bookB
            if (!enabled) return null
            roots = com.chesslab.play.OpeningBookStore.general(assets)
            width = ui.bookWidth
        }
        val san = com.chesslab.play.OpeningBookPicker.pick(roots, ui.sanMoves, width) ?: return null
        // Le SAN vient d'un fichier : il peut ne pas être jouable ici. On le
        // vérifie sur le plateau plutôt que de faire confiance au fichier.
        return chesskit.SanParser.parse(san, board.position)?.lan
    }

    /** Pose un coup en LAN sur le plateau et publie l'état. `false` s'il est refusé. */
    private suspend fun applyMove(lan: String, side: LabSide): Boolean {
        if (lan == "(none)" || lan.length < 4) return false
        var move: Move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
            ?: return false
        if (lan.length == 5) {
            move = board.completePromotion(
                of = move,
                to = when (lan[4]) {
                    'q' -> Piece.Kind.queen
                    'r' -> Piece.Kind.rook
                    'b' -> Piece.Kind.bishop
                    else -> Piece.Kind.knight
                },
            )
        }
        history += board.position.copy()
        recorder.record(move)

        ui = ui.copy(
            position = board.position,
            lastMove = move.start to move.end,
            sanMoves = ui.sanMoves + move.san,
            status = s(R.string.lab_played, side.label(getApplication()), move.san),
        )
        if (ui.resignationEnabled || ui.drawAgreementEnabled) noteEval()
        return true
    }

    /**
     * Une sonde COURTE après chaque coup, quand l'abandon ou la nulle sont
     * permis : c'est elle qui dit si la partie est jouée. Soixante
     * millisecondes — au regard des deux cents du coup lui-même, et de
     * l'inférence de Maia, c'est peu payé pour ne pas dérouler quarante
     * coups d'une finale décidée.
     */
    private suspend fun noteEval() {
        val cp = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { e ->
                e.send("position fen ${board.position.fen}")
                var score: Int? = null
                e.search("go movetime 60", timeoutMs = 5_000) { line ->
                    if (line.contains(" score cp ")) {
                        score = line.substringAfter(" score cp ").substringBefore(" ").toIntOrNull()
                    } else if (line.contains(" score mate ")) {
                        val mate = line.substringAfter(" score mate ").substringBefore(" ").toIntOrNull()
                        if (mate != null) score = if (mate > 0) 10_000 else -10_000
                    }
                }
                score
            }
        } ?: return
        // La sonde rend le score du camp AU TRAIT : on le range au point de vue des Blancs.
        recentEvals.addLast(if (board.position.sideToMove == Piece.Color.white) cp else -cp)
        while (recentEvals.size > DRAW_PLIES) recentEvals.removeFirst()
    }

    /**
     * La partie qui vient de finir entre au bilan, avec son PGN.
     *
     * Le résultat est rangé côté ÉCHIQUIER (« 1-0 ») et non côté A : c'est ce
     * qu'attend un PGN, et `LabCompletedGame` sait retrouver le point de vue
     * de A à partir de la couleur qu'il avait dans cette partie-là. Compter
     * directement pour A, comme on le faisait, rendait l'export impossible.
     */
    private fun tally(forced: String? = null) {
        val state = board.state
        val result = forced ?: when (state) {
            is Board.State.Checkmate -> if (state.color == Piece.Color.white) "0-1" else "1-0"
            is Board.State.Draw -> "1/2-1/2"
            else -> return
        }
        ui = ui.copy(
            completed = ui.completed + LabCompletedGame(
                index = ui.completed.size,
                aWasWhite = ui.aPlaysWhite,
                pgnResult = result,
                reasonLabel = if (forced == null) reasonLabel(state)
                else if (forced == "1/2-1/2") s(R.string.draw_agreement) else s(R.string.reason_resignation),
                plyCount = ui.sanMoves.size,
                pgn = recorder.pgn,
            )
        )
        // Sur le disque APRÈS CHAQUE PARTIE : une série de cent parties tourne
        // un quart d'heure, et l'app évincée par le système jetait jusqu'ici
        // tout le travail sans même le dire.
        LabAutosave.save(getApplication(), ui.seriesSettings, ui.completed)
    }

    // MARK: Chess960

    /** La partie de Chess960 en cours : sa position de départ, ses coups UCI, et les positions déjà vues. */
    private var c960Start: String? = null
    private val c960Log = mutableListOf<String>()
    private val c960Seen = HashMap<String, Int>()

    private enum class GameState { Finished, Paused, Failed }

    private fun positionOf(fen: String): Position =
        Position.fromFen(com.chesslab.variants.VariantFen.forChessKit(fen)) ?: Position.standard

    private fun settings960(): LabSeriesSettings = ui.seriesSettings

    /** Montre la position de la partie [index] avant qu'elle ne commence. */
    private fun previewChess960(index: Int) {
        val number = settings960().chess960NumberFor(index)
        val fen = com.chesslab.variants.Chess960Position.startingFen(number) ?: return
        ui = ui.copy(position = positionOf(fen), lastMove = null, sanMoves = emptyList(), chess960Current = number)
    }

    /**
     * La série en Chess960 : même déroulé que [runSeries], mais Fairy-Stockfish
     * ARBITRE (coups légaux, mat, pat) et joue — comme dans l'écran Chess960 de
     * l'app, sous `UCI_Chess960`. Pendant de `playOneChess960Game` (iOS). Stockfish
     * seul : ni livre, ni personnage.
     */
    private suspend fun runChess960Series() {
        while (viewModelScope.isActive && ui.running) {
            if (ui.completed.size >= ui.gameCount) {
                ui = ui.copy(running = false, status = s(R.string.lab_series_done, ui.completed.size))
                return
            }
            when (playChess960Game()) {
                GameState.Finished -> ui = ui.copy(
                    gameNumber = ui.gameNumber + 1,
                    aPlaysWhite = if (ui.alternateColors) !ui.aPlaysWhite else ui.aPlaysWhite,
                )
                GameState.Paused -> return
                GameState.Failed -> { stop(); return }
            }
        }
    }

    private suspend fun <T> fairy(block: suspend (com.chesslab.engine.FairyEngine) -> T): T? =
        withContext(Dispatchers.IO) {
            com.chesslab.engine.FairyEngine.use(getApplication()) { engine ->
                engine.send("setoption name UCI_Chess960 value true")
                block(engine)
            }
        }

    private suspend fun playChess960Game(): GameState {
        val index = ui.completed.size
        if (c960Start == null) {
            val number = settings960().chess960NumberFor(index)
            val fen = com.chesslab.variants.Chess960Position.startingFen(number) ?: return GameState.Failed
            c960Start = fen
            c960Log.clear()
            c960Seen.clear()
            recentEvals.clear()
            ui = ui.copy(position = positionOf(fen), lastMove = null, sanMoves = emptyList(), chess960Current = number)
        }
        val start = c960Start ?: return GameState.Failed

        var query = fairy { it.queryPosition("chess", start, c960Log) } ?: return GameState.Failed
        if (c960Seen.isEmpty()) c960Seen[repetitionKey(query.fen)] = 1

        while (viewModelScope.isActive && ui.running) {
            val position = positionOf(query.fen)
            val mover = position.sideToMove

            chess960End(query, position)?.let { (result, reason) ->
                finishChess960(index, start, result, reason)
                return GameState.Finished
            }
            if (c960Log.size >= MAX_PLIES) {
                finishChess960(index, start, "1/2-1/2", s(R.string.lab_end_too_long))
                return GameState.Finished
            }

            val isA = (mover == Piece.Color.white) == ui.aPlaysWhite
            val side = if (isA) ui.sideA else ui.sideB
            val strength = com.chesslab.variants.VariantSettings(level = side.level).strength
            val budget = com.chesslab.engine.ThermalMonitor.movetimeMs(ui.movetimeMs)
            val answer = fairy {
                it.search("chess", start, c960Log, budget, strength.maxDepth, strength.fairySetupCommands)
            } ?: return GameState.Failed
            if (!viewModelScope.isActive || !ui.running) return GameState.Paused

            val best = answer.bestLan
            if (best == null || best == "(none)") return GameState.Failed

            // La sonde de l'abandon et de la nulle : le score du camp au trait, tenu sur plusieurs coups.
            // Le score du camp au trait (`mover`), rangé au point de vue des Blancs.
            val moverCp = answer.cp ?: answer.mate?.let { if (it > 0) 10_000 else -10_000 }
            moverCp?.let { recentEvals.addLast(if (mover == Piece.Color.white) it else -it) }
            while (recentEvals.size > DRAW_PLIES) recentEvals.removeFirst()
            forcedChess960()?.let { (result, reason) ->
                finishChess960(index, start, result, reason)
                return GameState.Finished
            }

            val marks = com.chesslab.variants.Chess960Castling.displaySquares(best, position)
            c960Log += best
            val after = fairy { it.queryPosition("chess", start, c960Log) } ?: return GameState.Failed
            val san = com.chesslab.variants.VariantSan.build(
                uci = best, beforeFen = query.fen, legalMovesBefore = query.legalMoves,
                isCheck = after.inCheck, isMate = after.inCheck && after.legalMoves.isEmpty(),
            )
            val key = repetitionKey(after.fen)
            c960Seen[key] = (c960Seen[key] ?: 0) + 1
            ui = ui.copy(
                position = positionOf(after.fen),
                lastMove = marks,
                sanMoves = ui.sanMoves + san,
                status = s(R.string.lab_played, side.label(getApplication()), san),
            )
            query = after
            if (ui.liveVisualization) kotlinx.coroutines.delay(120)
        }
        return GameState.Paused
    }

    /** Les quatre premiers champs de la FEN : position, trait, droits, en passant. */
    private fun repetitionKey(fen: String) = fen.trim().split(" ").take(4).joinToString(" ")

    /**
     * Les fins « sur l'échiquier » : mat, pat (les coups légaux du moteur), matériel
     * insuffisant, cinquante coups et triple répétition. Même ordre qu'iOS.
     */
    private fun chess960End(query: com.chesslab.engine.PositionQuery, position: Position): Pair<String, String>? {
        if (query.legalMoves.isEmpty()) {
            return if (query.inCheck) {
                (if (position.sideToMove == Piece.Color.white) "0-1" else "1-0") to s(R.string.lab_end_checkmate)
            } else {
                "1/2-1/2" to s(R.string.draw_stalemate)
            }
        }
        if (com.chesslab.variants.VariantDrawRules.isInsufficientMaterial(query.fen, "chess960", true)) {
            return "1/2-1/2" to s(R.string.draw_material)
        }
        val halfmove = query.fen.trim().split(" ").getOrNull(4)?.toIntOrNull() ?: 0
        if (halfmove >= 100) return "1/2-1/2" to s(R.string.draw_fifty)
        if ((c960Seen[repetitionKey(query.fen)] ?: 0) >= 3) return "1/2-1/2" to s(R.string.draw_repetition)
        return null
    }

    /** L'abandon et la nulle par accord, aux mêmes seuils que la série classique. */
    private fun forcedChess960(): Pair<String, String>? {
        val result = agreedOutcome(recentEvals, ui.sanMoves.size) ?: return null
        return result to s(if (result == "1/2-1/2") R.string.draw_agreement else R.string.reason_resignation)
    }

    /** La partie finie entre au bilan, avec son PGN de variante (`Variant`, `SetUp`, `FEN`). */
    private fun finishChess960(index: Int, start: String, result: String, reason: String) {
        val app = getApplication<Application>()
        val tags = com.chesslab.library.PgnExport.tagLines(
            event = "ChessLab Lab",
            white = if (ui.aPlaysWhite) "A" else "B", black = if (ui.aPlaysWhite) "B" else "A",
            result = result, variant = "Chess960", startFen = start,
        )
        val moves = StringBuilder()
        ui.sanMoves.forEachIndexed { i, san ->
            if (i % 2 == 0) moves.append("${i / 2 + 1}. ")
            moves.append(san).append(' ')
        }
        moves.append(result)
        ui = ui.copy(
            completed = ui.completed + LabCompletedGame(
                index = index,
                aWasWhite = ui.aPlaysWhite,
                pgnResult = result,
                reasonLabel = reason,
                plyCount = ui.sanMoves.size,
                pgn = tags.joinToString("\n") + "\n\n" + moves,
                chess960Number = ui.chess960Current,
                chess960StartFen = start,
                chess960Moves = c960Log.joinToString(" "),
            )
        )
        c960Start = null
        LabAutosave.save(app, ui.seriesSettings, ui.completed)
        // La position de la partie SUIVANTE, montrée dès maintenant.
        if (ui.completed.size < ui.gameCount) previewChess960(ui.completed.size)
    }

    // MARK: Reprise

    /**
     * Une série interrompue attend-elle sur le disque ? Appelé à l'ouverture
     * de l'écran. Une série TERMINÉE n'est pas proposée : elle n'a plus rien à
     * reprendre, et son fichier ne sert qu'à ne pas la reproposer.
     */
    fun lookForInterruptedSeries() {
        if (ui.running || ui.completed.isNotEmpty()) return
        val snapshot = LabAutosave.load(getApplication()) ?: return
        if (snapshot.isComplete || snapshot.completed.isEmpty()) return
        ui = ui.copy(resumable = snapshot)
    }

    /** Reprendre : les réglages ET les parties déjà jouées reviennent. */
    fun resumeInterruptedSeries() {
        val snapshot = ui.resumable ?: return
        val settings = snapshot.settings
        startPosition = settings.startFen?.let { Position.fromFen(it) } ?: Position.standard
        ui = ui.copy(
            sideA = settings.sideA, sideB = settings.sideB,
            movetimeMs = settings.movetimeMs, gameCount = settings.gameCount,
            alternateColors = settings.alternateColors,
            resignationEnabled = settings.resignationEnabled,
            drawAgreementEnabled = settings.drawAgreementEnabled,
            liveVisualization = settings.liveVisualization,
            bookA = settings.bookA, bookB = settings.bookB, bookWidth = settings.bookWidth,
            keepAwakeSetting = settings.keepAwakeSetting, startFen = settings.startFen,
            chess960 = settings.chess960, chess960Number = settings.chess960Number,
            chess960Seed = settings.chess960Seed,
            completed = snapshot.completed,
            gameNumber = snapshot.completed.size,
            // La couleur de A suit l'alternance : la reprendre au hasard
            // biaiserait le reste de la série.
            aPlaysWhite = !settings.alternateColors || snapshot.completed.size % 2 == 0,
            resumable = null,
            status = s(R.string.lab_resumed, snapshot.completed.size),
        )
        c960Start = null
        if (settings.chess960) previewChess960(snapshot.completed.size) else newGame()
    }

    /** Écarter : on repart de zéro, et le fichier s'en va avec. */
    fun discardInterruptedSeries() {
        LabAutosave.clear(getApplication())
        ui = ui.copy(resumable = null)
    }

    private fun reasonLabel(state: Board.State): String = when (state) {
        is Board.State.Checkmate -> s(R.string.lab_end_checkmate)
        is Board.State.Draw -> when (state.reason) {
            Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
            Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
            Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
            Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
            Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
        }
        else -> ""
    }

    /** Le PGN de toute la série, pour l'export. */
    fun exportPgn(): String = LabExport.pgn(
        ui.completed,
        nameA = ui.sideA.label(getApplication()),
        nameB = ui.sideB.label(getApplication()),
    )

    /** Le CSV de toute la série : une ligne par partie. */
    fun exportCsv(): String = LabExport.csv(ui.completed)

    /**
     * Le PGN de la DERNIÈRE partie, pour aller la revoir. Vide tant qu'aucune
     * n'est finie. Sans ce chemin, il fallait exporter la série entière et
     * recoller le tout dans l'analyse pour regarder une seule partie.
     */
    fun lastGamePgn(): String {
        val last = ui.completed.lastOrNull() ?: return ""
        return LabExport.pgn(
            listOf(last),
            nameA = ui.sideA.label(getApplication()),
            nameB = ui.sideB.label(getApplication()),
        )
    }

    override fun onCleared() {
        loop?.cancel()
        super.onCleared()
    }

    private companion object {
        /** Fenêtre des évaluations gardées : la plus longue des deux (la nulle). */
        const val DRAW_PLIES = AgreedOutcome.DRAW_PLIES


        /** Sécurité anti-partie-infinie : 400 demi-coups, comme iOS. */
        const val MAX_PLIES = 400
    }
}
