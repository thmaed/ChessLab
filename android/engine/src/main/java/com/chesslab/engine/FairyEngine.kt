package com.chesslab.engine

import android.content.Context
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.concurrent.thread

/** Ce que le moteur sait d'une position de variante. */
data class PositionQuery(
    val fen: String,
    val inCheck: Boolean,
    /** Les coups légaux en UCI — l'ARBITRE de légalité pour la variante. */
    val legalMoves: List<String>,
)

/**
 * Fairy-Stockfish vu de Kotlin : les variantes.
 *
 * Il ne sert pas qu'à jouer — il ARBITRE. Pour Chess960, l'Atomique ou
 * l'Antichecs, les règles ne sont pas celles de `chesskit` ; la position vient
 * donc de `d` (sa FEN fait foi) et les coups légaux de `go perft 1`, dont
 * chaque ligne porte un coup. C'est la méthode de l'app iOS, pour la même
 * raison : réimplémenter huit jeux de règles serait long et faux.
 */
class FairyEngine private constructor(private val binaryPath: String) {

    private val incoming = Channel<String>(Channel.UNLIMITED)
    private var reader: Thread? = null

    val lines: Flow<String> = incoming.receiveAsFlow()

    fun start(): Boolean {
        if (FairyStockfish.nativeStart(binaryPath) != 0) return false
        reader = thread(name = "fairy-reader", isDaemon = true) {
            while (true) {
                val line = FairyStockfish.nativeReadLine() ?: break
                incoming.trySend(line)
            }
        }
        return true
    }

    fun send(command: String) = FairyStockfish.nativeSend(command)

    fun drain() { while (incoming.tryReceive().isSuccess) Unit }

    private suspend fun capture(command: String, timeoutMs: Long, until: (String) -> Boolean): List<String> {
        drain()
        send(command)
        val out = mutableListOf<String>()
        withTimeoutOrNull(timeoutMs) {
            while (true) {
                val line = incoming.receive()
                out += line
                if (until(line)) break
            }
        }
        return out
    }

    /**
     * L'état de la position après `uciLog`, tel que le moteur le voit.
     *
     * `null` si le moteur reste muet — l'appelant doit le dire plutôt que de
     * laisser un plateau figé sans explication.
     */
    suspend fun queryPosition(variant: String, startFen: String?, uciLog: List<String>): PositionQuery? {
        send("setoption name UCI_Variant value $variant")
        val base = if (startFen != null) "position fen $startFen" else "position startpos"
        send(if (uciLog.isEmpty()) base else "$base moves ${uciLog.joinToString(" ")}")

        val display = capture("d", 10_000) { it.startsWith("Checkers:") }
        val fenLine = display.firstOrNull { it.startsWith("Fen: ") } ?: return null
        val fen = fenLine.removePrefix("Fen: ").trim()
        val inCheck = display.firstOrNull { it.startsWith("Checkers:") }
            ?.trim()?.let { it != "Checkers:" } ?: false

        val perft = capture("go perft 1", 15_000) { it.startsWith("Nodes searched") }
        val legal = perft.mapNotNull { line ->
            val colon = line.indexOf(':')
            if (colon <= 0) return@mapNotNull null
            val move = line.substring(0, colon)
            if (isUciMove(move)) move else null
        }

        return PositionQuery(fen, inCheck, legal)
    }

    /** Un coup ordinaire (`e2e4`, `e7e8q`) ou un parachutage (`P@e4`). */
    private fun isUciMove(text: String): Boolean {
        if (text.length in 4..5 && text.all { it.isLowerCase() || it.isDigit() }) return true
        return text.length == 4 && text[1] == '@'
    }

    /** Le meilleur coup du moteur pour la variante. */
    suspend fun bestMove(variant: String, startFen: String?, uciLog: List<String>, movetimeMs: Int): String? {
        send("setoption name UCI_Variant value $variant")
        val base = if (startFen != null) "position fen $startFen" else "position startpos"
        send(if (uciLog.isEmpty()) base else "$base moves ${uciLog.joinToString(" ")}")
        val lines = capture("go movetime $movetimeMs", 60_000) { it.startsWith("bestmove") }
        return lines.lastOrNull { it.startsWith("bestmove") }?.split(" ")?.getOrNull(1)
    }

    fun stop() {
        FairyStockfish.nativeStop()
        reader?.join(3_000)
        incoming.close()
    }

    companion object {
        private val mutex = Mutex()
        private var instance: FairyEngine? = null
        private var failed = false

        /**
         * Donne le moteur de variantes à [block], seul.
         *
         * Même discipline que pour Stockfish, et pour une raison de plus : les
         * deux shims détournent le même `std::cout`, donc les faire vivre en
         * même temps mélangerait leurs sorties.
         */
        suspend fun <T> use(context: Context, block: suspend (FairyEngine) -> T): T? = mutex.withLock {
            val engine = start(context) ?: return@withLock null
            block(engine)
        }

        private fun start(context: Context): FairyEngine? {
            instance?.let { return it }
            if (failed) return null
            val dir = File(context.applicationContext.filesDir, "fairy").apply { mkdirs() }
            val engine = FairyEngine(File(dir, "fairy").absolutePath)
            if (!engine.start()) { failed = true; return null }
            engine.send("uci")
            instance = engine
            return engine
        }
    }
}
