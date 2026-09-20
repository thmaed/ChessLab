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
import kotlin.math.roundToInt
import kotlinx.coroutines.withContext
import com.chesslab.R
import com.chesslab.ui.HintArrowBuilder
import com.chesslab.ui.q
import com.chesslab.ui.s

/**
 * Le temps que le moteur prend par coup QUAND IL N'Y A PAS DE PENDULE.
 *
 * Figé, comme sur iOS (`PlayViewModel.baseMovetime`, 900 ms). Android en
 * faisait un réglage à quatre vitesses ; iOS n'en offre aucun, et deux apps
 * qui ne réfléchissent pas aussi longtemps ne jouent pas au même niveau.
 */
const val ENGINE_MOVETIME_MS = 900

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
    /** L'évaluation de la position affichée, POV Blancs — la barre s'en sert. */
    val evalCp: Int? = null,
    val evalMate: Int? = null,
    /** Maia a lâché en cours de partie : Stockfish bridé prend le relais. */
    val maiaUnavailable: Boolean = false,
    /** Combien de fois le filet a corrigé le coup du personnage. */
    val safetyNetInterventions: Int = 0,
    /** Le moteur propose nulle : à l'utilisateur de répondre. */
    val pendingDrawOffer: Boolean = false,
    /** Le moteur vient de refuser la nulle — à dire une fois, puis à oublier. */
    val drawDeclined: Boolean = false,
    /** L'indice est DEMANDÉ : il se relance après chaque coup, comme sur iOS. */
    val hintsWanted: Boolean = false,
    /** Stockfish n'a pas démarré : la bannière le dit, et propose de réessayer. */
    val engineUnavailable: Boolean = false,
    val retryingEngine: Boolean = false,
    /** Les coups écartés par « Reprendre ici », le temps de pouvoir les rendre. */
    val resumeUndo: ResumeUndo? = null,
    /** Ce que le lecteur d'écran doit dire : le coup joué, puis le résultat. */
    val announcement: com.chesslab.ui.Announcement? = null,
    /** La partie est GAGNÉE — ce qui décide des confettis, et d'eux seuls. */
    val userWon: Boolean = false,
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

    /**
     * Peut-on repartir du coup consulté ? Jamais avec une pendule — on ne
     * rend pas du temps écoulé — ni pendant que le moteur calcule la suite
     * qu'on s'apprête à jeter.
     */
    val canResumeFromReview: Boolean
        get() = isReviewing && !settings.timeControl.hasClock && !gameOver && !thinking
}

/** Ce que « Reprendre ici » a écarté, et d'où : de quoi le rendre. */
data class ResumeUndo(val discarded: List<String>, val atPly: Int)

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

    /** Le compte à rebours des huit secondes d'annulation de « Reprendre ici ». */
    private var undoJob: kotlinx.coroutines.Job? = null

    /**
     * Les dernières évaluations vues par l'ADVERSAIRE, en centipions de son
     * point de vue. C'est d'elles que tout dépend : son humeur, son abandon,
     * sa proposition de nulle. Sans évaluation continue, un personnage n'a
     * pas de caractère et le moteur ne renonce jamais.
     */
    private val recentEngineEvals = mutableListOf<Int>()

    /** Le moteur ne propose nulle qu'UNE fois par partie. */
    private var engineHasOfferedDraw = false

    /** `ucinewgame` reste à envoyer : le moteur est partagé par toute l'app. */
    private var needsUciNewGame = true

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
        ui = ui.copy(maiaAvailable = loaded != null, engineUnavailable = EngineService.isUnavailable)
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
        val clamped = ui.opponent?.clampedLevel(value)
            ?: value.coerceIn(EngineStrength.playSliderRange)
        ui = ui.copy(level = clamped)
    }

    /**
     * La force à laquelle le moteur doit jouer CE coup.
     *
     * Le curseur ne servait à rien : quel que soit le niveau choisi, Stockfish
     * jouait à pleine puissance. Il est bridé par `UCI_Elo` entre 1320 et
     * 3190, et sous 1320 par un `Skill Level` bas ET une profondeur plafonnée
     * — sans quoi un « grand débutant » à qui l'on donne quatre dixièmes de
     * seconde reste un joueur redoutable.
     */
    private fun strength(): EngineStrength = EngineStrength.of(ui.level)

    /**
     * Le budget de réflexion. Sans pendule, celui que l'utilisateur a choisi
     * dans les réglages ; avec, une fraction du temps restant plus une part de
     * l'incrément, bornée pour ne JAMAIS tomber au drapeau sur un seul coup.
     *
     * Le réglage « Temps de réflexion du moteur » était enregistré et JAMAIS
     * relu : ses quatre choix — rapide, normal, posé, long — ne changeaient
     * rien, et le moteur prenait 900 ms quoi qu'on choisisse. Il ne vaut que
     * sans pendule : avec une pendule, c'est elle qui commande, sans quoi
     * « long » ferait tomber au drapeau en blitz.
     */
    private fun movetimeMs(): Int {
        val budget = baseMovetimeMs()
        // Quand l'appareil chauffe, on rend la moitié du temps plutôt que de
        // laisser le système brider le processeur à notre place.
        return com.chesslab.engine.ThermalMonitor.movetimeMs(budget)
    }

    private fun baseMovetimeMs(): Int {
        val c = clock ?: return ENGINE_MOVETIME_MS
        if (!c.control.hasClock) return 900
        val remaining = c.remaining(board.position.sideToMove) / 1000.0
        val increment = c.control.incrementSeconds.toDouble()
        val base = remaining / 30 + increment * 0.8
        val maximum = minOf(30.0, remaining * 0.25)
        return (base.coerceIn(0.15, maxOf(0.15, maximum)) * 1000).toInt()
    }

    /**
     * Le rythme HUMAIN : un adversaire qui répond dans la même milliseconde
     * n'en est pas un. Pablo joue vite, Nadia réfléchit. Supprimé sous
     * 30 secondes — en zeitnot, le temps est trop précieux pour du décor — et
     * plafonné à 2 % du temps restant.
     */
    private fun naturalDelayMs(): Long {
        val pace = ui.opponent?.temperament?.pace ?: 1.0
        val maxSeconds = clock?.takeIf { it.control.hasClock }?.let { c ->
            val remaining = c.remaining(board.position.sideToMove) / 1000.0
            if (remaining < 30) return 0
            minOf(0.7 * pace, remaining * 0.02)
        } ?: (0.7 * pace)
        if (maxSeconds <= 0.1) return 0
        val lower = minOf(0.25, maxSeconds)
        return (kotlin.random.Random.nextDouble(lower, maxSeconds) * 1000).toLong()
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || ui.pendingPromotion != null) return
        // En consultation d'un coup passé, le plateau est une PHOTO : y jouer
        // écrirait un coup dans une position qui n'est plus celle de la partie.
        // On n'en sort pas par un tap, mais par les chevrons ou « Reprendre
        // ici » — sortir du passé par inadvertance surprenait.
        if (ui.isReviewing) return
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
        val move = board.move(pieceAt = from, to = to) ?: run {
            // Un geste refusé doit se SENTIR : sans retour, on croit que
            // l'écran n'a pas vu le doigt.
            com.chesslab.sound.Haptics.illegal()
            ui = ui.copy(selected = null, legalTargets = emptySet())
            return
        }
        if (board.state is Board.State.Promotion) {
            ui = ui.copy(selected = null, legalTargets = emptySet(), pendingPromotion = move)
            return
        }
        recordAndContinue(move)
    }

    /**
     * Annule la promotion — donc le coup : le pion retourne d'où il vient.
     * Promouvoir en dame parce qu'on a touché à côté, c'est jouer à la place
     * de quelqu'un qui n'a pas encore choisi.
     */
    fun cancelPromotion() {
        if (ui.pendingPromotion == null) return
        ui = ui.copy(pendingPromotion = null, selected = null, legalTargets = emptySet())
        // Le plateau a DÉJÀ bougé : on le repose sur les coups joués.
        rebuild(uciLog.toList(), null)
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
        // N'IMPORTE QUEL coup périme l'offre d'annulation : la rendre après
        // coup réinjecterait une suite qui ne colle plus à la partie.
        clearResumeUndo()
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
        if (!mustReply && !ui.gameOver && ui.hintsWanted) startHint()
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

    /** Ce qu'une recherche COURTE à pleine puissance a vu de la position. */
    private data class QuickSearch(val lan: String?, val cp: Int?, val mate: Int?)

    /**
     * Une recherche de 300 ms à PLEINE puissance, du point de vue du camp au
     * trait. Elle sert quatre fois : la barre d'évaluation, l'humeur du
     * personnage, le filet derrière Maia, et la décision d'abandonner ou de
     * proposer nulle. Une seule recherche les nourrit toutes.
     */
    private suspend fun quickSearch(): QuickSearch? = withContext(Dispatchers.IO) {
        val fen = board.position.fen
        EngineService.use(getApplication()) { e ->
            e.send("position fen $fen")
            var cp: Int? = null
            var mate: Int? = null
            val best = e.search("go movetime 300", timeoutMs = 5_000) { line ->
                if (!line.startsWith("info ") || !line.contains(" score ")) return@search
                if ((line.substringAfter(" multipv ", "1").substringBefore(" ").toIntOrNull() ?: 1) != 1) return@search
                val m = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                val c = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                if (m != null) { mate = m; cp = if (m > 0) 10_000 else -10_000 }
                else if (c != null) { cp = c; mate = null }
            }?.split(" ")?.getOrNull(1)
            QuickSearch(best?.takeIf { it.length >= 4 }, cp, mate)
        }
    }

    /** Une recherche de Stockfish BRIDÉ au niveau choisi. */
    private suspend fun bridledSearch(): String? = withContext(Dispatchers.IO) {
        val strength = strength()
        val fen = board.position.fen
        val budget = movetimeMs()
        val newGame = needsUciNewGame
        EngineService.use(getApplication()) { e ->
            // Le moteur est PARTAGÉ par toute l'app : le bridage se pose avant
            // chaque recherche, et `EngineService` le relève pour les autres.
            if (newGame) e.send("ucinewgame")
            strength.setupCommands.forEach { e.send(it) }
            EngineService.markBridled()
            e.send("position fen $fen")
            // Sous 1320, la force se simule en plafonnant la PROFONDEUR :
            // un budget en millisecondes ne suffit pas à affaiblir un moteur.
            val go = strength.maxDepth?.let { "go depth $it" } ?: "go movetime $budget"
            e.search(go, timeoutMs = 60_000)
        }?.split(" ")?.getOrNull(1)
    }.also { needsUciNewGame = false }

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
            // l'utilisateur l'a laissé actif.
            val fromBook = bookMove()

            // La position vue à pleine puissance : elle nourrit l'évaluation,
            // l'humeur, le filet et la décision d'abandonner.
            val quick = if (fromBook == null || needsEval()) quickSearch() else null
            if (epoch != gameEpoch) return@launch
            quick?.cp?.let { noteEngineEval(it) }

            val lan = fromBook ?: chooseMove(profile, quick)
            if (epoch != gameEpoch) return@launch
            ui = ui.copy(thinking = false)

            if (lan == null || lan == "(none)") {
                // Le moteur n'a rien à jouer : c'est que la partie est finie.
                // La laisser ouverte et muette était le défaut qu'iOS a corrigé.
                refresh(null)
                if (!ui.gameOver) finish(s(R.string.rival_silent), "*")
                return@launch
            }

            // Le rythme humain, avant de poser le coup.
            val delay = naturalDelayMs()
            if (delay > 0) kotlinx.coroutines.delay(delay)
            if (epoch != gameEpoch) return@launch

            val from = Square(lan.substring(0, 2))
            val to = Square(lan.substring(2, 4))
            var move = board.move(pieceAt = from, to = to)
            if (move == null) {
                // Un coup injouable ne doit pas laisser l'écran figé : on
                // conclut sur l'état RÉEL du plateau.
                refresh(null)
                if (!ui.gameOver) finish(s(R.string.move_refused, lan), "*")
                return@launch
            }

            if (lan.length == 5) {
                move = board.completePromotion(of = move, to = kindOf(lan[4]))
            }
            history += board.position.copy()
            moveLog += move
            recorder.record(move)
            uciLog += move.lan
            clock?.stopAndIncrement(System.currentTimeMillis())
            autosave()
            refresh(null, move)
            if (!ui.gameOver) {
                startClockForSideToMove()
                maybeResignOrOfferDraw()
                // L'indice DEMANDÉ se relance de lui-même : sur iOS il suit la
                // partie, il ne se redemande pas à chaque coup.
                if (ui.hintsWanted && !ui.gameOver) startHint()
            } else {
                ticker?.cancel()
            }
        }
    }

    /** A-t-on besoin d'une évaluation, même quand le livre fournit le coup ? */
    private fun needsEval(): Boolean =
        ui.settings.showEvalBar || ui.settings.engineResigns || ui.opponent != null

    /**
     * Le coup de l'adversaire : Maia arbitrée par le filet, ou Stockfish
     * bridé. Si Maia ne répond pas, Stockfish prend le relais POUR TOUTE LA
     * SUITE — une partie figée sur « l'adversaire n'a pas répondu » n'est pas
     * une partie.
     */
    private suspend fun chooseMove(profile: OpponentProfile?, quick: QuickSearch?): String? {
        val engine = maia
        if (profile == null || engine == null || ui.maiaUnavailable) return bridledSearch()

        val mood = profile.mood(lastMoverCp = quick?.cp)
        val proposed = withContext(Dispatchers.IO) {
            engine.chooseMove(
                history = history.toList(),
                board = Board(board.position.copy()),
                selfElo = ui.level,
                oppoElo = ui.level,
                temperature = mood.temperature,
                topP = profile.topP,
                style = mood.style,
            )?.uci
        }
        if (proposed == null) {
            // Le réseau a lâché : on le dit, et Stockfish bridé au niveau du
            // personnage joue à sa place — ce que `MaiaOpponent` documente
            // depuis toujours sans que personne ne l'ait branché.
            ui = ui.copy(maiaUnavailable = true)
            return bridledSearch()
        }

        // LE FILET. Quatre cas bornés, et rien d'autre : un mat en un ou deux
        // que le personnage est censé voir, une finale technique, une
        // répétition en position gagnée. Ailleurs, Maia joue ce qu'elle veut —
        // y compris se tromper, ce qui est tout l'intérêt.
        return when (val decision = MaiaTurnResolver.resolve(
            maiaUci = proposed, quick = quick?.let { MaiaTurnResolver.Quick(it.lan, it.cp, it.mate) },
            level = ui.level.roundToInt(), pieceCount = board.position.pieces.size,
            policy = profile.safetyNet, board = Board(board.position.copy()),
        )) {
            is MaiaTurnResolver.Decision.Play -> proposed
            is MaiaTurnResolver.Decision.Override -> {
                ui = ui.copy(safetyNetInterventions = ui.safetyNetInterventions + 1)
                decision.lan
            }
            MaiaTurnResolver.Decision.SearchBridled -> {
                ui = ui.copy(safetyNetInterventions = ui.safetyNetInterventions + 1)
                bridledSearch() ?: proposed
            }
        }
    }

    /** Range une évaluation vue par l'adversaire, et met la barre à jour. */
    private fun noteEngineEval(cp: Int) {
        recentEngineEvals += cp
        if (recentEngineEvals.size > 12) recentEngineEvals.removeAt(0)
        // La barre se lit du point de vue des BLANCS : l'évaluation, elle,
        // vient du camp au trait.
        val whitePov = if (board.position.sideToMove == Piece.Color.white) cp else -cp
        ui = ui.copy(
            evalCp = whitePov.coerceIn(-10_000, 10_000),
            evalMate = null,
        )
    }

    /**
     * L'adversaire abandonne-t-il, ou propose-t-il nulle ?
     *
     * Les seuils sont ceux du PERSONNAGE — Léa s'accroche, Nadia renonce tôt —
     * et le réglage de l'utilisateur peut couper l'abandon : un débutant qui
     * vient de gagner une dame apprend en donnant le mat, pas en voyant la
     * partie s'arrêter.
     */
    private fun maybeResignOrOfferDraw() {
        val temperament = ui.opponent?.temperament ?: com.chesslab.maia.Temperament()
        val patience = temperament.resignPatience
        val recent = recentEngineEvals.takeLast(patience)
        if (ui.settings.engineResigns && recent.size == patience &&
            recent.all { it < temperament.resignThresholdCp }
        ) {
            finish(s(R.string.outcome_opponent_resigned), if (humanColor == Piece.Color.white) "1-0" else "0-1")
            return
        }
        val last6 = recentEngineEvals.takeLast(6)
        if (temperament.offersDraws && !engineHasOfferedDraw && last6.size == 6 &&
            last6.all { kotlin.math.abs(it) < temperament.drawOfferMaxCp } &&
            board.position.pieces.size <= 12
        ) {
            engineHasOfferedDraw = true
            ui = ui.copy(pendingDrawOffer = true)
        }
    }

    /** L'utilisateur répond à la nulle proposée par l'adversaire. */
    fun acceptDrawOffer() {
        ui = ui.copy(pendingDrawOffer = false)
        finish(s(R.string.outcome_draw_agreed), "1/2-1/2")
    }

    fun declineDrawOffer() { ui = ui.copy(pendingDrawOffer = false) }

    fun dismissDrawDeclined() { ui = ui.copy(drawDeclined = false) }

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
                // Tout ce qu'il faut pour reprendre la partie TELLE QUELLE :
                // sa position de départ, le camp joué, la cadence, et les deux
                // temps restants — pris au plus PRÉCIS, pas à l'affichage.
                startFen = ui.settings.startFen,
                userColor = humanColor.name,
                timeControlId = ui.settings.timeControlId,
                whiteMs = clock?.remaining(Piece.Color.white),
                blackMs = clock?.remaining(Piece.Color.black),
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

    /**
     * Rejoue une partie sauvegardée — avec sa couleur, sa position de départ,
     * sa cadence et ses deux pendules. Reprendre une partie jouée avec les
     * Noirs à trente secondes… avec les Blancs et le temps plein n'était pas
     * une reprise.
     */
    fun resume(autosave: Autosave) {
        val profile = autosave.opponentId?.let { OpponentGallery.byId(it) }
        autosave.userColor?.let { name ->
            runCatching { Piece.Color.valueOf(name) }.getOrNull()?.let { humanColor = it }
        }
        startPosition = autosave.startFen?.let { Position.fromFen(it) } ?: Position.standard
        val settings = ui.settings.copy(
            startFen = autosave.startFen,
            timeControlId = autosave.timeControlId ?: ui.settings.timeControlId,
            opponentId = autosave.opponentId,
        )
        ui = ui.copy(
            settings = settings, opponent = profile, level = autosave.level,
            userColor = humanColor, started = true,
        )
        newGame()
        clock?.restore(autosave.whiteMs, autosave.blackMs)
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
    /** Vrai quand le dernier rejeu a buté sur un coup injouable. */
    private var failedResume = false

    /** Le numéro de la prochaine annonce — voir [com.chesslab.ui.Announcement]. */
    private var announcementId = 0

    private fun announce(text: String) {
        announcementId += 1
        ui = ui.copy(announcement = com.chesslab.ui.Announcement(announcementId, text))
    }

    private fun rebuild(lans: List<String>, status: String?) {
        gameEpoch++
        failedResume = false
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
                ?: run {
                    // Sauter le coup fautif appliquerait tous les suivants à
                    // une position devenue fausse, et l'on re-sauvegarderait
                    // par-dessus : la fin de la partie serait perdue sans que
                    // personne le sache. On s'arrête et on le dit.
                    failedResume = true
                    null
                } ?: break
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
        refresh(if (failedResume) s(R.string.play_resume_failed) else status)
        if (failedResume) {
            // La sauvegarde est inutilisable : on l'efface plutôt que de la
            // réécrire tronquée.
            viewModelScope.launch(Dispatchers.IO) {
                LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
            }
            return
        }
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
            // Et le lecteur d'écran l'entend : sans annonce, on ne sait pas
            // ce que l'adversaire vient de jouer.
            announce(
                com.chesslab.ui.MoveNarration.announcement(
                    getApplication(),
                    if (it.piece.color == humanColor) s(R.string.you) else opponentName(),
                    it.san,
                )
            )
        }

        val over = state is Board.State.Checkmate || state is Board.State.Draw
        // Une position de départ déjà finie n'est pas une partie : rien à
        // ranger en bibliothèque.
        if (over && !ui.gameOver && moveLog.isNotEmpty()) {
            viewModelScope.launch(Dispatchers.IO) {
                LibraryDatabase.get(getApplication()).autosaves().clear(MODE)
            }
            recorder.save(
                getApplication(),
                white = if (humanColor == Piece.Color.white) s(R.string.you) else opponentName(),
                black = if (humanColor == Piece.Color.white) opponentName() else s(R.string.you),
                source = "engine",
                state = state,
                opponentId = ui.opponent?.id,
                engineElo = ui.level.roundToInt(),
                engineColor = humanColor.opposite,
            )
        }
        if (over && !ui.gameOver) { com.chesslab.sound.Haptics.gameEnded(); ticker?.cancel() }
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
            userWon = if (over) state is Board.State.Checkmate && state.color != humanColor else ui.userWon,
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
        recentEngineEvals.clear()
        engineHasOfferedDraw = false
        needsUciNewGame = true
        ui = ui.copy(
            maiaUnavailable = false, safetyNetInterventions = 0,
            pendingDrawOffer = false, drawDeclined = false,
            evalCp = null, evalMate = null,
            position = startPosition,
            selected = null, legalTargets = emptySet(), lastMove = null, checkedKing = null,
            hints = emptyList(), blunderWarning = null,
            sanMoves = emptyList(), gameOver = false, outcome = null, userWon = false,
            pendingPromotion = null, thinking = false, displayedPly = 0,
            captured = CapturedMaterial(),
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
            status = if (board.position.sideToMove == humanColor) s(R.string.your_turn) else thinkingLabel(ui.opponent),
        )
        // La position de départ peut être DÉJÀ finie — « Jouer à partir d'ici »
        // depuis la position finale d'une partie. L'annoncer vaut mieux que
        // d'afficher « à vous de jouer » indéfiniment.
        val state = board.state
        if (state is Board.State.Checkmate || state is Board.State.Draw) {
            refresh(null)
            return
        }
        startClockForSideToMove()
        // L'utilisateur peut avoir les Noirs : c'est alors au moteur d'ouvrir.
        if (board.position.sideToMove != humanColor) askOpponent()
    }

    // MARK: Pendule

    private fun startClockForSideToMove() {
        val c = clock ?: return
        c.start(board.position.sideToMove, System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch { tickLoop(c) }
    }

    private suspend fun tickLoop(c: GameClock) {
        while (true) {
            kotlinx.coroutines.delay(100)
            val now = System.currentTimeMillis()
            c.tick(now)
            ui = ui.copy(
                whiteClockMs = c.remaining(Piece.Color.white),
                blackClockMs = c.remaining(Piece.Color.black),
            )
            val flagged = Piece.Color.entries.firstOrNull { c.flagged(it) }
            if (flagged != null) { flag(flagged); return }
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

    /**
     * L'écran disparaît, ou l'app passe en arrière-plan : la pendule
     * s'arrête, et l'indice avec. Sans cela le drapeau tombait derrière un
     * autre écran, sans que personne le voie.
     */
    fun pauseForBackground() {
        if (ui.gameOver) return
        clock?.pause(System.currentTimeMillis())
        ticker?.cancel()
        stopHint()
        ui = ui.copy(
            whiteClockMs = clock?.remaining(Piece.Color.white),
            blackClockMs = clock?.remaining(Piece.Color.black),
        )
    }

    /** Le retour sur l'écran : la pendule repart où elle en était. */
    fun resumeFromBackground() {
        if (ui.gameOver || !ui.started) return
        val c = clock ?: return
        c.resume(System.currentTimeMillis())
        ticker?.cancel()
        ticker = viewModelScope.launch { tickLoop(c) }
    }

    // MARK: Fin de partie

    /** Termine la partie, l'enregistre, et arrête tout ce qui tourne. */
    private fun finish(message: String, result: String) {
        val won = result == (if (humanColor == Piece.Color.white) "1-0" else "0-1")
        if (ui.gameOver) return
        gameEpoch++
        ticker?.cancel()
        thinkingJob?.cancel()
        // Une recherche d'indice dure jusqu'à huit secondes : la laisser
        // survivre à la partie tiendrait le moteur de toute l'app pour rien.
        stopHint()
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
            opponentId = ui.opponent?.id,
            engineElo = ui.level.roundToInt(),
            engineColor = humanColor.opposite,
        )
        ui = ui.copy(
            gameOver = true, thinking = false, outcome = message, status = message,
            userWon = won,
        )
        // Les coups étaient annoncés, la fin de partie non : on voyait le
        // moteur cesser de répondre sans savoir qu'on venait de gagner.
        announce(message)
    }

    private fun opponentName(): String =
        ui.opponent?.displayName(getApplication()) ?: s(R.string.stockfish)

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
        // Le moteur est revenu et c'était à lui de jouer : il reprend la main.
        if (!ui.engineUnavailable && !ui.gameOver && ui.started &&
            board.position.sideToMove != humanColor && !ui.thinking
        ) {
            askOpponent()
        }
    }

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
        if (ui.gameOver || ui.thinking) return@launch
        // Le critère est l'ÉVALUATION, pas le matériel capturé : une position
        // matériellement égale peut être stratégiquement perdue, et une
        // position gagnée avec un pion de moins reste gagnée. Sans évaluation
        // — le moteur n'a pas encore joué — on ne concède rien.
        val last = recentEngineEvals.lastOrNull()
        if (last != null && kotlin.math.abs(last) <= 50) {
            finish(s(R.string.outcome_draw_agreed), "1/2-1/2")
        } else {
            ui = ui.copy(drawDeclined = true)
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
        if (ui.hintsWanted) { ui = ui.copy(hintsWanted = false); stopHint(); return }
        ui = ui.copy(hintsWanted = true)
        startHint()
    }

    /**
     * Lance l'analyse d'indice pour la position courante — si c'est bien à
     * l'utilisateur de jouer et que le moteur n'est pas déjà pris.
     */
    private fun startHint() {
        if (!ui.hintsWanted || ui.gameOver || ui.thinking) return
        if (board.position.sideToMove != humanColor) return
        hintJob?.cancel()
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

    /**
     * Efface les flèches et rend le moteur — sans renoncer à l'indice : c'est
     * `hintsWanted` qui dit si l'utilisateur en veut, et il survit aux coups.
     */
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

    /** Va au demi-coup demandé — la liste des coups s'en sert. */
    fun reviewTo(ply: Int) = review(ply)

    /**
     * Repart du coup CONSULTÉ : la suite est écartée, et la partie continue
     * d'ici. Sans confirmation — mais avec huit secondes pour se raviser, ce
     * qui vaut mieux qu'une boîte de dialogue devant chaque geste.
     */
    fun resumeFromReview() {
        if (!ui.canResumeFromReview) return
        val ply = ui.displayedPly
        val discarded = uciLog.drop(ply)
        if (discarded.isEmpty()) return
        rebuild(uciLog.take(ply), s(R.string.your_turn))
        ui = ui.copy(resumeUndo = ResumeUndo(discarded, ply))
        // Sans feuille de confirmation, rien n'annonce la troncature à qui ne
        // voit pas la liste raccourcir.
        announce(s(R.string.two_resume_announce, discarded.size))
        undoJob?.cancel()
        undoJob = viewModelScope.launch {
            kotlinx.coroutines.delay(8_000)
            ui = ui.copy(resumeUndo = null)
        }
    }

    /** Rend les coups que « Reprendre ici » venait d'écarter. */
    fun cancelResumeFromReview() {
        val undo = ui.resumeUndo ?: return
        undoJob?.cancel()
        ui = ui.copy(resumeUndo = null)
        rebuild(uciLog.take(undo.atPly) + undo.discarded, null)
    }

    private fun clearResumeUndo() {
        undoJob?.cancel()
        if (ui.resumeUndo != null) ui = ui.copy(resumeUndo = null)
    }

    /**
     * La ligne qui résume l'adversaire en fin de partie : contre qui, à quel
     * niveau, et combien de fois le filet est intervenu.
     */
    fun opponentSummaryLine(): String {
        val profile = ui.opponent
        val level = ui.level.roundToInt()
        val base = if (profile != null) {
            s(R.string.play_summary_character, profile.displayName(getApplication()), level)
        } else {
            s(R.string.play_summary_engine, level)
        }
        val extra = when {
            ui.maiaUnavailable -> s(R.string.play_summary_maia_down)
            ui.safetyNetInterventions > 0 ->
                q(R.plurals.play_summary_safety_net, ui.safetyNetInterventions, ui.safetyNetInterventions)
            else -> null
        }
        return if (extra != null) "$base · $extra" else base
    }
}
