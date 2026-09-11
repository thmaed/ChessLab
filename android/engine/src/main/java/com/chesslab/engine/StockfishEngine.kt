package com.chesslab.engine

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.concurrent.thread

/**
 * Le moteur, vu de Kotlin. Pendant d'`EngineController` (l'acteur Swift).
 *
 * **Un Channel, pas un SharedFlow.** Les lignes du moteur sont mises en file
 * dès leur arrivée, qu'il y ait ou non un consommateur. C'est délibéré : côté
 * iOS, le flux perdait des lignes quand l'abonnement arrivait après l'envoi de
 * la commande (« uciok jamais reçu »). Une file supprime la course.
 *
 * Le moteur lui-même vit dans le process natif ; cette classe ne fait que
 * pousser des commandes et drainer des réponses.
 */
class StockfishEngine(private val binaryPath: String) {

    private val incoming = Channel<String>(Channel.UNLIMITED)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var reader: Thread? = null

    /** Toutes les lignes du moteur, dans l'ordre. */
    val lines: Flow<String> = incoming.receiveAsFlow()

    val isRunning: Boolean get() = Stockfish.nativeIsRunning()

    /** `false` si un moteur tourne déjà dans ce process. */
    fun start(): Boolean {
        if (Stockfish.nativeStart(binaryPath) != 0) return false
        reader = thread(name = "stockfish-reader", isDaemon = true) {
            while (true) {
                val line = Stockfish.nativeReadLine() ?: break
                incoming.trySend(line)
            }
        }
        return true
    }

    fun send(command: String) = Stockfish.nativeSend(command)

    /**
     * Consomme les lignes jusqu'à ce que [predicate] accepte, ou jusqu'au
     * délai. [onLine] voit passer toutes les lignes lues.
     */
    suspend fun awaitLine(
        timeoutMs: Long,
        onLine: (String) -> Unit = {},
        predicate: (String) -> Boolean,
    ): String? = withTimeoutOrNull(timeoutMs) {
        while (true) {
            val line = incoming.receive()
            onLine(line)
            if (predicate(line)) return@withTimeoutOrNull line
        }
        @Suppress("UNREACHABLE_CODE") null
    }

    /** Poignée de main UCI complète. Rend l'identité du moteur, ou `null`. */
    suspend fun handshake(threads: Int, hashMb: Int): String? {
        send("uci")
        var identity: String? = null
        val uciok = awaitLine(10_000, onLine = {
            if (it.startsWith("id name")) identity = it.removePrefix("id name ").trim()
        }) { it.trim() == "uciok" } ?: return null
        check(uciok.isNotEmpty())

        send("setoption name Threads value $threads")
        send("setoption name Hash value $hashMb")
        send("isready")
        awaitLine(30_000) { it.trim() == "readyok" } ?: return null
        return identity
    }

    fun stop() {
        Stockfish.nativeStop()
        reader?.join(3_000)
        scope.cancel()
        incoming.close()
    }

    companion object {
        /**
         * Prépare le dossier du moteur : les réseaux NNUE doivent être de
         * VRAIS fichiers, or les assets Android n'en sont pas. On les extrait
         * une fois, puis Stockfish les trouve à côté du chemin qu'on lui donne.
         *
         * - returns: le chemin fictif à passer à [StockfishEngine].
         */
        fun prepare(assetNames: List<String>, filesDir: File, open: (String) -> java.io.InputStream): String {
            val dir = File(filesDir, "engine").apply { mkdirs() }
            for (name in assetNames) {
                val target = File(dir, name)
                if (target.exists() && target.length() > 0) continue
                open(name).use { input ->
                    target.outputStream().use { output -> input.copyTo(output, 1 shl 20) }
                }
            }
            return File(dir, "stockfish").absolutePath
        }
    }
}
