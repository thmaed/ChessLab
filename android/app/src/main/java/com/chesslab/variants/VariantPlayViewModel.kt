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

data class VariantUiState(
    val position: Position = Position.standard,
    val variant: Variant? = null,
    val selected: Square? = null,
    val legalTargets: Set<Square> = emptySet(),
    val lastMove: Pair<Square, Square>? = null,
    val checkedKing: Square? = null,
    val status: String = "Démarrage du moteur…",
    val uciLog: List<String> = emptyList(),
    val thinking: Boolean = false,
    val gameOver: Boolean = false,
    val ready: Boolean = false,
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
    private var legal: List<String> = emptyList()
    private val humanColor = Piece.Color.white

    var ui by mutableStateOf(VariantUiState())
        private set

    fun load(variantId: String) {
        val variant = VariantCatalog.byId(variantId) ?: return
        startFen = if (variant.chess960) VariantCatalog.randomChess960Fen() else null
        ui = ui.copy(variant = variant, uciLog = emptyList(), gameOver = false, ready = false,
            status = "Démarrage du moteur…", lastMove = null)
        refresh()
    }

    fun newGame() {
        val variant = ui.variant ?: return
        startFen = if (variant.chess960) VariantCatalog.randomChess960Fen() else null
        ui = ui.copy(uciLog = emptyList(), gameOver = false, lastMove = null)
        refresh()
    }

    /** Interroge le moteur et remet à jour le plateau. */
    private fun refresh(afterMove: Pair<Square, Square>? = null): Job = viewModelScope.launch {
        val variant = ui.variant ?: return@launch
        ui = ui.copy(thinking = true)

        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                if (variant.chess960) engine.send("setoption name UCI_Chess960 value true")
                else engine.send("setoption name UCI_Chess960 value false")
                engine.queryPosition(variant.uci, startFen, ui.uciLog)
            }
        }
        ui = ui.copy(thinking = false)

        if (query == null) {
            ui = ui.copy(status = "Moteur de variantes indisponible", ready = false)
            return@launch
        }

        legal = query.legalMoves
        val position = parse(query.fen) ?: Position.standard
        val over = legal.isEmpty()

        ui = ui.copy(
            position = position,
            selected = null,
            legalTargets = emptySet(),
            lastMove = afterMove ?: ui.lastMove,
            checkedKing = if (query.inCheck) kingSquare(position, position.sideToMove) else null,
            gameOver = over,
            ready = true,
            status = when {
                over -> "Partie terminée"
                position.sideToMove == humanColor -> "À vous de jouer"
                else -> "Le moteur réfléchit…"
            },
        )

        if (!over && position.sideToMove != humanColor) askEngine()
    }

    private fun askEngine(): Job = viewModelScope.launch {
        val variant = ui.variant ?: return@launch
        ui = ui.copy(thinking = true, status = "Le moteur réfléchit…")
        val best = withContext(Dispatchers.IO) {
            FairyEngine.use(getApplication()) { engine ->
                engine.bestMove(variant.uci, startFen, ui.uciLog, movetimeMs = 400)
            }
        }
        ui = ui.copy(thinking = false)
        if (best == null || best == "(none)") { ui = ui.copy(status = "Le moteur n'a pas répondu"); return@launch }
        ui = ui.copy(uciLog = ui.uciLog + best)
        refresh(Square(best.substring(0, 2)) to Square(best.substring(2, 4)))
    }

    fun onSquareTap(square: Square) {
        if (ui.thinking || ui.gameOver || !ui.ready) return
        if (ui.position.sideToMove != humanColor) return

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
        ui = if (piece != null && piece.color == humanColor) {
            val targets = legal
                .filter { it.length >= 4 && it.substring(0, 2) == square.notation }
                .map { Square(it.substring(2, 4)) }
                .toSet()
            ui.copy(selected = square, legalTargets = targets)
        } else {
            ui.copy(selected = null, legalTargets = emptySet())
        }
    }

    /**
     * La FEN d'une variante peut porter des champs en plus (« +0+0 » aux Trois
     * échecs) ou des réserves entre crochets. Le plateau n'a besoin que des six
     * premiers champs, et du placement sans sa réserve.
     */
    private fun parse(fen: String): Position? {
        val fields = fen.trim().split(" ").filter { it.isNotEmpty() }
        if (fields.size < 4) return null
        val placement = fields[0].substringBefore('[')
        val six = listOf(placement) + fields.drop(1).take(3) +
            listOf(fields.getOrNull(4) ?: "0", fields.getOrNull(5) ?: "1")
        return FenParser.parse(six.joinToString(" "))
    }

    private fun kingSquare(position: Position, color: Piece.Color): Square? =
        position.pieces.firstOrNull { it.kind == Piece.Kind.king && it.color == color }?.square
}
