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
    private val humanColor = Piece.Color.white

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
    fun load(variantId: String, chess960Number: Int? = null, twoPlayer: Boolean = false) {
        val variant = VariantCatalog.byId(variantId) ?: return
        ui = ui.copy(
            variant = variant, uciLog = emptyList(), gameOver = false, ready = false,
            status = s(R.string.engine_starting), lastMove = null,
            twoPlayer = twoPlayer, chess960Number = chess960Number,
        )
        rebased = 0
        startFen = startingFen(variant, chess960Number)
        refresh()
    }

    fun newGame() {
        val variant = ui.variant ?: return
        // Une NOUVELLE position à chaque partie, sauf si l'on en avait choisi
        // une : on ne remplace pas un choix par un tirage au sort.
        rebased = 0
        startFen = startingFen(variant, ui.chess960Number)
        ui = ui.copy(uciLog = emptyList(), gameOver = false, lastMove = null, plies = 0)
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

        if (!over && !ui.twoPlayer && position.sideToMove != humanColor) askEngine()
    }

    private fun askEngine(): Job = viewModelScope.launch {
        val variant = ui.variant ?: return@launch
        ui = ui.copy(thinking = true, status = s(R.string.engine_thinking))
        val best = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                engine.bestMove(variant.uci, startFen, ui.uciLog, movetimeMs = 400)
            }
        }
        ui = ui.copy(thinking = false)
        if (best == null || best == "(none)") { ui = ui.copy(status = s(R.string.engine_silent)); return@launch }
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
                ui = ui.copy(uciLog = ui.uciLog + (CrazyhouseFen.letter(kind) + "@" + square.notation))
                refresh(square to square)
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
            ui = ui.copy(uciLog = ui.uciLog + move)
            refresh(selected to square)
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

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square
}
