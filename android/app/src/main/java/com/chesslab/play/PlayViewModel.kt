package com.chesslab.play

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
import com.chesslab.library.Autosave
import com.chesslab.library.GameRecorder
import com.chesslab.library.LibraryDatabase
import com.chesslab.maia.MaiaOpponent
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.settings.SettingsStore
import com.chesslab.sound.SoundPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.HintArrowBuilder
import com.chesslab.ui.s

data class PlayUiState(
    val position: Position = Position.standard,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    /** Les deux cases d'un coup soufflé par l'indice. */
    /**
     * Les flèches d'indice : UNE À TROIS, d'autant plus marquées que le coup
     * est fort. Vide quand l'indice n'est pas demandé.
     */
    val hints: List<com.chesslab.ui.BoardArrow> = emptyList(),
    /** L'alerte à montrer quand le coup qu'on vient de jouer coûte cher. */
    val blunderWarning: BlunderSeverity? = null,
    val status: String = "",
    val sanMoves: List<String> = emptyList(),
    val thinking: Boolean = false,
    val pendingPromotion: Move? = null,
    val gameOver: Boolean = false,
    /** Le mot de la fin : « Échec et mat — vous gagnez », « Abandon »… */
    val outcome: String? = null,
    /** `null` = Stockfish brut. */
    val opponent: OpponentProfile? = null,
    val level: Double = 1500.0,
    val maiaAvailable: Boolean = true,
    /** Le camp de l'utilisateur : le plateau se retourne avec lui. */
    val userColor: Piece.Color = Piece.Color.white,
    val captured: CapturedMaterial = CapturedMaterial(),
    /** Millisecondes restantes, ou `null` sans pendule. */
    val whiteClockMs: Long? = null,
    val blackClockMs: Long? = null,
    /**
     * Le demi-coup CONSULTÉ. Égal à `sanMoves.size` sur la position vive ;
     * plus petit quand on remonte la partie avec les chevrons.
     */
    val displayedPly: Int = 0,
    val settings: PlayGameSettings = PlayGameSettings(),
    /** Faux tant que l'écran de configuration n'a pas rendu la main. */
    val started: Boolean = false,
) {
    val isReviewing: Boolean get() = displayedPly < sanMoves.size

    /**
     * Peut-on reprendre un coup ?
     *
     * **Pas avec une pendule** : on ne reprend pas du temps déjà écoulé, et
     * iOS a tranché pareil. Ni pendant que le moteur réfléchit — la partie
     * qu'il calcule ne serait plus celle qu'on lui a donnée.
     */
    val canTakeback: Boolean
        get() = !settings.timeControl.hasClock && sanMoves.isNotEmpty() &&
            !gameOver && !thinking
    val totalPlies: Int get() = sanMoves.size
}

/**
 * Une partie contre l'ordinateur : un des neuf personnages, ou Stockfish.
 *
 * Pendant réduit de `PlayViewModel.swift`. Les personnages sont Maia-3 — un
 * réseau entraîné sur des parties HUMAINES — recoloré par un style borné ;
 * Stockfish reste disponible pour qui veut un mur.
 */
class PlayViewModel(app: Application) : AndroidViewModel(app) {

    private var board = Board()
    /** Le camp de l'utilisateur : il change d'une partie à l'autre. */
    private var humanColor = Piece.Color.white

    /**
     * La position d'où la partie part. Standard, sauf quand « Changer de
     * mode » a envoyé ici la position d'un autre écran.
     */
    private var startPosition: Position = Position.standard

    /** L'historique des positions : Maia lit les huit dernières. */
    private val history = mutableListOf(Position.standard)

    /** La partie, pour la bibliothèque : le plateau ne connaît pas l'histoire. */
    private val recorder = GameRecorder()

    /** Les coups en UCI : ce qu'il faut pour REJOUER la partie à la reprise. */
    private val uciLog = mutableListOf<String>()

    private var maia: MaiaOpponent? = null

    /** Les coups joués, pour les prises et la consultation de la partie. */
    private val moveLog = mutableListOf<Move>()
    private var clock: GameClock? = null
    private var ticker: kotlinx.coroutines.Job? = null
    /** La recherche en cours : une nouvelle partie doit pouvoir l'annuler. */
    private var thinkingJob: kotlinx.coroutines.Job? = null

    /**
     * L'ÉPOQUE de la partie : incrémentée dès que le plateau change de vie —
     * partie neuve, fin de partie, coup repris, partie rejouée.
     *
     * L'annulation du travail en cours ne suffit pas. Le coup de l'adversaire
     * traverse plusieurs attentes (le livre, l'inférence, la recherche), et
     * entre deux d'entre elles la partie peut avoir été abandonnée puis
     * relancée : la réponse revient alors sur un plateau qui n'est plus le
     * sien. iOS se garde à chaque reprise (« le trait peut avoir changé entre
     * la mise en file et l'exécution … sans ce garde-fou, le moteur jouerait
     * un coup pour le camp de l'utilisateur ») ; ici l'époque dit la même
     * chose en un seul test.
     */
    private var gameEpoch = 0

    /**
     * La recherche d'indice. Elle dure jusqu'à huit secondes et tient le
     * moteur : jouer un coup doit l'interrompre, sinon l'adversaire attendrait
     * la fin d'une réponse qu'on ne regarde déjà plus.
     */
    private var hintJob: kotlinx.coroutines.Job? = null

    var ui by mutableStateOf(PlayUiState(status = s(R.string.starting)))
        private set

    init { prepare() }

    private fun prepare() = viewModelScope.launch {
        val loaded = withContext(Dispatchers.IO) {
            MaiaOpponent.shared(getApplication(), EngineService.threads)
        }
        maia = loaded
        // Stockfish sert au filet et au mode « moteur » : on le démarre aussi
        withContext(Dispatchers.IO) { EngineService.use(getApplication()) { EngineService.identity } }
        ui = ui.copy(maiaAvailable = loaded != null)
        refresh(s(if (loaded == null) R.string.model_unavailable_stockfish else R.string.your_turn))
    }

    /**
     * Lance une partie avec les réglages de l'écran de configuration.
     *
     * C'est le SEUL point d'entrée d'une partie : la couleur, l'adversaire, le
     * niveau, la cadence et les aides sont décidés avant le premier coup, et
     * ne changent plus en cours de route.
     */
    fun start(settings: PlayGameSettings) {
        startPosition = settings.startFen?.let { Position.fromFen(it) } ?: Position.standard
        val color = when (settings.colorChoice) {
            PlayerColorChoice.white -> Piece.Color.white
            PlayerColorChoice.black -> Piece.Color.black
            PlayerColorChoice.random ->
                if (kotlin.random.Random.nextBoolean()) Piece.Color.white else Piece.Color.black
        }
        humanColor = color
        val profile = settings.opponentId?.let { OpponentGallery.byId(it) }
        clock = if (settings.timeControl.hasClock) GameClock(settings.timeControl) else null
        ui = ui.copy(
            settings = settings, opponent = profile, level = settings.level,
            userColor = color, started = true, outcome = null,
        )
        newGame()
    }

    fun chooseOpponent(profile: OpponentProfile?) {
        ui = ui.copy(opponent = profile, level = profile?.defaultLevel ?: 1500.0)
        newGame()
    }

    fun setLevel(value: Double) {
        val clamped = ui.opponent?.clampedLevel(value) ?: value.coerceIn(800.0, 3000.0)
        ui = ui.copy(level = clamped)
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || ui.pendingPromotion != null) return
        // En consultation d'un coup passé, le plateau est une PHOTO : y jouer
        // écrirait un coup dans une position qui n'est plus celle de la partie.
        if (ui.isReviewing) { reviewLive(); return }
        if (board.position.sideToMove != humanColor) return

        val selected = ui.selected
        if (selected != null && square in ui.legalTargets) {
            play(selected, square)
            return
        }

        val piece = board.position.piece(square)
        ui = if (piece != null && piece.color == humanColor) {
            ui.copy(selected = square, legalTargets = board.legalMoves(square).toSet())
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    private fun play(from: Square, to: Square) {
        val move = board.move(pieceAt = from, to = to) ?: return
        if (board.state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        recordAndContinue(move)
    }

    fun completePromotion(kind: Piece.Kind) {
        val pending = ui.pendingPromotion ?: return
        val move = board.completePromotion(of = pending, to = kind)
        ui = ui.copy(pendingPromotion = null)
        recordAndContinue(move)
    }

    private fun recordAndContinue(move: Move) {
        // La recherche d'indice porte sur la position d'AVANT : la laisser
        // finir, c'est faire attendre l'adversaire pour des flèches périmées.
        stopHint()
        val before = history.last().copy()
        val wasHuman = move.piece.color == humanColor
        history += board.position.copy()
        moveLog += move
        recorder.record(move)
        uciLog += move.lan
        clock?.stopAndIncrement(System.currentTimeMillis())
        autosave()
        refresh(null, move)
        if (ui.gameOver) { ticker?.cancel(); return }
        startClockForSideToMove()

        // La vérification passe AVANT la réponse du moteur, et c'est la seule
        // façon qu'elle marche : elle ne s'affiche que si reprendre est encore
        // possible, or « le moteur réfléchit » interdit de reprendre. Lancées
        // en parallèle, la réponse gagnait la course et l'alerte ne sortait
        // jamais. iOS les met dans la même file, pour la même raison ; le
        // joueur attend donc 300 ms de plus, une fois par coup.
        val mustReply = board.position.sideToMove != humanColor
        if (wasHuman && ui.settings.blunderAlertEnabled && !ui.settings.timeControl.hasClock) {
            val after = board.position.copy()
            val at = moveLog.size
            viewModelScope.launch {
                checkForBlunder(before, after, at)
                if (mustReply && !ui.gameOver) askOpponent()
            }
        } else if (mustReply) {
            askOpponent()
        }
    }

    /**
     * Le coup qu'on vient de jouer coûtait-il cher ?
     *
     * Deux recherches COURTES — 300 ms chacune, comme iOS : l'alerte doit
     * arriver pendant qu'on regarde encore le coup, pas trois secondes plus
     * tard. Elle ne s'affiche que si rien n'a bougé depuis, et que reprendre
     * est encore possible : proposer une reprise impossible serait pire que se
     * taire.
     */
    private suspend fun checkForBlunder(before: Position, after: Position, atMoveCount: Int) {
        val verdict = withContext(Dispatchers.IO) {
            EngineService.use(getApplication()) { e ->
                val b = quickScore(e, before) ?: return@use null
                val a = quickScore(e, after) ?: return@use null
                BlunderAlert.severity(b.first, b.second, a.first, a.second)
            }
        } ?: return
        // Un autre coup a pu être joué entre-temps — l'alerte porterait alors
        // sur une position qui n'est plus à l'écran.
        if (atMoveCount != moveLog.size || ui.gameOver || !ui.canTakeback) return
        ui = ui.copy(blunderWarning = verdict)
    }

    /**
     * Le coup de livre pour la position courante, en LAN, ou `null` s'il faut
     * calculer : livre coupé, position de départ personnalisée (le livre part
     * de la position initiale et n'aurait aucun sens ailleurs), ou position
     * sortie de l'arbre connu.
     */
    private fun bookMove(): String? {
        if (ui.settings.startFen != null) return null
        val assets = getApplication<Application>().assets
        val profile = ui.opponent
        val roots: List<BookNode>
        val width: BookWidth
        val own = profile?.id?.let { OpeningBookStore.forOpponent(assets, it) }
        if (profile != null && maia != null && own != null) {
            roots = own
            width = BookWidth.includeSidelines
        } else {
            if (!ui.settings.bookEnabled) return null
            roots = OpeningBookStore.general(assets)
            width = ui.settings.bookWidth
        }
        val san = OpeningBookPicker.pick(roots, moveLog.map { it.san }, width) ?: return null
        // Le SAN vient d'un fichier : il peut ne pas être jouable ici (livre
        // mal aligné, position atteinte par une autre voie). On le vérifie sur
        // le plateau plutôt que de faire confiance au fichier.
        val move = chesskit.SanParser.parse(san, board.position) ?: return null
        return move.lan
    }

    /** Score et mat éventuel d'une position, du point de vue du camp au trait. */
    private suspend fun quickScore(
        engine: com.chesslab.engine.StockfishEngine,
        position: Position,
    ): Pair<Int, Int?>? {
        engine.send("position fen ${position.fen}")
        var cp: Int? = null
        var mate: Int? = null
        engine.search("go movetime 300", timeoutMs = 5_000) { line ->
            if (!line.startsWith("info ") || !line.contains(" score ")) return@search
            if ((line.substringAfter(" multipv ", "1").substringBefore(" ").toIntOrNull() ?: 1) != 1) return@search
            val m = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
            val c = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
            if (m != null) { mate = m; cp = if (m > 0) 10_000 else -10_000 }
            else if (c != null) { cp = c; mate = null }
        }
        return cp?.let { it to mate }
    }

    fun dismissBlunderWarning() { ui = ui.copy(blunderWarning = null) }

    /**
     * Reprendre après l'alerte. La riposte du moteur est très probablement
     * déjà en train de se calculer : on l'annule d'abord, sinon la reprise
     * échouerait en silence sur le garde « le moteur réfléchit ».
     */
    fun takebackAfterWarning() {
        ui = ui.copy(blunderWarning = null, thinking = false)
        thinkingJob?.cancel()
        takeback()
    }

    private fun askOpponent() {
        thinkingJob?.cancel()
        // Ce qui vaut à l'instant du lancement. Tout ce qui suit une attente
        // se vérifie contre ça avant d'écrire quoi que ce soit.
        val epoch = gameEpoch
        // Le trait peut avoir changé entre la demande et l'exécution — une
        // gaffe reprise, par exemple. Sans ce contrôle, l'adversaire jouerait
        // un coup pour le camp de l'utilisateur.
        if (ui.gameOver || board.position.sideToMove == humanColor) return
        thinkingJob = viewModelScope.launch {
            val profile = ui.opponent
            ui = ui.copy(thinking = true, status = thinkingLabel(profile))

            // LE LIVRE D'ABORD. Un personnage joue SON répertoire — c'est son
            // caractère, pas un réglage —, sinon le livre général si
            // l'utilisateur l'a laissé actif. Sans livre, un réseau entraîné
            // sur des parties humaines rejoue les mêmes ouvertures, et le
            // style qu'on prête au personnage ne se voit nulle part.
            val fromBook = bookMove()
            val lan = fromBook ?: withContext(Dispatchers.IO) {
                val engine = maia
                if (profile != null && engine != null) {
                    // le personnage tel qu'il joue MAINTENANT : sans évaluation
                    // continue, on s'en tient à son humeur de repos
                    val mood = profile.mood(lastMoverCp = null)
                    engine.chooseMove(
                        history = history.toList(),
                        board = Board(board.position.copy()),
                        selfElo = ui.level,
                        oppoElo = ui.level,
                        temperature = mood.temperature,
                        topP = profile.topP,
                        style = mood.style,
                    )?.uci
                } else {
                    EngineService.use(getApplication()) { e ->
                        e.send("position fen ${board.position.fen}")
                        e.search("go movetime ${SettingsStore.state.value.engineMoveTimeMs}", timeoutMs = 60_000)
                    }?.split(" ")?.getOrNull(1)
                }
            }
            // La partie a pu changer de vie pendant la recherche : abandonnée
            // et relancée, reprise d'un coup, rejouée. La réponse ne vaut
            // alors plus rien, et l'appliquer écraserait le plateau neuf.
            if (epoch != gameEpoch) return@launch
            ui = ui.copy(thinking = false)

            if (lan == null || lan == "(none)") { refresh(s(R.string.rival_silent)); return@launch }

            val from = Square(lan.substring(0, 2))
            val to = Square(lan.substring(2, 4))
            var move = board.move(pieceAt = from, to = to)
            if (move == null) { refresh(s(R.string.move_refused, lan)); return@launch }

            if (lan.length == 5) {
                val kind = when (lan[4]) {
                    'q' -> Piece.Kind.queen
                    'r' -> Piece.Kind.rook
                    'b' -> Piece.Kind.bishop
                    else -> Piece.Kind.knight
                }
                move = board.completePromotion(of = move, to = kind)
            }
            history += board.position.copy()
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            clock?.stopAndIncrement(System.currentTimeMillis())
            autosave()
            refresh(null, move)
            if (!ui.gameOver) startClockForSideToMove() else ticker?.cancel()
            }
        }

    /**
     * Garde la partie en cours. Une seule par mode : reprendre, c'est
     * reprendre LA partie interrompue, pas en choisir une dans une pile.
     */
    private fun autosave() = viewModelScope.launch(Dispatchers.IO) {
        val dao = LibraryDatabase.get(getApplication()).autosaves()
        if (ui.gameOver || uciLog.isEmpty()) { dao.clear(MODE); return@launch }
        dao.put(
            Autosave(
                mode = MODE,
                savedAt = System.currentTimeMillis(),
                moves = uciLog.joinToString(" "),
                opponentId = ui.opponent?.id,
                level = ui.level,
                label = s(R.string.autosave_label, ui.opponent?.firstName ?: s(R.string.stockfish), uciLog.size),
            )
        )
    }

    /** Reprend la partie interrompue, s'il y en a une. */
    fun resumeSaved() = viewModelScope.launch {
        val saved = withContext(Dispatchers.IO) {
            LibraryDatabase.get(getApplication<Application>()).autosaves().byMode(MODE)
        } ?: return@launch
        resume(saved)
    }

    /** Rejoue une partie sauvegardée, coup par coup. */
    fun resume(autosave: Autosave) {
        val profile = autosave.opponentId?.let { OpponentGallery.byId(it) }
        newGame()
        ui = ui.copy(opponent = profile, level = autosave.level)
        rebuild(autosave.moveList, s(R.string.game_resumed))
    }

    /**
     * Repose la partie sur exactement ces coups, puis remet en marche ce qui
     * dépend de la position. Sert à REPRENDRE une partie sauvegardée comme à
     * ANNULER un coup — deux gestes, une seule mécanique.
     *
     * La recherche en cours est annulée D'ABORD, et c'est indispensable :
     * `newGame()` fait jouer le moteur quand l'utilisateur a les Noirs, et
     * cette réponse-là porte sur la position de départ. Sans cette annulation,
     * elle s'appliquait sur la partie fraîchement rejouée — un coup surgi de
     * nulle part au milieu d'une reprise.
     */
    private fun rebuild(lans: List<String>, status: String?) {
        gameEpoch++
        thinkingJob?.cancel()
        stopHint()

        board = Board(startPosition)
        history.clear()
        history += startPosition
        val custom = startPosition.fen.takeIf { it != Position.standard.fen }
        recorder.reset(startPosition, custom)
        moveLog.clear()
        uciLog.clear()
        ui = ui.copy(sanMoves = emptyList(), lastMove = null, thinking = false)

        for (lan in lans) {
            var move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
                ?: break
            if (lan.length == 5) {
                move = board.completePromotion(of = move, to = kindOf(lan[4]))
            }
            history += board.position.copy()
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            ui = ui.copy(sanMoves = ui.sanMoves + move.san, lastMove = move.start to move.end)
        }
        ui = ui.copy(captured = CapturedMaterial.from(moveLog, board))
        refresh(status)
        autosave()
        if (!ui.gameOver && board.position.sideToMove != humanColor) askOpponent()
    }

    /**
     * Annule son dernier coup — et la riposte du moteur avec, s'il a répondu.
     * Reprendre un seul demi-coup rendrait la main à l'adversaire, ce qui
     * n'est pas ce qu'on demande en disant « annuler ».
     */
    fun takeback() {
        if (!ui.canTakeback) return
        val last = moveLog.last()
        val count = if (last.piece.color != humanColor && moveLog.size >= 2) 2 else 1
        rebuild(uciLog.dropLast(count), s(R.string.your_turn))
    }

    private fun kindOf(c: Char): Piece.Kind = when (c) {
        'q' -> Piece.Kind.queen
        'r' -> Piece.Kind.rook
        'b' -> Piece.Kind.bishop
        else -> Piece.Kind.knight
    }

    private fun thinkingLabel(profile: OpponentProfile?): String =
        if (profile != null) s(R.string.someone_thinking, profile.firstName) else s(R.string.engine_thinking)

    private fun refresh(status: String?, move: Move? = null) {
        val position = board.position
        val state = board.state

        val checkedKing = when (state) {
            is Board.State.Check -> kingSquare(state.color)
            is Board.State.Checkmate -> kingSquare(state.color)
            else -> null
        }

        // le son suit le COUP, pas l'état : une prise reste une prise même
        // quand elle donne échec — c'est l'échec qui l'emporte
        SoundPlayer.enabled = SettingsStore.state.value.soundsEnabled
        move?.let {
            val isCapture = it.result is Move.Result.Capture
            val isCastle = it.result is Move.Result.Castle
            val isCheck = state is Board.State.Check || state is Board.State.Checkmate
            SoundPlayer.forMove(isCapture, isCastle, isCheck)
            // Le doigt sent ce que l'oreille entend, et l'un marche quand
            // l'autre est coupé — en silence, ou dans un train.
            com.chesslab.sound.Haptics.forMove(isCapture, isCastle, isCheck)
        }

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        if (over && !ui.gameOver) {
            com.chesslab.sound.Haptics.gameEnded()
            ticker?.cancel()
            viewModelScope.launch(Dispatchers.IO) {
                LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
            }
            recorder.save(
                getApplication(),
                white = if (humanColor == Piece.Color.white) s(R.string.you) else opponentName(),
                black = if (humanColor == Piece.Color.white) opponentName() else s(R.string.you),
                source = "engine",
                state = state,
            )
        }
        val text = status ?: when (state) {
            is Board.State.Checkmate ->
                s(if (state.color == humanColor) R.string.checkmate_you_lose else R.string.checkmate_you_win)
            is Board.State.Draw -> s(R.string.draw_reason, drawLabel(state.reason))
            is Board.State.Check -> s(R.string.check)
            else -> if (position.sideToMove == humanColor) s(R.string.your_turn) else thinkingLabel(ui.opponent)
        }

        val sans = if (move != null) ui.sanMoves + move.san else ui.sanMoves
        ui = ui.copy(
            position = position,
            selected = null,
            legalTargets = emptySet(),
            hints = emptyList(),
            lastMove = move?.let { it.start to it.end } ?: ui.lastMove,
            checkedKing = checkedKing,
            status = text,
            sanMoves = sans,
            displayedPly = sans.size,
            captured = CapturedMaterial.from(moveLog, board),
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            gameOver = over,
            outcome = if (over) text else ui.outcome,
        )
    }

    private fun kingSquare(color: Piece.Color): Square? =
        board.position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square

    private fun drawLabel(reason: Board.State.DrawReason): String = when (reason) {
        Board.State.DrawReason.stalemate -> s(R.string.draw_stalemate)
        Board.State.DrawReason.fiftyMoves -> s(R.string.draw_fifty)
        Board.State.DrawReason.insufficientMaterial -> s(R.string.draw_material)
        Board.State.DrawReason.repetition -> s(R.string.draw_repetition)
        Board.State.DrawReason.agreement -> s(R.string.draw_agreement)
    }

    companion object { private const val MODE = "engine" }

    fun newGame() {
        // La recherche en cours vaut pour la position d'AVANT : la laisser
        // vivre, c'est risquer de la voir jouer sur le plateau neuf.
        gameEpoch++
        thinkingJob?.cancel()
        stopHint()
        ticker?.cancel()
        board = Board(startPosition)
        history.clear()
        history += startPosition
        // La FEN n'est transmise que si elle n'est PAS la position standard :
        // un PGN ordinaire ne porte pas de tag `SetUp`.
        val custom = startPosition.fen.takeIf { it != Position.standard.fen }
        recorder.reset(startPosition, custom)
        uciLog.clear()
        moveLog.clear()
        clock = ui.settings.timeControl.takeIf { it.hasClock }?.let { GameClock(it) }
        ui = ui.copy(
            position = startPosition,
            selected = null, legalTargets = emptySet(), lastMove = null, checkedKing = null,
            hints = emptyList(), blunderWarning = null,
            sanMoves = emptyList(), gameOver = false, outcome = null,
            pendingPromotion = null, thinking = false, displayedPly = 0,
            captured = CapturedMaterial(),
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            status = if (board.position.sideToMove == humanColor) s(R.string.your_turn) else thinkingLabel(ui.opponent),
        )
        startClockForSideToMove()
        // L'utilisateur peut avoir les Noirs : c'est alors au moteur d'ouvrir.
        if (board.position.sideToMove != humanColor) askOpponent()
    }

    // MARK: Pendule

    private fun startClockForSideToMove() {
        val c = clock ?: return
        c.start(board.position.sideToMove, System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch {
            while (true) {
                kotlinx.coroutines.delay(100)
                val now = System.currentTimeMillis()
                c.tick(now)
                ui = ui.copy(
                    whiteClockMs = c.remaining(Piece.Color.white),
                    blackClockMs = c.remaining(Piece.Color.black),
                )
                val flagged = Piece.Color.entries.firstOrNull { c.flagged(it) }
                if (flagged != null) { flag(flagged); return@launch }
            }
        }
    }

    /** Le drapeau tombe : la partie s'arrête là, et le score le dit. */
    private fun flag(loser: Piece.Color) {
        ticker?.cancel()
        thinkingJob?.cancel()
        finish(
            s(if (loser == humanColor) R.string.outcome_flag_you else R.string.outcome_flag_opponent),
            if (loser == Piece.Color.white) "0-1" else "1-0",
        )
    }

    // MARK: Fin de partie

    /** Termine la partie, l'enregistre, et arrête tout ce qui tourne. */
    private fun finish(message: String, result: String) {
        if (ui.gameOver) return
        gameEpoch++
        ticker?.cancel()
        thinkingJob?.cancel()
        viewModelScope.launch(Dispatchers.IO) {
            LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
        }
        recorder.save(
            getApplication(),
            white = if (humanColor == Piece.Color.white) s(R.string.you) else opponentName(),
            black = if (humanColor == Piece.Color.white) opponentName() else s(R.string.you),
            source = "engine",
            state = board.state,
            forcedResult = result,
        )
        ui = ui.copy(gameOver = true, thinking = false, outcome = message, status = message)
    }

    private fun opponentName(): String =
        ui.opponent?.displayName(getApplication()) ?: s(R.string.stockfish)

    /** L'utilisateur abandonne. */
    fun resign() {
        finish(
            s(R.string.outcome_resigned),
            if (humanColor == Piece.Color.white) "0-1" else "1-0",
        )
    }

    /**
     * L'utilisateur propose nulle. L'ordinateur accepte s'il n'est pas mieux :
     * il n'a pas d'amour-propre, mais il ne concède pas une partie gagnée.
     */
    fun offerDraw() = viewModelScope.launch {
        if (ui.gameOver) return@launch
        val advantage = ui.captured.advantage(humanColor.opposite)
        if (advantage >= 2) {
            ui = ui.copy(status = s(R.string.outcome_draw_refused))
        } else {
            finish(s(R.string.outcome_draw_agreed), "1/2-1/2")
        }
    }

    // MARK: Indice et consultation

    /** Montre — ou cache — le meilleur coup, si les aides sont permises. */
    /**
     * Montre — ou cache — les flèches d'indice.
     *
     * Le moteur est interrogé en MultiPV 3, et les flèches se posent AU FIL DE
     * L'EAU : la première apparaît en une fraction de seconde et se précise
     * ensuite, plutôt que de faire attendre huit secondes un résultat complet.
     * C'est ce que fait iOS, et c'est ce qui rend l'indice utilisable.
     */
    fun toggleHint() {
        if (!ui.settings.hintsEnabled || ui.gameOver) return
        if (ui.hints.isNotEmpty() || hintJob?.isActive == true) { stopHint(); return }

        val fen = board.position.fen
        hintJob = viewModelScope.launch {
            val lanByRank = HashMap<Int, String>()
            val scoreByRank = HashMap<Int, Double>()
            withContext(Dispatchers.IO) {
                EngineService.use(getApplication()) { e ->
                    e.send("setoption name MultiPV value 3")
                    e.send("position fen $fen")
                    try {
                        // Bornée en PROFONDEUR plutôt qu'infinie : au-delà, les
                        // flèches ne bougent plus à l'œil, et le moteur repasse
                        // au repos au lieu de chauffer tant que l'indice reste
                        // affiché. Le plafond en millisecondes est le filet.
                        e.search("go depth 18 movetime 8000", timeoutMs = 20_000) { line ->
                            readHintInfo(line, lanByRank, scoreByRank)
                        }
                    } finally {
                        // Le moteur sert aussi à faire jouer l'adversaire : le
                        // laisser en MultiPV 3 lui ferait calculer trois lignes
                        // pour un coup dont on n'en veut qu'une.
                        e.send("setoption name MultiPV value 1")
                    }
                }
            }
        }
    }

    /** Efface les flèches et rend le moteur. */
    private fun stopHint() {
        hintJob?.cancel()
        hintJob = null
        ui = ui.copy(hints = emptyList())
    }

    /** Une ligne `info` du moteur → une flèche de plus, ou une flèche affinée. */
    private fun readHintInfo(
        line: String,
        lanByRank: MutableMap<Int, String>,
        scoreByRank: MutableMap<Int, Double>,
    ) {
        if (!line.startsWith("info ") || !line.contains(" score ")) return
        val rank = line.substringAfter(" multipv ", "").substringBefore(" ").toIntOrNull() ?: 1
        val lan = line.substringAfter(" pv ", "").trim().substringBefore(" ")
        if (lan.length < 4) return
        val mate = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
        val cp = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
        val score = HintArrowBuilder.score(cp, mate) ?: return

        lanByRank[rank] = lan
        scoreByRank[rank] = score
        ui = ui.copy(hints = HintArrowBuilder.build(lanByRank, scoreByRank))
    }

    /** Remonte d'un demi-coup dans la partie jouée. */
    /**
     * Le PGN de la partie en cours, pour « Analyser » : la bibliothèque ne
     * l'a pas encore quand la partie vient tout juste de se terminer.
     */
    fun currentPgn(): String = recorder.pgn

    fun reviewPrevious() = review(ui.displayedPly - 1)

    fun reviewNext() = review(ui.displayedPly + 1)

    /**
     * Affiche la position après [ply] demi-coups, SANS toucher à la partie :
     * le plateau réel reste où il est, seule la vue recule.
     */
    private fun review(ply: Int) {
        val target = ply.coerceIn(0, ui.sanMoves.size)
        if (target == ui.displayedPly) return
        val position = history.getOrNull(target) ?: return
        val move = moveLog.getOrNull(target - 1)
        ui = ui.copy(
            displayedPly = target,
            position = position,
            selected = null, legalTargets = emptySet(), hints = emptyList(),
            lastMove = move?.let { it.start to it.end },
        )
    }

    /** Revient à la position vive. */
    fun reviewLive() = review(ui.sanMoves.size)
}
