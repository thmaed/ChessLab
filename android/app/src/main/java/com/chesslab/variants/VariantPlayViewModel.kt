package com.chesslab.variants

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.engine.FairyEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.s

data class VariantUiState(
    val position: Position = Position.standard,
    val variant: Variant? = null,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "",
    val uciLog: List<String> = emptyList(),
    /** Les pièces en main, par camp — vide partout sauf au Crazyhouse. */
    val pocket: Map<Piece.Color, Map<Piece.Kind, Int>> = emptyMap(),
    /** La pièce de la réserve qu'on s'apprête à poser. */
    val selectedDrop: Piece.Kind? = null,
    val thinking: Boolean = false,
    val gameOver: Boolean = false,
    val ready: Boolean = false,
    /** Personne ne joue contre le moteur : il ne fait qu'arbitrer. */
    val twoPlayer: Boolean = false,
    /** Le numéro de la position Chess960 en cours, quand il y en a un. */
    val chess960Number: Int? = null,
    /** Les cases murées, lues dans la FEN du moteur. */
    val walls: Set<Square> = emptySet(),
    /** Les demi-coups joués — compté à part : les Barricades aléatoires repartent d'une FEN à chaque coup. */
    val plies: Int = 0,
    /** Ce qui a été réglé avant la partie : force, couleur, cadence, aides. */
    val settings: VariantSettings = VariantSettings(),
    /** Le camp de l'utilisateur — le plateau se retourne avec lui. */
    val userColor: Piece.Color = Piece.Color.white,
    /** Millisecondes restantes, ou `null` sans pendule. */
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    /** L'évaluation de la position, POV Blancs — la barre s'en sert. */
    val evalCp: Int? = null,
    val evalMate: Int? = null,
    /** Les flèches d'indice, quand l'indice est demandé. */
    val hints: List<com.chesslab.ui.BoardArrow> = emptyList(),
    val hintWanted: Boolean = false,
    /** L'alerte à montrer quand le coup qu'on vient de jouer coûte cher. */
    val blunderWarning: com.chesslab.play.BlunderSeverity? = null,
    /** Le moteur vient de refuser la nulle — l'écran le dit, puis l'efface. */
    val drawDeclined: Boolean = false,
    /** Le mot de la fin : « Échec et mat — vous gagnez », « Abandon »… */
    val outcome: String? = null,
)

/**
 * Une partie de variante, ARBITRÉE par Fairy-Stockfish.
 *
 * Pendant réduit d'`EngineLegalityPlayViewModel`. Les règles ne sont pas
 * celles de `chesskit` : la position vient de la FEN que rend `d`, et les
 * coups légaux de `go perft 1`. Réimplémenter sept jeux de règles serait long
 * et faux — le moteur les connaît déjà.
 */
class VariantPlayViewModel(app: Application) : AndroidViewModel(app) {

    private var startFen: String? = null

    /**
     * La position d'où repart la ligne courante, pour la revoir.
     *
     * Aux Barricades ALÉATOIRES, les murs bougent et la base est rebasée en
     * cours de partie : la revue porte alors sur le segment depuis le dernier
     * déplacement de murs, pas sur la partie entière. C'est ce que le moteur
     * sait reproduire — un journal de coups ne contient pas un tirage.
     */
    fun startFen(): String? = startFen
    private var legal: List<String> = emptyList()

    /**
     * Les demi-coups déjà REBASÉS : aux Barricades aléatoires, la position se
     * réécrit à chaque coup et le journal repart de zéro, mais le compteur
     * affiché, lui, doit continuer de monter.
     */
    private var rebased = 0

    /**
     * Le camp de l'utilisateur, tiré une fois pour toutes au démarrage quand
     * il a demandé le hasard : le retirer à chaque consultation ferait changer
     * de camp au milieu de la partie.
     */
    private var humanColor = Piece.Color.white

    /** La pendule, quand la cadence en demande une. */
    private val clock = VariantClock(viewModelScope).apply {
        onTick = { white, black -> ui = ui.copy(whiteClockMs = white, blackClockMs = black) }
        onFlag = { flagged ->
            val word = s(
                if (flagged == humanColor || ui.twoPlayer) R.string.outcome_flag_you
                else R.string.outcome_flag_opponent
            )
            ui = ui.copy(gameOver = true, status = word, outcome = word, hints = emptyList())
        }
    }

    /** À deux, les DEUX camps sont humains : c'est la seule différence. */
    private val humanToMove: Boolean
        get() = ui.twoPlayer || ui.position.sideToMove == humanColor

    var ui by mutableStateOf(VariantUiState(status = s(R.string.engine_starting)))
        private set

    /**
     * [chess960Number] : la position voulue, quand l'écran de réglage l'a
     * choisie. Sans lui, un tirage au sort — c'est ce que faisait la tuile
     * avant que le numéro existe.
     */
    fun load(
        variantId: String,
        chess960Number: Int? = null,
        twoPlayer: Boolean = false,
        settings: VariantSettings = VariantSettings(),
    ) {
        val variant = VariantCatalog.byId(variantId) ?: return
        humanColor = when (settings.colorChoice) {
            com.chesslab.play.PlayerColorChoice.white -> Piece.Color.white
            com.chesslab.play.PlayerColorChoice.black -> Piece.Color.black
            com.chesslab.play.PlayerColorChoice.random ->
                if (kotlin.random.Random.nextBoolean()) Piece.Color.white else Piece.Color.black
        }
        val number = chess960Number ?: settings.chess960Number
        clock.reset(settings.timeControl)
        ui = ui.copy(
            variant = variant, uciLog = emptyList(), gameOver = false, ready = false,
            status = s(R.string.engine_starting), lastMove = null,
            twoPlayer = twoPlayer || settings.twoPlayers, chess960Number = number,
            settings = settings, userColor = humanColor,
            whiteClockMs = clock.remaining(Piece.Color.white),
            blackClockMs = clock.remaining(Piece.Color.black),
            evalCp = null, evalMate = null, hints = emptyList(), hintWanted = false,
            blunderWarning = null, plies = 0, drawDeclined = false, outcome = null,
        )
        rebased = 0
        startFen = startingFen(variant, number)
        refresh()
    }

    /** L'écran s'en va : la pendule s'arrête, sinon le drapeau tombe derrière. */
    fun pauseForBackground() {
        if (ui.gameOver) return
        clock.pause()
    }

    fun resumeFromBackground() {
        if (ui.gameOver || !ui.ready) return
        clock.startTurn(ui.position.sideToMove)
    }

    fun newGame() {
        val variant = ui.variant ?: return
        // Une NOUVELLE position à chaque partie, sauf si l'on en avait choisi
        // une : on ne remplace pas un choix par un tirage au sort.
        rebased = 0
        startFen = startingFen(variant, ui.chess960Number)
        clock.reset(ui.settings.timeControl)
        ui = ui.copy(
            uciLog = emptyList(), gameOver = false, lastMove = null, plies = 0,
            whiteClockMs = clock.remaining(Piece.Color.white),
            blackClockMs = clock.remaining(Piece.Color.black),
            evalCp = null, evalMate = null, hints = emptyList(), blunderWarning = null,
            drawDeclined = false, outcome = null,
        )
        refresh()
    }

    private fun startingFen(variant: Variant, number: Int?): String? = when {
        // Les murs mobiles posent les leurs au hasard avant le premier coup :
        // la variante ne peut pas les porter, ils changent à chaque partie.
        variant.wallsMove -> BarricadesConfiguration.openingPosition()
        !variant.chess960 -> null
        number != null -> Chess960Position.startingFen(number) ?: VariantCatalog.randomChess960Fen()
        else -> VariantCatalog.randomChess960Fen()
    }

    /** Interroge le moteur et remet à jour le plateau. */
    private fun refresh(afterMove: Pair<Square, Square>? = null): Job = viewModelScope.launch {
        val variant = ui.variant ?: return@launch
        ui = ui.copy(thinking = true)

        var query = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                if (variant.chess960) engine.send("setoption name UCI_Chess960 value true")
                else engine.send("setoption name UCI_Chess960 value false")
                engine.queryPosition(variant.uci, startFen, ui.uciLog)
            }
        }

        // Les murs MOBILES se redéploient après chaque demi-coup, et la
        // position qui en sort devient la nouvelle base : le tirage ne figure
        // dans aucun coup, donc « départ + coups » ne le reproduirait pas. Il
        // faut redemander les coups légaux, puisque des murs déplacés
        // n'arrêtent plus les mêmes lignes.
        if (query != null && variant.wallsMove && ui.uciLog.isNotEmpty()) {
            BarricadesConfiguration.relocatingWalls(query.fen)?.let { moved ->
                rebased += ui.uciLog.size
                startFen = moved
                ui = ui.copy(uciLog = emptyList())
                query = withContext(Dispatchers.IO) {
                    FairyEngine.use(getApplication()) { engine ->
                        engine.queryPosition(variant.uci, moved, emptyList())
                    }
                }
            }
        }
        ui = ui.copy(thinking = false)

        val answer = query
        if (answer == null) {
            ui = ui.copy(status = s(R.string.variant_engine_unavailable), ready = false)
            return@launch
        }

        // Le moteur propose de PRENDRE les murs mobiles : faute de région de
        // mobilité — impossible à figer sur des murs qui bougent — il y voit
        // des pièces blanches sans valeur. On retire ces coups-là, et rien
        // d'autre : toute la légalité reste la sienne.
        legal = if (variant.wallsMove) BarricadesConfiguration.removingWallCaptures(answer.legalMoves, answer.fen)
        else answer.legalMoves
        val position = parse(answer.fen) ?: Position.standard
        val pocket = CrazyhouseFen.pocket(answer.fen)
        val walls = if (variant.hasWalls) BarricadesFen.wallSquares(answer.fen).toSet() else emptySet()
        val over = legal.isEmpty()

        ui = ui.copy(
            position = position,
            selected = null,
            selectedDrop = null,
            legalTargets = emptySet(),
            pocket = pocket,
            lastMove = afterMove ?: ui.lastMove,
            checkedKing = if (answer.inCheck) kingSquare(position, position.sideToMove) else null,
            walls = walls,
            plies = rebased + ui.uciLog.size,
            gameOver = over,
            ready = true,
            status = when {
                over -> s(R.string.game_over)
                // À deux, dire « à vous » ne dit rien : c'est la COULEUR au
                // trait qui désigne celui dont c'est le tour.
                ui.twoPlayer -> s(
                    if (position.sideToMove == Piece.Color.white) R.string.white_to_move
                    else R.string.black_to_move
                )
                position.sideToMove == humanColor -> s(R.string.your_turn)
                else -> s(R.string.engine_thinking)
            },
        )

        if (over) {
            clock.stop()
            ui = ui.copy(outcome = ui.outcome ?: s(R.string.game_over), hints = emptyList())
            return@launch
        }

        clock.startTurn(position.sideToMove)
        if (!ui.twoPlayer && position.sideToMove != humanColor) {
            askEngine()
        } else {
            refreshEvalBar()
            if (ui.hintWanted) startHint()
        }
    }

    // MARK: Barre d'évaluation

    private var evalJob: Job? = null

    /**
     * La barre parle de la position AFFICHÉE, pas de la recherche du moteur :
     * quand c'est à l'utilisateur de jouer, personne ne cherche, et sans cette
     * passe la barre resterait figée sur le dernier coup de l'ordinateur.
     */
    private fun refreshEvalBar() {
        if (!ui.settings.showEvalBar) return
        val variant = ui.variant ?: return
        val log = ui.uciLog
        val whiteToMove = ui.position.sideToMove == Piece.Color.white
        evalJob?.cancel()
        evalJob = viewModelScope.launch {
            val result = withContext(Dispatchers.IO) {
                FairyEngine.use(getApplication()) { engine ->
                    engine.evaluate(variant.uci, startFen, log, movetimeMs = 300, whiteToMove = whiteToMove)
                }
            }
            if (log != ui.uciLog) return@launch
            if (result != null) ui = ui.copy(evalCp = result.cp, evalMate = result.mate)
        }
    }

    // MARK: Indice

    private var hintJob: Job? = null

    fun toggleHint() {
        if (!ui.settings.hintsEnabled || ui.gameOver) return
        if (ui.hintWanted) {
            ui = ui.copy(hintWanted = false, hints = emptyList())
            hintJob?.cancel()
            return
        }
        ui = ui.copy(hintWanted = true)
        startHint()
    }

    private fun startHint() {
        val variant = ui.variant ?: return
        if (!ui.hintWanted || ui.gameOver || !humanToMove) return
        val log = ui.uciLog
        hintJob?.cancel()
        hintJob = viewModelScope.launch {
            val lines = withContext(Dispatchers.IO) {
                FairyEngine.use(getApplication()) { engine ->
                    engine.hintLines(variant.uci, startFen, log, movetimeMs = 1_500)
                }
            } ?: return@launch
            if (log != ui.uciLog || !ui.hintWanted) return@launch
            ui = ui.copy(hints = com.chesslab.ui.HintArrowBuilder.build(lines.first, lines.second))
        }
    }

    // MARK: Alerte gaffe

    /**
     * L'alerte arrive APRÈS le coup, comme en mode « Contre l'ordinateur » :
     * prévenir avant obligerait à faire attendre le joueur à chaque coup.
     */
    private fun checkBlunder(beforeLog: List<String>, afterLog: List<String>) {
        if (!ui.settings.blunderAlertEnabled) return
        val variant = ui.variant ?: return
        viewModelScope.launch {
            val pair = withContext(Dispatchers.IO) {
                FairyEngine.use(getApplication()) { engine ->
                    val before = engine.search(variant.uci, startFen, beforeLog, movetimeMs = 250)
                    val after = engine.search(variant.uci, startFen, afterLog, movetimeMs = 250)
                    before to after
                }
            } ?: return@launch
            val (before, after) = pair
            val beforeCp = before.cp ?: (if (before.mate != null) 0 else return@launch)
            val afterCp = after.cp ?: (if (after.mate != null) 0 else return@launch)
            val severity = com.chesslab.play.BlunderAlert.severity(
                beforeCp = beforeCp, beforeMate = before.mate,
                afterCp = afterCp, afterMate = after.mate,
            ) ?: return@launch
            // La position a bougé depuis : l'alerte ne porterait plus sur le
            // coup qu'on vient de jouer, et reprendre n'y changerait rien.
            if (afterLog != ui.uciLog || ui.gameOver) return@launch
            ui = ui.copy(blunderWarning = severity)
        }
    }

    fun dismissBlunderWarning() { ui = ui.copy(blunderWarning = null) }

    /** Reprendre le coup regretté — et celui de l'ordinateur avec, s'il a répondu. */
    fun takebackAfterBlunderWarning() {
        val log = ui.uciLog
        if (log.isEmpty()) return
        val back = if (!ui.twoPlayer && ui.position.sideToMove == humanColor && log.size >= 2) 2 else 1
        ui = ui.copy(blunderWarning = null, uciLog = log.dropLast(back), hints = emptyList())
        refresh()
    }

    // MARK: Abandon et nulle

    /** Dernière évaluation du MOTEUR, de son point de vue (positif = il se voit mieux). */
    private var lastEngineEvalCp: Int? = null

    fun resign() {
        if (ui.gameOver) return
        clock.stop()
        val word = s(R.string.outcome_resigned)
        ui = ui.copy(gameOver = true, status = word, outcome = word, hints = emptyList())
    }

    /**
     * Même règle qu'en mode « Contre l'ordinateur » : il accepte s'il ne se
     * voit pas mieux qu'une quasi-égalité sur son dernier coup, refuse
     * sinon — et refuse tant qu'il n'a pas joué, faute d'avoir un avis.
     */
    fun offerDraw() {
        if (ui.gameOver || ui.thinking) return
        val cp = lastEngineEvalCp
        if (cp == null || kotlin.math.abs(cp) > DRAW_ACCEPTANCE_CP) {
            ui = ui.copy(drawDeclined = true)
            return
        }
        clock.stop()
        val word = s(R.string.outcome_draw_agreed)
        ui = ui.copy(gameOver = true, status = word, outcome = word, hints = emptyList())
    }

    fun dismissDrawDeclined() { ui = ui.copy(drawDeclined = false) }

    private fun askEngine(): Job = viewModelScope.launch {
        val variant = ui.variant ?: return@launch
        val strength = ui.settings.strength
        val engineColor = ui.position.sideToMove
        ui = ui.copy(thinking = true, status = s(R.string.engine_thinking))
        val result = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                engine.search(
                    variant = variant.uci,
                    startFen = startFen,
                    uciLog = ui.uciLog,
                    movetimeMs = clock.movetimeFor(engineColor),
                    depth = strength.maxDepth,
                    setup = strength.fairySetupCommands,
                )
            }
        }
        ui = ui.copy(thinking = false)
        val best = result?.bestLan
        // Le score du moteur, DE SON point de vue : c'est lui qu'interroge la
        // règle de nulle. On le relève même quand la barre est éteinte — un
        // avis ne se demande pas deux fois.
        result?.cp?.let { lastEngineEvalCp = it }
        if (ui.settings.showEvalBar && result != null && (result.cp != null || result.mate != null)) {
            val sign = if (engineColor == Piece.Color.white) 1 else -1
            ui = ui.copy(evalCp = result.cp?.let { it * sign }, evalMate = result.mate?.let { it * sign })
        }
        if (best == null || best == "(none)") { ui = ui.copy(status = s(R.string.engine_silent)); return@launch }
        clock.stopAndIncrement()
        ui = ui.copy(uciLog = ui.uciLog + best)
        refresh(Square(best.substring(0, 2)) to Square(best.substring(2, 4)))
    }



    /**
     * Choisit — ou repose — une pièce de SA réserve. La réserve adverse est un
     * relevé, pas une commande : on la montre pour savoir ce qui peut nous
     * tomber dessus, elle ne se touche pas.
     */
    fun selectPocketPiece(kind: Piece.Kind) {
        if (ui.thinking || ui.gameOver || !ui.ready) return
        if (!humanToMove) return
        if ((ui.pocket[ui.position.sideToMove]?.get(kind) ?: 0) <= 0) return

        if (ui.selectedDrop == kind) {
            ui = ui.copy(selectedDrop = null, legalTargets = emptySet())
            return
        }
        val prefix = CrazyhouseFen.letter(kind) + "@"
        val targets = legal
            .filter { it.startsWith(prefix) && it.length == prefix.length + 2 }
            .map { Square(it.takeLast(2)) }
            .toSet()
        ui = ui.copy(selected = null, selectedDrop = kind, legalTargets = targets)
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || !ui.ready) return
        if (!humanToMove) return

        // Une pose : la pièce vient de la main, pas d'une case. Le coup joué
        // est marqué sur sa seule case d'arrivée — une pose n'a pas d'origine.
        ui.selectedDrop?.let { kind ->
            if (square in ui.legalTargets) {
                commit(CrazyhouseFen.letter(kind) + "@" + square.notation, square to square)
            } else {
                ui = ui.copy(selectedDrop = null, legalTargets = emptySet())
            }
            return
        }

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            val prefix = selected.notation + square.notation
            // une promotion ? le moteur l'aura listée avec son suffixe
            val move = legal.firstOrNull { it == prefix }
                ?: legal.firstOrNull { it.startsWith(prefix) && it.length == 5 }
                ?: return
            commit(move, selected to square)
            return
        }

        val piece = ui.position.piece(square)
        ui = if (piece != null && piece.color == ui.position.sideToMove && humanToMove) {
            val targets = legal
                .filter { it.length >= 4 && it.substring(0, 2) == square.notation }
                .map { Square(it.substring(2, 4)) }
                .toSet()
            ui.copy(selected = square, selectedDrop = null, legalTargets = targets)
        } else {
            ui.copy(selected = null, selectedDrop = null, legalTargets = emptySet())
        }
    }

    /**
     * Enregistre le coup d'un HUMAIN : la pendule bascule, les flèches
     * s'effacent, et le coup passe au crible de l'alerte de gaffe.
     */
    private fun commit(move: String, marks: Pair<Square, Square>) {
        val before = ui.uciLog
        clock.stopAndIncrement()
        hintJob?.cancel()
        ui = ui.copy(uciLog = before + move, hints = emptyList(), blunderWarning = null)
        checkBlunder(before, ui.uciLog)
        refresh(marks)
    }

    /**
     * La FEN d'une variante peut porter des champs en plus (« +0+0 » aux Trois
     * échecs), une réserve entre crochets et le `~` d'une pièce promue. Le
     * plateau n'a besoin que des six premiers champs, débarrassés de tout cela.
     */
    private fun parse(fen: String): Position? {
        // Les murs disparaissent AVANT `chesskit` : le « W » n'est une pièce
        // que pour le moteur, et la lettre ferait refuser toute la position.
        val fields = BarricadesFen.forChessKit(CrazyhouseFen.boardFen(fen)).split(" ").filter { it.isNotEmpty() }
        if (fields.size < 4) return null
        val six = fields.take(4) + listOf(fields.getOrNull(4) ?: "0", fields.getOrNull(5) ?: "1")
        return FenParser.parse(six.joinToString(" "))
    }

    private companion object {
        /** Écart d'évaluation en deçà duquel l'ordinateur accepte une nulle. */
        const val DRAW_ACCEPTANCE_CP = 50
    }

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square
}
