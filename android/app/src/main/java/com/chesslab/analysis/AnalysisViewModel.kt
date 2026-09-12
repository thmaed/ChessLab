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
import com.chesslab.puzzles.OwnPuzzle
import com.chesslab.puzzles.PuzzleSolutionTrimmer
import com.chesslab.ui.s
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
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
data class Candidate(val rank: Int, val san: String, val lan: String, val eval: String)

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
    /** Le nombre de puzzles que la dernière génération a créés, à annoncer. */
    val puzzlesCreated: Int? = null,
) {
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
    val canReview: Boolean get() = sanMoves.isNotEmpty() && !reviewing
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

    /** Les évaluations de la revue, une par POSITION (il y en a une de plus que de coups). */
    private var reviewEvals: MutableMap<Int, PositionEval> = HashMap()

    var ui by mutableStateOf(AnalysisUiState(status = s(R.string.analysis_paste)))
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

    fun setArrowMode(mode: ArrowMode) {
        ui = ui.copy(arrowMode = mode)
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

        val parsed = try {
            PgnParser.parse(text)
        } catch (e: Exception) {
            ui = ui.copy(error = "PGN illisible : ${e.message}")
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
        goTo(moves.size - 1)
    }

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
        )
        evaluate()
    }

    fun previous() = goTo(ui.cursor - 1)
    fun next() = goTo(ui.cursor + 1)

    /** Jouer un coup candidat, c'est aller le voir : il devient le coup courant. */
    fun playCandidate(candidate: Candidate) {
        val at = ui.cursor
        val position = positions.getOrNull(at + 1) ?: return
        val board = Board(position.copy())
        val from = Square(candidate.lan.substring(0, 2))
        val to = Square(candidate.lan.substring(2, 4))
        val move = board.move(from, to) ?: return
        val done = if (board.state is Board.State.Promotion)
            board.completePromotion(move, Piece.Kind.queen) else move

        // On COUPE la suite : explorer un candidat crée une nouvelle ligne.
        // Rejouer la partie d'origine demande de la recharger, ce qui est
        // fidèle à ce que fait iOS quand on suit une variante depuis le bout.
        positions = positions.take(at + 2) + board.position.copy()
        moves = moves.take(at + 1) + done
        reviewEvals.clear()
        ui = ui.copy(
            sanMoves = moves.map { it.san },
            qualities = emptyMap(), explanations = emptyMap(), winDeltas = emptyMap(),
            curve = emptyList(), summary = null,
        )
        goTo(moves.size - 1)
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
        if (ui.reviewing) return
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
                        e.search("go depth 18", timeoutMs = 30_000) { line ->
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
                ui = ui.copy(thinking = false)
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
        val candidates = (1..3).mapNotNull { rank ->
            val line = lines[rank] ?: return@mapNotNull null
            val san = sanFor(position, line.lan) ?: return@mapNotNull null
            val white = toWhitePov(line, position.sideToMove)
            Candidate(rank, san, line.lan, scoreText(white.cp, white.mate))
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
    fun review() {
        if (moves.isEmpty() || ui.reviewing) return
        evalJob?.cancel()
        reviewJob?.cancel()

        val snapshotPositions = positions.map { it.copy() }
        val snapshotMoves = moves.toList()
        val assets = getApplication<Application>().assets
        val book = EcoOpeningLoader.bookLines(assets)

        reviewJob = viewModelScope.launch {
            ui = ui.copy(reviewing = true, reviewDone = 0, reviewTotal = snapshotPositions.size)
            val evals = HashMap<Int, PositionEval>()
            try {
                withContext(Dispatchers.IO) {
                    EngineService.use(getApplication()) { e ->
                        e.send("setoption name MultiPV value 2")
                        for ((i, position) in snapshotPositions.withIndex()) {
                            ensureActive()
                            evals[i] = rankedEval(e, position)
                            withContext(Dispatchers.Main) {
                                ui = ui.copy(reviewDone = i + 1)
                            }
                        }
                    }
                }
                reviewEvals = evals
                classify(snapshotPositions, snapshotMoves, evals, book)
            } finally {
                ui = ui.copy(reviewing = false)
                // La position affichée retrouve son analyse en continu.
                evaluate()
            }
        }
    }

    /** Une recherche sur une position, en MultiPV 2. */
    private suspend fun rankedEval(engine: com.chesslab.engine.StockfishEngine, position: Position): PositionEval {
        terminalWinWhite(position)?.let {
            return PositionEval(null, null, null, null, emptyList(), terminalWinWhite = it)
        }
        engine.send("position fen ${position.fen}")
        val lines = HashMap<Int, RankedLine>()
        engine.search("go nodes $REVIEW_NODES movetime $REVIEW_CAP_MS", timeoutMs = 20_000) { line ->
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
            bestLan = best?.lan, gapToSecondBest = gap, pv = best?.pv ?: emptyList(),
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

        ui = ui.copy(
            qualities = qualities,
            explanations = explanations,
            winDeltas = deltas,
            curve = curve,
            summary = GameSummary.compute(entries, moves.size, accuracy),
            betterLan = if (qualities[ui.cursor]?.isFault == true)
                evals[ui.cursor]?.bestLan else null,
        )
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
        engine.search("go nodes $PUZZLE_NODES movetime $PUZZLE_CAP_MS", timeoutMs = 30_000) { line ->
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

    private data class ParsedInfo(val rank: Int, val depth: Int, val line: RankedLine)

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
        return ParsedInfo(rank, depth, RankedLine(pv.first(), pv, cp, mate))
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

    private companion object {
        /**
         * 300 000 nœuds, comme iOS : ~600-750 ms en milieu de partie sur un
         * téléphone récent, et la profondeur atteinte s'adapte toute seule — le
         * débit en nœuds/seconde baisse quand la position se complique.
         */
        const val REVIEW_NODES = 300_000

        /**
         * Le plafond qui empêche une revue de quarante coups de s'éterniser sur
         * un appareil lent. UCI s'arrête à la première limite atteinte.
         */
        const val REVIEW_CAP_MS = 1_500

        /** Le triple du budget de classification : une solution de puzzle doit tenir. */
        const val PUZZLE_NODES = 900_000
        const val PUZZLE_CAP_MS = 4_500
    }
}
