package com.chesslab.variants

import android.content.Context
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.engine.EngineService
import com.chesslab.play.EngineStrength
import kotlin.math.abs

/**
 * L'adversaire du Duck Chess. Pendant de `DuckChessEngine.swift`.
 *
 * Aucun moteur ne connaît cette variante, et il n'a pas fallu en écrire un :
 * Stockfish reste un excellent joueur d'échecs, il suffit de ne JAMAIS le
 * laisser choisir hors des coups que le canard autorise. C'est le rôle de
 * `searchmoves`, qui restreint sa recherche à une liste imposée — les coups
 * légaux calculés par [DuckChessRules].
 *
 * ## Ce que le moteur ne voit pas, et ce qu'on fait à la place
 *
 * Il ignore le canard dans son ÉVALUATION : il croit ouvertes des lignes que
 * le canard barre. Son jeu reste bon sans être parfait — compromis assumé.
 *
 * Trois cas le mettraient en défaut, tous traités AVANT lui :
 * - **le roi adverse est prenable** : aux échecs une telle position est
 *   ILLÉGALE, le moteur la refuse ou répond n'importe quoi, et ne proposerait
 *   jamais la prise — qui est pourtant le coup gagnant ;
 * - **la position est illégale sans l'être pour nous** : un roi qui reste sous
 *   une attaque est normal ici, interdit là-bas — même quand le canard pare
 *   cette attaque, puisqu'il ne figure pas dans la FEN ;
 * - **plus rien à chercher** : si tous les coups laissent le roi en prise, sa
 *   liste devient vide et il répond `bestmove (none)`. Une heuristique locale
 *   prend alors le relais.
 */
object DuckChessEngine {

    /** Le budget de réflexion par défaut : la variante se joue à un rythme de salon. */
    const val movetimeMs = 400

    /**
     * Choisit un coup pour le camp au trait.
     *
     * [strength] BRIDE le moteur : sans elle, choisir « 1200 Elo » sur l'écran
     * de réglage ne changeait rien et l'on affrontait un Stockfish entier. Les
     * deux replis — la prise du roi, puis l'heuristique — restent à pleine
     * force : ils ne cherchent pas, ils constatent.
     */
    suspend fun chooseMove(
        context: Context,
        position: Position,
        duck: Square?,
        enPassant: Square?,
        strength: EngineStrength = EngineStrength.Maximum,
        movetimeMs: Int = DuckChessEngine.movetimeMs,
    ): DuckChessRules.Move? {
        val legal = DuckChessRules.moves(position, duck, enPassant)
        if (legal.isEmpty()) return null

        // 1. Le roi adverse est à portée : on gagne, inutile de réfléchir.
        legal.firstOrNull { DuckChessRules.capturesKing(it, position) != null }?.let { return it }

        // 2. Stockfish, borné aux coups que le canard autorise.
        if (DuckChessRules.isStandardLegal(position)) {
            val searchmoves = "searchmoves ${legal.joinToString(" ") { it.uci }}"
            val go = strength.maxDepth?.let { "go depth $it $searchmoves" }
                ?: "go movetime $movetimeMs $searchmoves"
            val best = EngineService.use(context) { engine ->
                for (command in strength.setupCommands) engine.send(command)
                engine.send("position fen ${position.fen}")
                engine.search(go, timeoutMs = 30_000)
            }?.split(" ")?.getOrNull(1)
            legal.firstOrNull { it.uci == best }?.let { return it }
        }

        // 3. Repli : la meilleure prise, sinon un coup au hasard.
        return heuristicMove(legal, position)
    }

    /** Ce que le moteur pense d'une position, POV du camp au trait. */
    data class Eval(val cp: Int?, val mate: Int?, val bestLan: String?)

    /**
     * L'évaluation d'une position de Duck Chess — pour la barre, l'alerte de
     * gaffe et la revue d'après-partie.
     *
     * Elle vaut ce que vaut un moteur qui ne VOIT PAS le canard : très fiable
     * sur le matériel et les grosses fautes, discutable sur le positionnel
     * fin. Et `null` sur une position que les échecs ordinaires tiendraient
     * pour illégale — mieux vaut pas de chiffre qu'un chiffre faux.
     */
    suspend fun evaluate(
        context: Context,
        position: Position,
        duck: Square?,
        enPassant: Square?,
        movetimeMs: Int = 300,
    ): Eval? {
        if (!DuckChessRules.isStandardLegal(position)) return null
        val legal = DuckChessRules.moves(position, duck, enPassant)
        if (legal.isEmpty()) return null
        var cp: Int? = null
        var mate: Int? = null
        val best = EngineService.use(context) { engine ->
            for (command in EngineStrength.Maximum.setupCommands) engine.send(command)
            engine.send("position fen ${position.fen}")
            engine.search(
                "go movetime $movetimeMs searchmoves ${legal.joinToString(" ") { it.uci }}",
                timeoutMs = 30_000,
            ) { line ->
                if (!line.startsWith("info ") || !line.contains(" score ")) return@search
                line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                    ?.let { cp = it; mate = null }
                line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                    ?.let { mate = it }
            }
        }?.split(" ")?.getOrNull(1)
        if (cp == null && mate == null) return null
        return Eval(cp, mate, best?.takeIf { it != "(none)" })
    }

    /** Les trois meilleures lignes, pour les flèches d'indice. */
    suspend fun hintLines(
        context: Context,
        position: Position,
        duck: Square?,
        enPassant: Square?,
        movetimeMs: Int = 1_500,
    ): Pair<Map<Int, String>, Map<Int, Double>> {
        val empty = emptyMap<Int, String>() to emptyMap<Int, Double>()
        if (!DuckChessRules.isStandardLegal(position)) return empty
        val legal = DuckChessRules.moves(position, duck, enPassant)
        if (legal.isEmpty()) return empty
        val lanByRank = HashMap<Int, String>()
        val scoreByRank = HashMap<Int, Double>()
        EngineService.use(context) { engine ->
            engine.send("setoption name MultiPV value 3")
            engine.send("position fen ${position.fen}")
            try {
            engine.search(
                "go movetime $movetimeMs searchmoves ${legal.joinToString(" ") { it.uci }}",
                timeoutMs = 30_000,
            ) { line ->
                if (!line.startsWith("info ") || !line.contains(" multipv ")) return@search
                val rank = line.substringAfter(" multipv ", "").substringBefore(" ").toIntOrNull()
                    ?: return@search
                val first = line.substringAfter(" pv ", "").substringBefore(" ")
                if (first.isBlank()) return@search
                lanByRank[rank] = first
                val mate = line.substringAfter(" score mate ", "").substringBefore(" ").toIntOrNull()
                val cp = line.substringAfter(" score cp ", "").substringBefore(" ").toIntOrNull()
                when {
                    mate != null -> scoreByRank[rank] = if (mate > 0) 10_000.0 - mate else -10_000.0 - mate
                    cp != null -> scoreByRank[rank] = cp.toDouble()
                }
            }
            } finally {
                // Un indice ANNULÉ laissait `MultiPV` à 3 pour le reste de la
                // partie : trois fois le travail à chaque coup, en silence.
                kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) {
                    engine.send("setoption name MultiPV value 1")
                }
            }
        }
        return lanByRank to scoreByRank
    }

    /** À défaut du moteur : prendre ce qui vaut le plus, sinon avancer. */
    private fun heuristicMove(moves: List<DuckChessRules.Move>, position: Position): DuckChessRules.Move? {
        val captures = moves.mapNotNull { move ->
            position.piece(move.to)?.let { move to value(it.kind) }
        }
        captures.maxByOrNull { it.second }?.let { return it.first }
        return moves.randomOrNull()
    }

    /**
     * Où poser le canard : SUR le chemin du meilleur coup adverse.
     *
     * C'est l'esprit de la variante — on ne pose pas le canard au hasard, on
     * le pose là où il gêne. On demande donc au moteur ce que l'adversaire
     * voudrait jouer, et on bloque : sa case d'arrivée si elle est libre,
     * sinon une case de son trajet.
     *
     * [position] est celle d'APRÈS le coup — le trait y appartient encore à
     * celui qui vient de jouer, le tour n'étant pas fini. La question portant
     * sur ce que l'ADVERSAIRE veut faire, c'est une position au trait retourné
     * qu'on envoie au moteur.
     */
    suspend fun chooseDuckSquare(
        context: Context, position: Position, currentDuck: Square?,
    ): Square? {
        val targets = DuckChessRules.duckTargets(position, currentDuck)
        if (targets.isEmpty()) return null

        val opponent = DuckChessFen.flippedSideToMove(position)
        if (DuckChessRules.isStandardLegal(opponent)) {
            val threat = EngineService.use(context) { engine ->
                engine.send("position fen ${opponent.fen}")
                engine.search("go movetime ${maxOf(80, movetimeMs / 3)}", timeoutMs = 20_000)
            }?.split(" ")?.getOrNull(1)
            if (threat != null && threat.length >= 4) {
                val from = Square(threat.substring(0, 2))
                val to = Square(threat.substring(2, 4))
                // La case d'arrivée d'abord : le canard y annule le coup.
                if (to in targets) return to
                // Sinon une case du trajet, pour les pièces à distance.
                DuckChessRules.pathBetween(from, to).firstOrNull { it in targets }?.let { return it }
            }
        }
        // Faute de mieux, une case au centre plutôt qu'un coin : elle gêne
        // statistiquement davantage.
        return targets.maxByOrNull { centrality(it) }
    }

    /** Plus c'est central, plus c'est grand. */
    fun centrality(square: Square): Int =
        -(abs(square.file.number * 2 - 9) + abs(square.rank.value * 2 - 9))

    private fun value(kind: Piece.Kind): Int = when (kind) {
        Piece.Kind.pawn -> 1
        Piece.Kind.knight, Piece.Kind.bishop -> 3
        Piece.Kind.rook -> 5
        Piece.Kind.queen -> 9
        Piece.Kind.king -> 100
    }

    private fun <T> List<T>.randomOrNull(): T? = if (isEmpty()) null else random()
}
