package com.chesslab.analysis

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.Board
import chesskit.FenParser
import chesskit.Game
import chesskit.Move
import chesskit.MoveTree
import chesskit.PgnParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R
import com.chesslab.engine.EngineService
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.SettingsStore
import com.chesslab.puzzles.OwnPuzzle
import com.chesslab.puzzles.PuzzleSolutionTrimmer
import com.chesslab.ui.HintArrowBuilder
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Ce que les flèches du mode Analyser montrent. Pendant d'`ArrowMode`. */
enum class ArrowMode(val labelRes: Int) {
    /** Pour revoir une partie sans être soufflé. */
    none(R.string.arrows_none),
    best(R.string.arrows_best),
    /** Pour comparer des candidats. */
    three(R.string.arrows_three);
}

/** Un coup candidat du moteur à la position affichée. */
data class Candidate(
    val rank: Int,
    val san: String,
    val lan: String,
    val eval: String,
    /**
     * La force de la flèche — `null` quand le coup est trop loin du meilleur
     * pour mériter d'être montré. Le candidat reste dans la LISTE (on veut
     * pouvoir lire pourquoi il est moins bon), il n'a simplement pas de flèche.
     */
    val strength: Double? = null,
)

/**
 * L'évaluation d'UNE position, telle que le moteur la rend.
 *
 * [cp] et [mate] sont ramenés au POINT DE VUE DES BLANCS — le moteur les donne
 * du point de vue du trait, ce qui ferait changer l'évaluation de signe à
 * chaque coup.
 */
data class PositionEval(
    val cp: Int?,
    val mate: Int?,
    val bestLan: String?,
    /** Écart (points de %) entre le 1er et le 2e choix, POV du camp au trait. */
    val gapToSecondBest: Double?,
    /** Le 2e choix lui-même : la flèche de comparaison, en revue. */
    val secondBestLan: String? = null,
    /** La variante principale, en LAN : c'est elle qui sert de réfutation. */
    val pv: List<String>,
    /**
     * Le verdict d'une position TERMINÉE, en probabilité de gain POV Blancs :
     * 100 mat des Noirs, 0 mat des Blancs, 50 partie nulle.
     *
     * Le moteur n'a rien à dire d'une position finie — pas de coup légal, donc
     * pas de variante, donc pas de ligne `info` exploitable. Sans ce cas, la
     * position d'après le mat retombait sur « 0 centipion », soit 50 % : le
     * coup qui MATE apparaissait comme une chute de 100 à 50, et se voyait
     * classé « occasion manquée ». Le mat noté comme une gaffe.
     */
    val terminalWinWhite: Double? = null,
) {
    /** Probabilité de gain des Blancs (0…100). */
    val winPercentWhite: Double
        get() = terminalWinWhite
            ?: mate?.let { EvalConversion.fromMate(it) }
            ?: EvalConversion.fromCentipawns(cp ?: 0)

    /** L'évaluation en pions, POV Blancs, bornée ±10 pour la courbe. */
    val pawnsWhite: Double
        get() = terminalWinWhite?.let { if (it > 50) 10.0 else if (it < 50) -10.0 else 0.0 }
            ?: mate?.let { if (it > 0) 10.0 else -10.0 }
            ?: min(10.0, max(-10.0, (cp ?: 0) / 100.0))
}

/**
 * La même position, le trait passé à l'adversaire : celle qui révèle sa MENACE
 * (« et si je passais mon tour ? »). Pendant de `ThreatPosition.swift`.
 *
 * `null` quand la question n'a pas de sens : passer son tour est impossible si
 * l'adversaire pourrait alors prendre le roi. Envoyer une position illégale au
 * moteur, c'est en recevoir n'importe quoi.
 */
fun fenWithSideToMoveFlipped(fen: String): String? {
    val fields = fen.split(" ")
    if (fields.size != 6) return null
    val flipped = fields.toMutableList()
    flipped[1] = if (fields[1] == "w") "b" else "w"
    // La case en passant est un DROIT du camp au trait, valable pour ce seul
    // coup : la garder après avoir passé la main produirait un coup fantôme.
    flipped[3] = "-"

    val candidate = flipped.joinToString(" ")
    val position = Position.fromFen(candidate) ?: return null
    val board = Board(position)
    val enemyKing = position.pieces
        .firstOrNull { it.kind == Piece.Kind.king && it.color == position.sideToMove.opposite }
        ?.square ?: return null
    // Le roi du camp qui vient de « passer » est-il en prise ? Alors la
    // position n'existe pas.
    val kingIsCapturable = position.pieces
        .filter { it.color == position.sideToMove }
        .any { enemyKing in board.legalMoves(it.square) }
    return if (kingIsCapturable) null else candidate
}

/**
 * Le verdict d'une position finie, en probabilité de gain POV Blancs, ou `null`
 * si la partie continue. Partagé par l'analyse en continu et par la revue :
 * les deux doivent dire la même chose d'un mat.
 */
private fun terminalWinWhite(position: Position): Double? =
    when (val state = Board(position.copy()).state) {
        is Board.State.Checkmate -> if (state.color == Piece.Color.black) 100.0 else 0.0
        is Board.State.Draw -> 50.0
        else -> null
    }

/** Un point de la courbe d'évaluation. */
data class CurvePoint(val ply: Int, val pawns: Double, val quality: MoveQuality?)

data class AnalysisUiState(
    val position: Position = Position.standard,
    val sanMoves: List<String> = emptyList(),
    /** -1 = position de départ ; sinon l'index du coup joué. */
    val cursor: Int = -1,
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val evaluation: String = "",
    val depth: Int = 0,
    val bestLine: String = "",
    val thinking: Boolean = false,
    val input: String = "",
    val error: String? = null,
    val orientation: Piece.Color = Piece.Color.white,

    /** L'éval de la position affichée, POV Blancs — la barre s'en sert. */
    val evalCp: Int? = null,
    val evalMate: Int? = null,

    /** Les coups candidats du moteur à la position affichée. */
    val candidates: List<Candidate> = emptyList(),
    val arrowMode: ArrowMode = ArrowMode.best,

    /** L'ouverture reconnue par la base ECO, si la ligne la confirme. */
    val opening: EcoOpening? = null,

    /**
     * Ce que l'adversaire jouerait si on lui laissait la main : la MENACE.
     * Flèche rouge sur le plateau.
     */
    val threat: Pair<Square, Square>? = null,

    /** La classification, par index de coup — vide tant que la revue n'a pas tourné. */
    val qualities: Map<Int, MoveQuality> = emptyMap(),
    val explanations: Map<Int, MoveExplanation> = emptyMap(),
    /** La perte de probabilité de gain de chaque coup, POV du joueur. */
    val winDeltas: Map<Int, Double> = emptyMap(),
    val curve: List<CurvePoint> = emptyList(),
    val summary: GameSummary? = null,
    val reviewing: Boolean = false,
    val reviewDone: Int = 0,
    val reviewTotal: Int = 0,
    /** Le meilleur coup de la position précédente, en LAN, après une faute. */
    val betterLan: String? = null,
    /**
     * L'évaluation MISE EN CACHE de la position affichée, quand la revue est
     * passée par là. Sa présence fait basculer les flèches du gris de
     * l'analyse en direct au vert de la revue — ce sont deux régimes
     * différents, et iOS les distingue.
     */
    val reviewEval: PositionEval? = null,
    /** Le nombre de puzzles que la dernière génération a créés, à annoncer. */
    val puzzlesCreated: Int? = null,
    /** La case choisie, et les cases où elle peut aller : le plateau se JOUE. */
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    /** Le coup en attente du choix de la pièce de promotion. */
    val pendingPromotion: Move? = null,
    /** La lecture automatique déroule la partie, un coup par seconde. */
    val autoplaying: Boolean = false,
    /** Stockfish n'a pas démarré : la bannière le dit, et propose de réessayer. */
    val engineUnavailable: Boolean = false,
    val retryingEngine: Boolean = false,
) {
    /**
     * La PASTILLE de qualité du dernier coup, à poser sur sa case d'arrivée.
     * Pendant du `qualityBadge` d'iOS : le verdict là où il s'est joué.
     */
    val qualityBadge: Pair<chesskit.Square, MoveQuality>?
        get() {
            val quality = qualities[cursor] ?: return null
            val end = lastMove?.second ?: return null
            return end to quality
        }

    val canGoNext: Boolean get() = cursor < sanMoves.size - 1
    val canGoPrevious: Boolean get() = cursor >= 0

    /**
     * Peut-on dérouler le meilleur coup ? Seulement quand il y en a un, et
     * qu'on est au BOUT de la ligne : au milieu d'une partie, « jouer le
     * meilleur coup » couperait la suite sans prévenir.
     */
    val canPlayBestMove: Boolean
        get() = !canGoNext && candidates.isNotEmpty() && pendingPromotion == null

    /** La qualité du coup qui mène à la position affichée. */
    val displayedQuality: MoveQuality? get() = qualities[cursor]

    /**
     * « Il fallait jouer ça » : le meilleur coup de la position PRÉCÉDENTE,
     * montré quand le coup affiché s'est révélé fautif. C'est le point
     * d'apprentissage — le seul moment où une flèche rétrospective a un sens.
     */
    val betterMove: Pair<Square, Square>? get() = betterLan?.let {
        Square(it.substring(0, 2)) to Square(it.substring(2, 4))
    }
    val displayedExplanation: MoveExplanation? get() = explanations[cursor]
    val displayedWinDelta: Double? get() = winDeltas[cursor]
}

/**
 * Analyser une partie : charger un PGN ou une FEN, parcourir les coups, lire
 * l'évaluation du moteur à chaque position — et, sur demande, classer TOUS les
 * coups de la partie pour en dresser le bilan.
 *
 * Pendant d'`AnalysisViewModel.swift`. Le filet de `PGNLoader` n'a PAS
 * d'équivalent ici : les deux bugs qu'il contourne côté iOS sont corrigés dans
 * le port, donc rien n'est perdu à l'import — ni variantes, ni commentaires.
 */
class AnalysisViewModel(app: Application) : AndroidViewModel(app) {

    private var positions: List<Position> = listOf(Position.standard)
    private var moves: List<Move> = emptyList()
    private var game: Game? = null
    private var evalJob: Job? = null
    private var reviewJob: Job? = null
    private var lazyJob: Job? = null

    /** Les évaluations de la revue, une par POSITION (il y en a une de plus que de coups). */
    private var reviewEvals: MutableMap<Int, PositionEval> = HashMap()

    /**
     * REVUE d'une partie (un PGN qui a des coups) ou ANALYSE d'une position
     * (FEN, scan, éditeur) ? iOS distingue les deux à la source, et tout en
     * dépend : en revue, la classification part TOUTE SEULE au chargement,
     * puis le moteur se tait — naviguer lit le cache, rien n'est recalculé.
     * Sur une position, l'analyse en continu est la seule source d'évaluation.
     */
    private var isGameReview = false

    /** La clé du cache disque pour la partie chargée ; `null` pour une ligne explorée à la main. */
    private var persistenceKey: String? = null
    private val store = AnalysisEvalStore(
        java.io.File(app.filesDir, "analysis-cache"),
        AnalysisEvalStore.engineProfile(app),
    )
    private val book by lazy { EcoOpeningLoader.bookLines(getApplication<Application>().assets) }

    var ui by mutableStateOf(
        AnalysisUiState(
            status = s(R.string.analysis_paste),
            arrowMode = ArrowMode.entries
                .firstOrNull { it.name == SettingsStore.state.value.analysisArrowMode }
                ?: ArrowMode.best,
        )
    )
        private set

    /** Les parties enregistrées, les plus récentes d'abord. */
    val savedGames: Flow<List<GameRecord>> = LibraryDatabase.get(app).games().all()

    /** Charge une partie de la bibliothèque comme si on collait son PGN. */
    fun open(record: GameRecord) {
        ui = ui.copy(input = record.pgn)
        load()
    }

    fun onInputChange(text: String) { ui = ui.copy(input = text, error = null) }

    fun flip() {
        ui = ui.copy(orientation = ui.orientation.opposite)
    }

    /**
     * Le choix de flèches SURVIT à la fermeture de l'écran : quelqu'un qui
     * revoit ses parties sans vouloir être soufflé a coupé les flèches une
     * fois, pas à chaque ouverture.
     */
    fun setArrowMode(mode: ArrowMode) {
        ui = ui.copy(arrowMode = mode)
        SettingsStore.setArrowMode(getApplication(), mode.name)
    }

    /** Le PGN de la partie chargée, pour l'export. Vide si rien n'est chargé. */
    fun pgn(): String = game?.pgn ?: ""

    fun load() {
        val text = ui.input.trim()
        if (text.isEmpty()) return

        reviewJob?.cancel()
        reviewEvals.clear()

        // une FEN d'abord — c'est plus court et sans ambiguïté
        FenParser.parse(text)?.let { position ->
            positions = listOf(position)
            moves = emptyList()
            game = null
            isGameReview = false
            persistenceKey = null
            ui = ui.copy(
                position = position, sanMoves = emptyList(), cursor = -1,
                lastMove = null, status = s(R.string.analysis_position_loaded), error = null,
                qualities = emptyMap(), explanations = emptyMap(), winDeltas = emptyMap(),
                curve = emptyList(), summary = null, opening = null,
                reviewing = false, reviewDone = 0, reviewTotal = 0,
                // Les Noirs au trait : on regarde la position de leur côté.
                orientation = position.sideToMove,
            )
            evaluate()
            return
        }

        // Un PGN collé depuis un site web arrive avec un BOM, des fins de
        // ligne Windows ou un commentaire de présentation : valide à l'œil,
        // refusé par le lecteur. On le nettoie AVANT de le lui donner. Et un
        // fichier de base contient souvent plusieurs parties : on prend la
        // première, la seule que cet écran puisse montrer.
        val cleaned = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(text))
            .firstOrNull() ?: text
        val parsed = try {
            PgnParser.parse(cleaned)
        } catch (e: Exception) {
            ui = ui.copy(error = s(R.string.analysis_pgn_unreadable))
            return
        }

        val mainline = parsed.moves.indices
            .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
            .sorted()

        if (mainline.isEmpty()) {
            ui = ui.copy(error = s(R.string.analysis_no_moves))
            return
        }

        val start = parsed.startingPosition ?: Position.standard
        positions = listOf(start) + mainline.mapNotNull { parsed.position(it) }
        moves = mainline.mapNotNull { parsed.moves[it] }
        game = parsed

        val label = listOfNotNull(
            parsed.tags.white.ifEmpty { null },
            parsed.tags.black.ifEmpty { null },
        ).joinToString(" — ").ifEmpty { s(R.string.analysis_game_loaded) }

        ui = ui.copy(
            sanMoves = moves.map { it.san },
            cursor = moves.size - 1,
            status = label,
            error = null,
            qualities = emptyMap(), explanations = emptyMap(), winDeltas = emptyMap(),
            curve = emptyList(), summary = null,
            reviewing = false, reviewDone = 0, reviewTotal = 0,
        )
        isGameReview = true
        // Analyse DÉJÀ FAITE ? Le cache disque la restitue entière — évals,
        // verdicts, courbe, précision — avant même que le moteur démarre : la
        // partie s'ouvre classifiée, et la revue ne repart que pour ce qui
        // manque (écran quitté en cours de route).
        persistenceKey = AnalysisEvalStore.key(start.fen, moves.map { it.lan })
        persistenceKey?.let { key -> store.load(key) }?.let { restored ->
            reviewEvals = restored.toMutableMap()
            classify(positions, moves, reviewEvals, book)
        }
        goTo(moves.size - 1)
        if (!isMainLineFullyEvaluated()) review()
    }

    /**
     * Vrai quand chaque position de la ligne principale porte son évaluation.
     * Fondé sur les DONNÉES, pas sur un drapeau : un drapeau ment dès que la
     * revue s'interrompt sans le remettre à zéro.
     */
    private fun isMainLineFullyEvaluated(): Boolean =
        positions.indices.all { reviewEvals.containsKey(it) }

    fun goTo(index: Int) {
        val clamped = index.coerceIn(-1, moves.size - 1)
        val position = positions.getOrNull(clamped + 1) ?: return
        val move = moves.getOrNull(clamped)

        val board = Board(position.copy())
        val checked = when (val state = board.state) {
            is Board.State.Check -> kingSquare(position, state.color)
            is Board.State.Checkmate -> kingSquare(position, state.color)
            else -> null
        }

        ui = ui.copy(
            position = position,
            cursor = clamped,
            selected = null, legalTargets = emptySet(),
            lastMove = move?.let { it.start to it.end },
            checkedKing = checked,
            evaluation = "", depth = 0, bestLine = "",
            evalCp = null, evalMate = null, candidates = emptyList(), threat = null,
            opening = openingAt(clamped),
            // La rétrospective ne se montre qu'après une FAUTE : ailleurs, elle
            // donnerait la solution d'une position qu'on n'a pas eu tort de
            // jouer. `reviewEvals[clamped]` est l'éval de la position PARENTE
            // du coup affiché — c'est là que vivait le coup qu'il fallait jouer.
            betterLan = if (ui.qualities[clamped]?.isFault == true)
                reviewEvals[clamped]?.bestLan else null,
            reviewEval = reviewEvals[clamped + 1],
        )
        // REVUE : l'analyse a DÉJÀ été calculée. Naviguer ne relance RIEN —
        // l'évaluation et les flèches sont lues dans le cache, le moteur reste
        // au repos. Une position pas encore évaluée (variante explorée, revue
        // interrompue) est classée UNE fois, sans rallumer l'analyse en
        // continu. EXPLORATION d'une position : l'analyse en continu est la
        // seule source, elle recalcule à chaque coup — c'est voulu.
        if (isGameReview) showCachedEval(clamped) else evaluate()
    }

    /**
     * Affiche l'évaluation MISE EN CACHE de la position affichée,
     * instantanément et sans toucher au moteur ; en demande une seule si elle
     * manque. Les candidats viennent du même cache : le meilleur coup avec
     * son éval, le 2e choix quand il est proche — ce que les chips savent
     * jouer pour explorer.
     */
    private fun showCachedEval(cursor: Int) {
        val index = cursor + 1
        val position = positions.getOrNull(index) ?: return
        val cached = reviewEvals[index]
        if (cached == null) {
            ensureEvaluatedLazily(index)
            return
        }
        val candidates = ArrayList<Candidate>()
        cached.bestLan?.let { lan ->
            sanFor(position, lan)?.let { san ->
                candidates += Candidate(1, san, lan, scoreText(cached.cp, cached.mate), strength = 1.0)
            }
        }
        val gap = cached.gapToSecondBest
        cached.secondBestLan?.let { lan ->
            sanFor(position, lan)?.let { san ->
                candidates += Candidate(2, san, lan, "", strength = gap?.let { max(0.6, 1 - it / 12) })
            }
        }
        ui = ui.copy(
            thinking = false, depth = 0,
            evaluation = cached.terminalWinWhite?.let { terminalText(it) } ?: scoreText(cached.cp, cached.mate),
            evalCp = cached.cp, evalMate = cached.mate,
            bestLine = cached.pv.joinToString(" "),
            candidates = candidates,
        )
    }

    /**
     * Classe un nœud isolé dès qu'on y navigue pour la première fois — une
     * variante explorée depuis un candidat, ou un coup que la revue n'a pas
     * encore atteint. Une seule recherche, puis le cache reprend la main.
     */
    private fun ensureEvaluatedLazily(index: Int) {
        if (ui.reviewing || reviewEvals.containsKey(index)) return
        val position = positions.getOrNull(index)?.copy() ?: return
        val fen = position.fen
        lazyJob?.cancel()
        lazyJob = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            val eval = try {
                withContext(Dispatchers.IO) {
                    EngineService.use(getApplication()) { e ->
                        e.send("setoption name MultiPV value 2")
                        rankedEval(e, position)
                    }
                }
            } finally {
                ui = ui.copy(thinking = false)
            } ?: return@launch
            // La ligne a pu changer pendant la recherche : une éval rangée
            // sous le mauvais index serait pire que pas d'éval du tout.
            if (positions.getOrNull(index)?.fen != fen) return@launch
            reviewEvals[index] = eval
            classify(positions, moves, reviewEvals, book)
            if (ui.cursor + 1 == index) showCachedEval(ui.cursor)
        }
    }

    fun previous() = goTo(ui.cursor - 1)
    fun next() = goTo(ui.cursor + 1)
    fun goToStart() = goTo(-1)

    /** Jouer un coup candidat, c'est aller le voir : il devient le coup courant. */
    fun playCandidate(candidate: Candidate) {
        val at = ui.cursor
        val position = positions.getOrNull(at + 1) ?: return
        val board = Board(position.copy())
        val from = Square(candidate.lan.substring(0, 2))
        val to = Square(candidate.lan.substring(2, 4))
        val move = board.move(from, to) ?: return
        val done = if (board.state is Board.State.Promotion)
            board.completePromotion(move, kindOf(candidate.lan.getOrNull(4))) else move
        append(board, done)
    }

    // MARK: Jouer sur le plateau — l'exploration d'une variante

    /**
     * Le plateau d'analyse SE JOUE : on pose un coup dessus pour voir ce qu'il
     * donne, comme sur iOS. Il était inerte — la seule façon d'explorer était
     * de toucher une pastille de candidat, donc on ne pouvait essayer que ce
     * que le moteur proposait déjà.
     */
    fun selectSquare(square: Square) {
        if (ui.pendingPromotion != null) return
        stopAutoplay()
        val position = positions.getOrNull(ui.cursor + 1) ?: return
        val board = Board(position.copy())
        val mover = position.sideToMove

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            attemptMove(selected, square)
            return
        }

        // Toucher la case d'ARRIVÉE d'une flèche, sans rien avoir sélectionné,
        // joue ce candidat : c'est ce que fait iOS quand on tape la flèche
        // elle-même, et c'est le geste qu'on essaie spontanément.
        if (selected == null) {
            ui.candidates.firstOrNull { it.lan.length >= 4 && Square(it.lan.substring(2, 4)) == square }
                ?.let { candidate ->
                    val from = Square(candidate.lan.substring(0, 2))
                    if (position.piece(from)?.color == mover && position.piece(square)?.color != mover) {
                        playCandidate(candidate)
                        return
                    }
                }
        }

        val piece = position.piece(square)
        ui = if (piece != null && piece.color == mover) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    /** Le glisser-déposer : d'une case à l'autre, sans passer par la sélection. */
    fun attemptMove(from: Square, to: Square) {
        if (ui.pendingPromotion != null) return
        val position = positions.getOrNull(ui.cursor + 1) ?: return
        if (position.piece(from)?.color != position.sideToMove) return
        val board = Board(position.copy())
        val move = board.move(pieceAt = from, to = to) ?: run {
            ui = ui.copy(selected = null, legalTargets = emptySet())
            return
        }
        if (board.state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        append(board, move)
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val position = positions.getOrNull(ui.cursor + 1) ?: return
        val board = Board(position.copy())
        val move = board.move(pieceAt = pending.start, to = pending.end) ?: return
        ui = ui.copy(pendingPromotion = null)
        append(board, board.completePromotion(of = move, to = kind))
    }

    /** Toucher à côté ANNULE : le coup n'est pas joué, la pièce reste où elle est. */
    fun cancelPromotion() {
        if (ui.pendingPromotion == null) return
        ui = ui.copy(pendingPromotion = null, selected = null, legalTargets = emptySet())
    }

    /** Déroule le meilleur coup du moteur, un coup à la fois. */
    fun playBestMove() {
        if (!ui.canPlayBestMove) return
        ui.candidates.firstOrNull { it.rank == 1 }?.let { playCandidate(it) }
    }

    /**
     * Ajoute [move] à la ligne affichée, en COUPANT la suite : explorer, c'est
     * créer une nouvelle ligne. Rejouer la partie d'origine demande de la
     * recharger, ce qui est fidèle à ce que fait iOS quand on suit une
     * variante depuis le bout.
     */
    private fun append(board: Board, move: Move) {
        val at = ui.cursor
        positions = positions.take(at + 2) + board.position.copy()
        moves = moves.take(at + 1) + move
        // Les évaluations du tronc commun restent vraies ; celles de la suite
        // coupée ne le sont plus. Et une ligne explorée à la main n'entre pas
        // dans le cache disque : il ne garde que la partie telle que jouée.
        reviewEvals = reviewEvals.filterKeys { it <= at + 1 }.toMutableMap()
        persistenceKey = null
        ui = ui.copy(
            sanMoves = moves.map { it.san },
            qualities = emptyMap(), explanations = emptyMap(), winDeltas = emptyMap(),
            curve = emptyList(), summary = null,
            selected = null, legalTargets = emptySet(),
        )
        if (isGameReview && reviewEvals.isNotEmpty()) classify(positions, moves, reviewEvals, book)
        goTo(moves.size - 1)
    }

    private fun kindOf(c: Char?): Piece.Kind = when (c) {
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        'n' -> Piece.Kind.knight
        else -> Piece.Kind.queen
    }

    // MARK: Lecture automatique

    private var autoplayJob: Job? = null

    /**
     * Déroule la partie toute seule, un coup par seconde. C'est la façon la
     * plus simple de REVOIR une partie : on regarde le plateau, pas les
     * boutons.
     */
    fun toggleAutoplay() {
        if (ui.autoplaying) { stopAutoplay(); return }
        if (!ui.canGoNext) return
        ui = ui.copy(autoplaying = true)
        autoplayJob = viewModelScope.launch {
            while (ui.canGoNext) {
                kotlinx.coroutines.delay(1_000)
                if (!ui.autoplaying) return@launch
                next()
            }
            ui = ui.copy(autoplaying = false)
        }
    }

    /**
     * L'écran s'en va : on arrête TOUT ce qui tourne pour lui.
     *
     * Sans cela, la lecture automatique continuait de dérouler la partie
     * derrière l'écran disparu — en relançant une analyse à chaque coup — et
     * l'analyse en continu gardait le moteur à plein régime pendant qu'on
     * regardait autre chose. La REVUE, elle, poursuit : elle sauvegarde ce
     * qu'elle classe, et la reprendre coûterait plus cher que la finir.
     */
    fun handleViewDisappear() {
        stopAutoplay()
        evalJob?.cancel()
        lazyJob?.cancel()
        ui = ui.copy(thinking = false)
    }

    /** Le retour sur l'écran : l'analyse en continu reprend là où elle était. */
    fun handleViewAppear() {
        if (!isGameReview && ui.sanMoves.isNotEmpty() || positions.size > 1) evaluate()
    }

    fun stopAutoplay() {
        autoplayJob?.cancel()
        autoplayJob = null
        if (ui.autoplaying) ui = ui.copy(autoplaying = false)
    }

    /**
     * Le moteur n'a pas démarré : on retente. Un échec de lancement est
     * parfois passager, et rester devant une bannière sans recours n'aide
     * personne.
     */
    fun retryEngine() = viewModelScope.launch {
        if (ui.retryingEngine) return@launch
        ui = ui.copy(retryingEngine = true)
        EngineService.retry()
        withContext(Dispatchers.IO) { EngineService.use(getApplication()) { EngineService.identity } }
        ui = ui.copy(retryingEngine = false, engineUnavailable = EngineService.isUnavailable)
        if (!ui.engineUnavailable) evaluate()
    }

    /** L'ouverture reconnue à hauteur du coup [cursor]. */
    private fun openingAt(cursor: Int): EcoOpening? {
        if (cursor < 0) return null
        val path = moves.take(cursor + 1).map { it.san }
        val database = EcoOpeningLoader.standard(getApplication<Application>().assets)
        return EcoOpeningLookup.openingName(path, database)
    }

    // MARK: L'analyse de la position affichée

    /**
     * Le moteur sur la position affichée, en MultiPV 3 : l'évaluation, les
     * coups candidats et les flèches en viennent tous.
     */
    private fun evaluate() {
        evalJob?.cancel()
        // GARANTIE : en REVUE d'une partie, on ne lance JAMAIS l'analyse en
        // continu. La revue se contente du cache ; le moteur reste au repos
        // une fois la passe finie — quelle que soit la voie d'appel.
        if (ui.reviewing || isGameReview) return
        val position = ui.position.copy()
        val fen = position.fen

        // Rien à demander au moteur sur une position finie : il n'a pas de coup
        // à proposer, et l'écran doit dire « mat » ou « nulle », pas « — ».
        terminalWinWhite(position)?.let { win ->
            ui = ui.copy(
                thinking = false, depth = 0, bestLine = "", candidates = emptyList(),
                evaluation = terminalText(win),
                evalCp = null, evalMate = if (win == 50.0) null else if (win > 50) 1 else -1,
            )
            return
        }

        evalJob = viewModelScope.launch {
            ui = ui.copy(thinking = true)
            try {
                withContext(Dispatchers.IO) {
                    EngineService.use(getApplication()) { e ->
                        e.send("setoption name MultiPV value 3")
                        e.send("position fen $fen")
                        val lines = HashMap<Int, RankedLine>()
                        // La profondeur de l'analyse EN CONTINU : rabotée
                        // quand l'appareil chauffe (voir `ThermalMonitor`),
                        // car cette position est réévaluée à chaque
                        // navigation.
                        val preferred = com.chesslab.engine.DevicePerformance.liveDepth(getApplication())
                        val depth = com.chesslab.engine.ThermalMonitor.liveDepth(preferred)
                        e.search("go depth $depth", timeoutMs = 30_000) { line ->
                            parseInfo(line)?.let { info ->
                                lines[info.rank] = info.line
                                if (info.rank == 1) publishLive(position, info, lines)
                            }
                        }
                        publishCandidates(position, lines)
                        // La menace se demande APRÈS, sur la même prise du
                        // moteur : une seconde requête séparée devrait
                        // reprendre le verrou, et la position aurait pu changer
                        // entre-temps.
                        computeThreat(e, position)
                    }
                }
            } finally {
                // Le moteur n'a pas démarré : l'écran le DIT plutôt que de
                // rester sur un tiret, avec de quoi réessayer.
                ui = ui.copy(thinking = false, engineUnavailable = EngineService.isUnavailable)
            }
        }
    }

    private fun publishLive(position: Position, info: ParsedInfo, lines: Map<Int, RankedLine>) {
        val white = toWhitePov(info.line, position.sideToMove)
        ui = ui.copy(
            evaluation = scoreText(white.cp, white.mate),
            depth = info.depth,
            bestLine = info.line.pv.joinToString(" "),
            evalCp = white.cp, evalMate = white.mate,
        )
        publishCandidates(position, lines)
    }

    /**
     * Courte recherche (200 ms, comme iOS) sur la position avec le trait passé
     * à l'adversaire. Elle est brève à dessein : la menace se lit d'un coup
     * d'œil, elle n'a pas à être exacte au centipion.
     */
    private suspend fun computeThreat(engine: com.chesslab.engine.StockfishEngine, position: Position) {
        val fen = fenWithSideToMoveFlipped(position.fen)
        if (fen == null) { ui = ui.copy(threat = null); return }
        engine.send("setoption name MultiPV value 1")
        engine.send("position fen $fen")
        val best = engine.search("go movetime 200", timeoutMs = 5_000)
            ?.removePrefix("bestmove ")?.trim()?.substringBefore(" ")
        // La position affichée a pu changer pendant la recherche : une menace
        // calculée pour une AUTRE position serait pire que pas de menace.
        if (ui.position.fen != position.fen) return
        ui = ui.copy(
            threat = best?.takeIf { it.length >= 4 && it != "(none)" }
                ?.let { Square(it.substring(0, 2)) to Square(it.substring(2, 4)) }
        )
    }

    /** Les candidats, dans l'ordre du moteur, avec leur SAN et leur éval. */
    private fun publishCandidates(position: Position, lines: Map<Int, RankedLine>) {
        // Les forces se mesurent AU TRAIT, point de vue commun à toutes les
        // lignes de la même position — les convertir au point de vue des
        // Blancs d'abord inverserait l'ordre une fois sur deux.
        val bestScore = lines[1]?.let { HintArrowBuilder.score(it.cp, it.mate) }
        val candidates = (1..3).mapNotNull { rank ->
            val line = lines[rank] ?: return@mapNotNull null
            val san = sanFor(position, line.lan) ?: return@mapNotNull null
            val white = toWhitePov(line, position.sideToMove)
            val score = HintArrowBuilder.score(line.cp, line.mate)
            val strength = if (bestScore != null && score != null) {
                HintArrowBuilder.strength(rank, score, bestScore)
            } else null
            Candidate(rank, san, line.lan, scoreText(white.cp, white.mate), strength)
        }
        ui = ui.copy(candidates = candidates)
    }

    // MARK: La revue complète

    /**
     * Classe TOUS les coups de la partie, puis en dresse le bilan.
     *
     * Une recherche par POSITION (il y en a une de plus que de coups), en
     * MultiPV 2 : le 2e choix vient gratuitement avec, et c'est lui qui permet
     * de distinguer « le seul bon coup » d'un coup simplement correct.
     *
     * Budget en NŒUDS et non en temps, comme iOS : un budget en temps rend la
     * classification irreproductible — la même partie analysée deux fois
     * rendrait deux verdicts selon la charge de l'appareil, ce qui est pénible
     * pour une fonction pédagogique. Le plafond en millisecondes ne mord qu'en
     * régime dégradé, où l'on préfère perdre la reproductibilité plutôt que
     * laisser l'analyse s'éterniser.
     */
    /**
     * La revue : chaque position de la ligne principale évaluée dans l'ORDRE,
     * la passe avance visiblement coup par coup, puis s'arrête — et le moteur
     * se tait. Part toute seule au chargement d'une partie ; ne refait pas
     * ce que le cache sait déjà (revue interrompue, partie déjà vue).
     */
    fun review() {
        if (moves.isEmpty() || ui.reviewing) return
        evalJob?.cancel()
        lazyJob?.cancel()
        reviewJob?.cancel()

        val snapshotPositions = positions.map { it.copy() }
        val snapshotMoves = moves.toList()
        val key = persistenceKey
        val book = book

        reviewJob = viewModelScope.launch {
            val evals = reviewEvals
            val missing = snapshotPositions.indices.filter { it !in evals }
            ui = ui.copy(reviewing = true, reviewDone = snapshotPositions.size - missing.size, reviewTotal = snapshotPositions.size)
            try {
                withContext(Dispatchers.IO) {
                    EngineService.use(getApplication()) { e ->
                        e.send("setoption name MultiPV value 2")
                        for (i in missing) {
                            ensureActive()
                            evals[i] = rankedEval(e, snapshotPositions[i])
                            withContext(Dispatchers.Main) {
                                ui = ui.copy(reviewDone = ui.reviewDone + 1)
                            }
                        }
                        refineBorderlineVerdicts(e, snapshotPositions, snapshotMoves, evals, book)
                    }
                }
                classify(snapshotPositions, snapshotMoves, evals, book)
            } finally {
                // Une classification interrompue n'est pas perdue : ce qui est
                // déjà classé part sur le disque, la revue reprendra là au
                // prochain chargement. `NonCancellable` : on est peut-être ici
                // parce qu'on a été annulé.
                if (key != null && evals.isNotEmpty()) {
                    withContext(NonCancellable + Dispatchers.IO) { store.save(key, evals.toMap()) }
                }
                ui = ui.copy(reviewing = false)
                // Revue TERMINÉE : le moteur s'arrête ici. La navigation lira
                // le cache, plus de recalcul à chaque coup.
                if (isGameReview) showCachedEval(ui.cursor) else evaluate()
            }
        }
    }

    // MARK: Affinage des verdicts limites

    /**
     * Recalcule PLUS PROFONDÉMENT les positions dont le verdict hésite.
     *
     * Mesuré côté iOS sur neuf parties de tournoi (887 coups, quatre budgets,
     * ~25 milliards de nœuds) : au budget de base, **4,62 %** des coups
     * reçoivent un verdict qu'un budget 33 fois supérieur contredirait — un
     * coup sur 22 passe à tort de « signalé » à « non signalé », ou l'inverse.
     *
     * Augmenter le budget PARTOUT serait un mauvais calcul : dix fois plus
     * d'effort ne ramène ce chiffre qu'à 1,69 %. Les erreurs ne sont pas
     * réparties au hasard, elles se concentrent autour des SEUILS — dépenser
     * du calcul sur un coup qui perd 40 points ne sert à rien, c'est une faute
     * à n'importe quelle profondeur. On ne recalcule donc que la bande
     * d'hésitation : ±2 points autour des trois frontières de signalement,
     * soit ~15 % des coups, pour 85 % des erreurs corrigées.
     *
     * Un coup de THÉORIE ou un coup FORCÉ n'est jamais affiné : leur étiquette
     * ne dépend pas de l'évaluation, ce serait payer jusqu'à 2 × 3 M nœuds
     * pour rien. Et en SURCHAUFFE on renonce à l'affinage plutôt qu'à la passe
     * de base : mieux vaut tous les coups classés normalement que la moitié
     * classés finement.
     */
    private suspend fun refineBorderlineVerdicts(
        engine: com.chesslab.engine.StockfishEngine,
        positions: List<Position>,
        moves: List<Move>,
        evals: MutableMap<Int, PositionEval>,
        book: List<EcoOpening>,
    ) {
        if (com.chesslab.engine.ThermalMonitor.isThrottling) return
        val refined = HashSet<Int>()

        for (index in moves.indices) {
            kotlinx.coroutines.currentCoroutineContext().ensureActive()
            val before = evals[index] ?: continue
            val after = evals[index + 1] ?: continue
            val mover = positions[index].sideToMove

            // Un coup de théorie ou un coup forcé porte son étiquette quoi
            // qu'en dise le moteur : affiner serait payer pour rien.
            val path = moves.take(index + 1).map { it.san }
            if (EcoOpeningLookup.isInBook(path, book)) continue
            if (legalMoveCount(positions[index]) == 1) continue

            fun lossNow(): Double {
                val b = moverWin(evals[index] ?: before, mover)
                val a = moverWin(evals[index + 1] ?: after, mover)
                return maxOf(0.0, b - a)
            }
            if (!isBorderline(lossNow())) continue

            // Le PARENT d'abord. La distance donnée à la règle d'arrêt se
            // mesure contre l'éval déjà connue de l'enfant, et réciproquement.
            if (index !in refined) {
                val fixedAfter = moverWin(evals[index + 1] ?: after, mover)
                refineOne(engine, positions[index], mover) { whiteWin ->
                    val beforeMover = if (mover == Piece.Color.white) whiteWin else 100 - whiteWin
                    distanceToNearestThreshold(maxOf(0.0, beforeMover - fixedAfter))
                }?.let { evals[index] = it; refined += index }
            }

            // RE-TEST entre les deux affinages : si celui du parent a déjà
            // sorti la perte de la bande d'hésitation, l'enfant n'a plus rien
            // à trancher — on s'épargne au moins son plancher d'un million de
            // nœuds.
            if (!isBorderline(lossNow())) continue
            if (index + 1 in refined) continue
            val fixedBefore = moverWin(evals[index] ?: before, mover)
            refineOne(engine, positions[index + 1], mover) { whiteWin ->
                val afterMover = if (mover == Piece.Color.white) whiteWin else 100 - whiteWin
                distanceToNearestThreshold(maxOf(0.0, fixedBefore - afterMover))
            }?.let { evals[index + 1] = it; refined += index + 1 }
        }
    }

    /** La probabilité de gain d'une position, DU POINT DE VUE de [mover]. */
    private fun moverWin(eval: PositionEval, mover: Piece.Color): Double {
        val white = eval.winPercentWhite
        return if (mover == Piece.Color.white) white else 100 - white
    }

    /**
     * Une recherche d'affinage sur UNE position, arrêtée dès qu'elle a
     * tranché — voir [RefinementStopRule]. La recherche n'est jamais quittée
     * puis relancée : relancer repaie l'arbre entier (mesuré ×13, pas ×10).
     */
    private suspend fun refineOne(
        engine: com.chesslab.engine.StockfishEngine,
        position: Position,
        mover: Piece.Color,
        lossDistance: (Double) -> Double,
    ): PositionEval? {
        if (terminalWinWhite(position) != null) return null
        val rule = RefinementStopRule()
        engine.send("position fen ${position.fen}")
        val lines = HashMap<Int, RankedLine>()
        val cap = com.chesslab.engine.DevicePerformance.refinementCapMs(getApplication())
        engine.search(
            "go nodes $REFINEMENT_NODES movetime $cap",
            timeoutMs = 60_000,
            stopWhen = { raw ->
                val info = parseInfo(raw)
                if (info == null || info.rank != 1) false
                else {
                    val white = toWhitePov(info.line, position.sideToMove)
                    val winWhite = white.mate?.let { EvalConversion.fromMate(it) }
                        ?: EvalConversion.fromCentipawns(white.cp ?: 0)
                    rule.shouldStop(info.depth, info.nodes, winWhite, lossDistance(winWhite))
                }
            },
        ) { line -> parseInfo(line)?.let { lines[it.rank] = it.line } }

        val best = lines[1] ?: return null
        val second = lines[2]
        val white = toWhitePov(best, position.sideToMove)
        val gap = if (second != null) winPercentMover(best) - winPercentMover(second) else null
        return PositionEval(
            cp = white.cp, mate = white.mate,
            bestLan = best.lan, gapToSecondBest = gap, secondBestLan = second?.lan,
            pv = best.pv,
        )
    }

    /**
     * Ce verdict est-il trop proche d'une frontière pour être tranché au
     * budget de base ? Seules comptent les frontières qui DÉCLENCHENT un
     * signalement : franchir Excellent/Bon ne change rien pour le lecteur,
     * les deux sont bons.
     */
    private fun isBorderline(loss: Double): Boolean =
        REFINEMENT_THRESHOLDS.any { kotlin.math.abs(loss - it) <= REFINEMENT_BAND }

    private fun distanceToNearestThreshold(loss: Double): Double =
        REFINEMENT_THRESHOLDS.minOf { kotlin.math.abs(loss - it) }

    /** Une recherche sur une position, en MultiPV 2. */
    private suspend fun rankedEval(engine: com.chesslab.engine.StockfishEngine, position: Position): PositionEval {
        terminalWinWhite(position)?.let {
            return PositionEval(null, null, null, null, pv = emptyList(), terminalWinWhite = it)
        }
        engine.send("position fen ${position.fen}")
        val lines = HashMap<Int, RankedLine>()
        // La surchauffe rabote le TRAVAIL demandé — les nœuds — et non le
        // temps accordé : le verdict reste comparable d'une exécution à
        // l'autre, seulement rendu sur une recherche moins profonde.
        val budget = com.chesslab.engine.DevicePerformance.classificationNodes(getApplication())
        val reviewNodes = com.chesslab.engine.ThermalMonitor.nodes(budget)
        val cap = com.chesslab.engine.DevicePerformance.classificationCapMs(getApplication())
        engine.search("go nodes $reviewNodes movetime $cap", timeoutMs = 20_000) { line ->
            parseInfo(line)?.let { lines[it.rank] = it.line }
        }
        val best = lines[1]
        val second = lines[2]
        val white = best?.let { toWhitePov(it, position.sideToMove) }
        // L'écart au 2e choix se lit DU POINT DE VUE DU TRAIT : c'est celui du
        // joueur dont on juge le coup.
        val gap = if (best != null && second != null) {
            winPercentMover(best) - winPercentMover(second)
        } else null
        return PositionEval(
            cp = white?.cp, mate = white?.mate,
            bestLan = best?.lan, gapToSecondBest = gap, secondBestLan = second?.lan,
            pv = best?.pv ?: emptyList(),
        )
    }

    /**
     * Le verdict de chaque coup, une fois toutes les positions évaluées.
     * Fonction pure hors du moteur : c'est ce qui la rend vérifiable.
     */
    private fun classify(
        positions: List<Position>,
        moves: List<Move>,
        evals: Map<Int, PositionEval>,
        book: List<EcoOpening>,
    ) {
        val qualities = HashMap<Int, MoveQuality>()
        val explanations = HashMap<Int, MoveExplanation>()
        val deltas = HashMap<Int, Double>()
        val entries = ArrayList<GameSummary.Companion.Entry>()
        val lossesByColor = mapOf(
            Piece.Color.white to ArrayList<Pair<Int, Double>>(),
            Piece.Color.black to ArrayList<Pair<Int, Double>>(),
        )

        for ((i, move) in moves.withIndex()) {
            val before = evals[i] ?: continue
            val after = evals[i + 1] ?: continue
            val parent = positions[i]
            val mover = parent.sideToMove

            val winBefore = if (mover == Piece.Color.white) before.winPercentWhite
            else 100 - before.winPercentWhite
            val winAfter = if (mover == Piece.Color.white) after.winPercentWhite
            else 100 - after.winPercentWhite

            val sanPath = moves.take(i + 1).map { it.san }
            val isBook = EcoOpeningLookup.isInBook(sanPath, book)
            val isForced = legalMoveCount(parent) == 1

            val boardAfter = Board(positions[i + 1].copy())
            val quality = MoveClassifier.classify(
                MoveClassifier.Input(
                    winPercentBefore = winBefore,
                    winPercentAfter = winAfter,
                    isBestMove = before.bestLan == move.lan,
                    gapToSecondBest = before.gapToSecondBest,
                    isBook = isBook,
                    isSacrifice = MoveClassifier.involvesSacrifice(move, boardAfter),
                    sacrificeImmediatelyRecaptured =
                        MoveClassifier.isImmediatelyRecaptured(move, moves.getOrNull(i + 1)),
                    bestMoveWasTactical = bestMoveIsTactical(before.bestLan, parent),
                    isForced = isForced,
                )
            )

            qualities[i] = quality
            val loss = max(0.0, winBefore - winAfter)
            deltas[i] = winAfter - winBefore
            entries += GameSummary.Companion.Entry(mover, quality, loss)
            lossesByColor[mover]!! += i to loss

            // Seulement les fautes : un bon coup n'a rien à expliquer, et la
            // variante d'après un bon coup raconte la suite de la partie, pas
            // une punition. `after.pv` est la réponse du moteur À CE COUP — la
            // réfutation, déjà payée par l'évaluation.
            if (quality.isFault) {
                MoveExplainer.explain(positions[i + 1], after.pv)?.let { explanations[i] = it }
            }
        }

        // Les poids de volatilité se calculent sur TOUTE la partie, POV Blancs,
        // position de départ comprise : chaque coup est pesé par ce qui bougeait
        // autour de lui, pas par sa seule perte.
        val whitePercents = positions.indices.map { evals[it]?.winPercentWhite ?: 50.0 }
        val weights = AccuracyScore.moveWeights(whitePercents)
        val accuracy = HashMap<Piece.Color, Double>()
        for ((color, losses) in lossesByColor) {
            AccuracyScore.accuracy(
                losses.map { it.second },
                losses.map { weights.getOrElse(it.first) { 1.0 } },
            )?.let { accuracy[color] = it }
        }

        val curve = positions.indices.map { i ->
            CurvePoint(
                ply = i,
                pawns = evals[i]?.pawnsWhite ?: 0.0,
                // Le point d'index i est ATTEINT par le coup i-1 : c'est la
                // qualité de ce coup-là qui marque le décrochage.
                quality = if (i == 0) null else qualities[i - 1],
            )
        }

        val summary = GameSummary.compute(entries, moves.size, accuracy)
        ui = ui.copy(
            qualities = qualities,
            explanations = explanations,
            winDeltas = deltas,
            curve = curve,
            summary = summary,
            betterLan = if (qualities[ui.cursor]?.isFault == true)
                evals[ui.cursor]?.bestLan else null,
        )
        if (summary.isComplete) persistMetrics(summary)
    }

    /**
     * Range le bilan chiffré AVEC la partie enregistrée, quand la ligne
     * principale est entièrement classée.
     *
     * La bibliothèque montre alors la précision sans rien recalculer, et la
     * mesure du niveau a une matière. Le lien passe par l'EMPREINTE de la
     * partie et non par son identité : l'écran d'analyse ne reçoit qu'un texte
     * PGN, jamais un numéro de ligne — et deux PGN aux en-têtes différents mais
     * aux mêmes coups se retrouvent.
     */
    private fun persistMetrics(summary: GameSummary) {
        val key = persistenceKey ?: return
        viewModelScope.launch(Dispatchers.IO) {
            val dao = LibraryDatabase.get(getApplication()).games()
            val start = positions.firstOrNull()?.fen ?: return@launch
            val lans = moves.map { it.lan }
            val record = dao.allOnce().firstOrNull { candidate ->
                candidate.analysisKey == key || matchesKey(candidate, key, start, lans)
            } ?: return@launch
            dao.setMetrics(
                id = record.id, key = key, version = ANALYSIS_VERSION,
                whiteAccuracy = summary.white.accuracy, blackAccuracy = summary.black.accuracy,
                whiteLoss = summary.white.averageLoss, blackLoss = summary.black.averageLoss,
                whiteClassified = summary.white.classifiedCount,
                blackClassified = summary.black.classifiedCount,
                whiteBook = summary.white.bookCount, blackBook = summary.black.bookCount,
            )
        }
    }

    /**
     * Une partie enregistrée porte-t-elle la ligne qu'on vient d'analyser ?
     * On recalcule son empreinte depuis son PGN — c'est le seul moyen, la
     * partie n'ayant pas encore de clé la première fois.
     */
    private fun matchesKey(record: GameRecord, key: String, start: String, lans: List<String>): Boolean {
        if (record.moveCount != lans.size) return false
        val cleaned = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(record.pgn)).firstOrNull()
            ?: record.pgn
        val parsed = runCatching { PgnParser.parse(cleaned) }.getOrNull() ?: return false
        val theirStart = parsed.startingPosition ?: Position.standard
        if (theirStart.fen != start) return false
        val mainline = parsed.moves.indices
            .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
            .sorted()
        val theirs = AnalysisEvalStore.key(
            theirStart.fen,
            mainline.mapNotNull { parsed.moves[it]?.lan },
        )
        return theirs == key
    }

    /**
     * Fabrique des puzzles à partir des FAUTES de la partie : chaque erreur,
     * gaffe ou occasion manquée devient une position à retrouver.
     *
     * Ce sont les puzzles qui valent le plus : la position est déjà arrivée sur
     * votre échiquier, et l'erreur est la vôtre.
     *
     * Budget TRIPLE de celui de la classification (900 000 nœuds contre
     * 300 000) : la séquence solution doit être sûre sur plusieurs coups, pas
     * seulement sur le premier. Le plafond suit la même proportion, sinon il
     * mordrait avant les nœuds et ramènerait le budget réel à celui de la
     * classification.
     */
    fun generatePuzzles() {
        if (ui.reviewing) return
        val evals = reviewEvals.toMap()
        if (evals.isEmpty()) { ui = ui.copy(puzzlesCreated = 0); return }

        evalJob?.cancel()
        val snapshotPositions = positions.map { it.copy() }
        val snapshotMoves = moves.toList()
        val qualities = ui.qualities
        val sourcePgn = pgn()

        reviewJob = viewModelScope.launch {
            ui = ui.copy(reviewing = true, reviewDone = 0, puzzlesCreated = null)
            var created = 0
            try {
                // L'occasion manquée est un candidat de choix : par définition,
                // il existait un coup nettement meilleur à retrouver.
                val candidates = snapshotMoves.indices.filter {
                    qualities[it] == MoveQuality.mistake || qualities[it] == MoveQuality.miss ||
                        qualities[it] == MoveQuality.blunder
                }
                ui = ui.copy(reviewTotal = candidates.size)
                val dao = LibraryDatabase.get(getApplication()).ownPuzzles()

                withContext(Dispatchers.IO) {
                    EngineService.use(getApplication()) { e ->
                        e.send("setoption name MultiPV value 2")
                        for ((done, i) in candidates.withIndex()) {
                            ensureActive()
                            withContext(Dispatchers.Main) { ui = ui.copy(reviewDone = done + 1) }
                            val parent = snapshotPositions[i]
                            // La même position ne donne qu'un puzzle : revoir
                            // deux fois la partie ne doit pas la doubler.
                            if (dao.countFor(parent.fen) > 0) continue

                            val deep = deepEval(e, parent)
                            val best = deep[1] ?: continue
                            val second = deep[2] ?: continue
                            // Sans écart net entre le meilleur coup et le
                            // suivant, il n'y a rien à TROUVER : deux coups qui
                            // se valent ne font pas un puzzle.
                            if (cpEquivalent(best) - cpEquivalent(second) <= 150) continue

                            val solution = PuzzleSolutionTrimmer.trim(best.pv, parent.fen)
                            if (solution.isEmpty()) continue

                            dao.insert(
                                OwnPuzzle(
                                    uid = java.util.UUID.randomUUID().toString(),
                                    fen = parent.fen,
                                    playedSan = snapshotMoves[i].san,
                                    solution = solution.joinToString(" "),
                                    theme = themeFor(parent, solution),
                                    // Un puzzle maison n'a pas de cote : on
                                    // affiche celle de la partie, pas une note
                                    // inventée. 0 = « sans cote » pour l'écran.
                                    rating = 0,
                                    createdAt = System.currentTimeMillis(),
                                    sourcePgn = sourcePgn,
                                )
                            )
                            created++
                        }
                    }
                }
            } finally {
                ui = ui.copy(reviewing = false, puzzlesCreated = created)
                evaluate()
            }
        }
    }

    fun clearPuzzleNotice() { ui = ui.copy(puzzlesCreated = null) }

    /**
     * Un score comparable, mat compris : un mat en 1 doit battre un mat en 3.
     *
     * iOS aplatit tout mat à ±10 000 dans ce chemin-ci, si bien qu'une position
     * où DEUX coups matent donne un écart nul — et le mat en un manqué, le plus
     * net des puzzles, était écarté. Son autre chemin de code (l'analyse en
     * continu) tient déjà compte de la distance ; c'est cette convention-là
     * qu'on retient des deux côtés.
     */
    private fun cpEquivalent(line: RankedLine): Int = line.mate?.let {
        if (it > 0) 10_000 - it else -10_000 - it
    } ?: (line.cp ?: 0)

    /** Une recherche PROFONDE, pour une solution de puzzle sûre sur plusieurs coups. */
    private suspend fun deepEval(
        engine: com.chesslab.engine.StockfishEngine,
        position: Position,
    ): Map<Int, RankedLine> {
        engine.send("position fen ${position.fen}")
        val lines = HashMap<Int, RankedLine>()
        val puzzleNodes = com.chesslab.engine.ThermalMonitor.nodes(PUZZLE_NODES.toLong())
        engine.search("go nodes $puzzleNodes movetime $PUZZLE_CAP_MS", timeoutMs = 30_000) { line ->
            parseInfo(line)?.let { lines[it.rank] = it.line }
        }
        return lines
    }

    /**
     * Le thème du puzzle, lu sur le premier coup de la solution — le même
     * détecteur que celui qui explique une faute. Sans motif nommable, c'est
     * de la « tactique », comme dans la bibliothèque Lichess.
     */
    private fun themeFor(parent: Position, solution: List<String>): String {
        val lan = solution.firstOrNull() ?: return "tactic"
        if (lan.length < 4) return "tactic"
        val board = Board(parent.copy())
        val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4)))
            ?: return "tactic"
        return when (TacticalMotifDetector.detect(move, board)) {
            is TacticalMotif.Checkmate -> "checkmate"
            is TacticalMotif.Fork -> "fork"
            is TacticalMotif.Pin -> "pin"
            is TacticalMotif.DiscoveredCheck -> "discoveredAttack"
            is TacticalMotif.HangingPiece -> "hangingPiece"
            null -> "tactic"
        }
    }

    /**
     * Le meilleur coup disponible (celui qu'on a pu RATER) est-il une tactique
     * nette — capture de matériel ou mat direct ? Sert à qualifier l'occasion
     * manquée : dans une position déjà gagnée, rater un mat ou une pièce en est
     * une, relâcher positionnellement non.
     */
    private fun bestMoveIsTactical(lan: String?, parent: Position): Boolean {
        if (lan == null || lan.length < 4) return false
        val to = Square(lan.substring(2, 4))
        val capturesMaterial = parent.pieces.any {
            it.square == to && it.color == parent.sideToMove.opposite
        }
        if (capturesMaterial) return true
        val board = Board(parent.copy())
        board.move(Square(lan.substring(0, 2)), to) ?: return false
        return board.state is Board.State.Checkmate
    }

    /** Nombre de coups légaux du camp au trait — 1 = coup forcé. */
    private fun legalMoveCount(position: Position): Int {
        val board = Board(position.copy())
        return position.pieces
            .filter { it.color == position.sideToMove }
            .sumOf { board.legalMoves(it.square).size }
    }

    // MARK: Lecture du moteur

    /** Une ligne de classement du moteur. */
    private data class RankedLine(val lan: String, val pv: List<String>, val cp: Int?, val mate: Int?)

    private data class ParsedInfo(
        val rank: Int,
        val depth: Int,
        val line: RankedLine,
        /** Les nœuds cherchés — le plancher de l'arrêt anticipé s'y mesure. */
        val nodes: Long? = null,
    )

    private data class WhitePov(val cp: Int?, val mate: Int?)

    /**
     * Le score UCI est TOUJOURS du point de vue du camp au trait ; on le ramène
     * au point de vue des Blancs, sans quoi l'évaluation changerait de signe à
     * chaque coup.
     */
    private fun toWhitePov(line: RankedLine, sideToMove: Piece.Color): WhitePov {
        val sign = if (sideToMove == Piece.Color.white) 1 else -1
        return WhitePov(line.cp?.let { it * sign }, line.mate?.let { it * sign })
    }

    /** Probabilité de gain DU CAMP AU TRAIT à la position interrogée. */
    private fun winPercentMover(line: RankedLine): Double =
        line.mate?.let { EvalConversion.fromMate(it) }
            ?: EvalConversion.fromCentipawns(line.cp ?: 0)

    /** Une ligne `info` du moteur → rang, profondeur, coup, variante, score. */
    private fun parseInfo(line: String): ParsedInfo? {
        if (!line.startsWith("info ") || !line.contains(" score ")) return null
        val depth = line.substringAfter(" depth ", "").substringBefore(" ").toIntOrNull() ?: return null
        val pv = line.substringAfter(" pv ", "").trim().split(" ").filter { it.isNotEmpty() }
        if (pv.isEmpty()) return null
        // `multipv` est absent quand MultiPV vaut 1 : c'est alors le rang 1.
        val rank = line.substringAfter(" multipv ", "").substringBefore(" ").toIntOrNull() ?: 1
        val mate = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
        val cp = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
        if (mate == null && cp == null) return null
        val nodes = line.substringAfter(" nodes ", "").substringBefore(" ").toLongOrNull()
        return ParsedInfo(rank, depth, RankedLine(pv.first(), pv, cp, mate), nodes)
    }

    /** Ce qu'affiche une position finie : le signe, pas un chiffre. */
    private fun terminalText(winWhite: Double): String = when {
        winWhite > 50 -> "1−0"
        winWhite < 50 -> "0−1"
        else -> "½−½"
    }

    /** L'évaluation en clair, POV Blancs. */
    private fun scoreText(cp: Int?, mate: Int?): String = when {
        mate != null -> if (mate > 0) "+M$mate" else "−M${-mate}"
        cp != null -> {
            val pawns = cp / 100.0
            (if (pawns >= 0) "+%.2f" else "−%.2f").format(abs(pawns))
        }
        else -> ""
    }

    /** Le SAN d'un coup en LAN, joué sur une position — pour nommer un candidat. */
    private fun sanFor(position: Position, lan: String): String? {
        if (lan.length < 4) return null
        val board = Board(position.copy())
        val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return null
        if (board.state is Board.State.Promotion) {
            val kind = when (lan.getOrNull(4)?.lowercaseChar()) {
                'n' -> Piece.Kind.knight
                'b' -> Piece.Kind.bishop
                'r' -> Piece.Kind.rook
                else -> Piece.Kind.queen
            }
            return board.completePromotion(move, kind).san
        }
        return move.san
    }

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    companion object {
        // Le budget d'une position de revue et son plafond de temps vivent
        // désormais dans `DevicePerformance` : ils dépendent de l'appareil,
        // comme sur iOS. Un budget unique servait mal les deux bouts — trop
        // lourd sur un téléphone d'entrée de gamme, trop timide sur un récent.

        /**
         * La demi-largeur de la bande d'hésitation, en points de probabilité
         * de gain, autour des seuils qui déclenchent un signalement. Choisie
         * chronomètre en main sur la courbe mesurée côté iOS :
         *
         *     ±1,0 → ×1,96   59 % des erreurs corrigées   il reste 1,92 %
         *     ±1,5 → ×2,42   73 %                         il reste 1,24 %
         *     ±2,0 → ×2,95   85 %                         il reste 0,68 %   ← ici
         *     ±3,0 → ×3,81   93 %                         il reste 0,34 %
         *
         * Au-delà de ±2 on paie surtout des recalculs qui CONFIRMENT le
         * verdict.
         */
        const val REFINEMENT_BAND = 2.0

        /**
         * Le budget de la seconde recherche.
         *
         * ⚠️ Hypothèse réfutée par la mesure : la seconde recherche, lancée
         * sur la MÊME position sans réinitialiser le moteur, n'hérite d'aucune
         * remise de la table de transposition — un coup affiné coûte ×13,1 un
         * coup de base. Le bilan reste bon (≈ ×2,2 au total avec l'arrêt
         * anticipé, contre ×11,4 pour tout approfondir), mais il vaut par le
         * CIBLAGE, pas par une remise qui n'existe pas.
         */
        const val REFINEMENT_NODES = 3_000_000

        /**
         * La version du BARÈME rangée avec chaque bilan. À incrémenter dès que
         * change quoi que ce soit qui déplace les valeurs : seuils de
         * classification, budget de recherche, formule de précision,
         * traitement de la théorie. Sans elle, une moyenne glissante
         * mélangerait des parties mesurées à des aunes différentes — et
         * personne ne le verrait. Elle va de pair avec le profil moteur du
         * cache disque : les deux se changent ensemble.
         */
        const val ANALYSIS_VERSION = 1

        /** Les trois frontières qui déclenchent un signalement. */
        val REFINEMENT_THRESHOLDS = listOf(
            MoveClassifier.INACCURACY_THRESHOLD,
            MoveClassifier.MISTAKE_THRESHOLD,
            MoveClassifier.BLUNDER_THRESHOLD,
        )

        /** Le triple du budget de classification : une solution de puzzle doit tenir. */
        const val PUZZLE_NODES = 900_000
        const val PUZZLE_CAP_MS = 4_500
    }
}
