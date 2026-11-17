package com.chesslab.puzzles

import android.content.res.AssetManager
import android.util.JsonReader
import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.random.Random

/**
 * « Contre la montre » (17/11/2026) : trois minutes, autant de puzzles que possible, trois erreurs et c'est
 * fini. La difficulté MONTE à chaque réussite. Pendant de `PuzzleRushRun` (PuzzleRush.swift).
 *
 * Décisions de l'utilisateur (17/11/2026) : la série ne touche NI la cote de puzzles NI « Ratés » — les
 * ratés restent dans le bilan. Le record reste sur l'appareil (pas d'iCloud sur Android).
 *
 * La RÈGLE, pure et datée de l'extérieur (millisecondes) : vérifiable en test JVM.
 */
data class PuzzleRushRun(
    val durationMs: Long = DURATION_MS,
    val startRating: Int,
    val solved: Int = 0,
    val errors: Int = 0,
    /** La cote du puzzle le plus difficile trouvé — « plus difficile trouvé » au bilan. */
    val highestSolvedRating: Int? = null,
    private val elapsedBeforePauseMs: Long = 0,
    private val runningSinceMs: Long? = null,
) {
    /** La difficulté visée pour le PROCHAIN puzzle. */
    val targetRating: Int get() = startRating + solved * RATING_STEP
    val isRunning: Boolean get() = runningSinceMs != null

    fun elapsedMs(now: Long): Long = elapsedBeforePauseMs + (runningSinceMs?.let { now - it } ?: 0L)
    fun remainingMs(now: Long): Long = (durationMs - elapsedMs(now)).coerceAtLeast(0L)
    fun isOver(now: Long): Boolean = errors >= MAX_ERRORS || remainingMs(now) <= 0L

    fun start(now: Long): PuzzleRushRun = if (runningSinceMs != null) this else copy(runningSinceMs = now)

    /** Le temps s'arrête : app en arrière-plan, écran quitté. */
    fun pause(now: Long): PuzzleRushRun {
        val since = runningSinceMs ?: return this
        return copy(elapsedBeforePauseMs = elapsedBeforePauseMs + (now - since), runningSinceMs = null)
    }

    fun recordSolved(rating: Int?): PuzzleRushRun = copy(
        solved = solved + 1,
        highestSolvedRating = if (rating == null || rating <= 0) highestSolvedRating
            else maxOf(highestSolvedRating ?: rating, rating),
    )

    fun recordError(): PuzzleRushRun = copy(errors = minOf(MAX_ERRORS, errors + 1))

    companion object {
        const val DURATION_MS = 180_000L
        const val MAX_ERRORS = 3
        const val RATING_STEP = 30
        const val START_BELOW_RATING = 400
        const val LOWEST_START = 600
        /** Au plus deux coups à trouver (coup, riposte, coup). */
        const val MAX_PLIES = 3

        fun forPlayer(playerRating: Double, durationMs: Long = DURATION_MS) = PuzzleRushRun(
            durationMs = durationMs,
            startRating = maxOf(LOWEST_START, Math.round(playerRating).toInt() - START_BELOW_RATING),
        )
    }
}

/**
 * Les puzzles d'une série, tirés à l'avance. iOS les prend un à un dans sa base ; Android lit la
 * bibliothèque EN FLUX (23 Mo) : la relire à chaque puzzle prendrait des secondes. On en tire donc un lot
 * en UNE passe au moment de la règle, par tranches de 100 points au-dessus du départ, et la série puise
 * dedans — mêmes fenêtres qu'iOS (`PuzzleRushDrawer`).
 */
class PuzzleRushPool(private val puzzles: List<Puzzle>) {

    val size: Int get() = puzzles.size

    fun next(target: Int, used: Set<String>, random: Random = Random.Default): Puzzle? {
        for (half in WINDOWS) {
            val candidates = puzzles.filter { it.rating in (target - half)..(target + half) && it.id !in used }
            if (candidates.isNotEmpty()) return candidates.random(random)
        }
        return null
    }

    companion object {
        /** Demi-largeurs successives de la fenêtre de cotes, comme iOS. */
        val WINDOWS = listOf(75, 200, 500, 3000)
        /** Tranches tirées au-dessus du départ : 60 réussites en trois minutes, c'est déjà +1 800. */
        private const val BANDS = 22
        private const val PER_BAND = 14
        private const val BAND = 100

        fun isPlayable(puzzle: Puzzle): Boolean =
            puzzle.solution.size in 1..PuzzleRushRun.MAX_PLIES && puzzle.setup == null && puzzle.fen.isNotEmpty()

        /** Une passe sur la bibliothèque : par tranche, un échantillon uniforme (réservoir) de puzzles courts. */
        fun load(assets: AssetManager, startRating: Int, random: Random = Random.Default): PuzzleRushPool {
            val low = startRating - BAND
            val buckets = Array(BANDS) { ArrayList<Puzzle>(PER_BAND) }
            val seen = IntArray(BANDS)
            assets.open("lichess_puzzles.json").reader().use { stream ->
                JsonReader(stream).use { json ->
                    json.beginArray()
                    while (json.hasNext()) {
                        val puzzle = PuzzleRepository.read(json) ?: continue
                        if (!isPlayable(puzzle)) continue
                        val band = (puzzle.rating - low) / BAND
                        if (puzzle.rating < low || band !in 0 until BANDS) continue
                        seen[band]++
                        val bucket = buckets[band]
                        if (bucket.size < PER_BAND) bucket += puzzle
                        else random.nextInt(seen[band]).let { if (it < PER_BAND) bucket[it] = puzzle }
                    }
                    json.endArray()
                }
            }
            return PuzzleRushPool(buckets.flatMap { it })
        }
    }
}

/** La solution entière, numérotée, en SAN anglais — l'écran la traduit (`SanFormatter`). */
object PuzzleRushSolution {
    fun sans(puzzle: Puzzle): List<String> {
        val position = Position.fromFen(puzzle.fen) ?: return emptyList()
        val board = Board(position)
        val out = ArrayList<String>()
        for (lan in puzzle.solution) {
            if (lan.length < 4) break
            var move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4))) ?: break
            if (board.state is Board.State.Promotion) {
                val kind = when (lan.getOrNull(4)) {
                    'r' -> Piece.Kind.rook
                    'b' -> Piece.Kind.bishop
                    'n' -> Piece.Kind.knight
                    else -> Piece.Kind.queen
                }
                move = board.completePromotion(of = move, to = kind)
            }
            out += move.san
        }
        return out
    }

    /** « 19. Fxh7+ Rf8 20. Txe5 » à partir des SAN déjà mis dans la notation de l'utilisateur. */
    fun numbered(fen: String, sans: List<String>): String {
        val position = Position.fromFen(fen) ?: return sans.joinToString(" ")
        val whiteFirst = position.sideToMove == Piece.Color.white
        var number = position.clock.fullmoves
        val parts = ArrayList<String>()
        sans.forEachIndexed { index, san ->
            val isWhite = if (whiteFirst) index % 2 == 0 else index % 2 == 1
            parts += when {
                isWhite -> "$number. $san"
                index == 0 -> "$number… $san"
                else -> san
            }
            if (!isWhite) number++
        }
        return parts.joinToString(" ")
    }
}
