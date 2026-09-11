package com.chesslab.spike

import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Enveloppe utilisable du moteur : un thread lecteur draine la file native et
 * alimente une file Java, que l'appelant consomme avec [awaitLine].
 *
 * C'est le pendant Kotlin d'`EngineController` (l'acteur Swift) — en beaucoup
 * plus rudimentaire, un spike n'ayant pas à gérer le cycle de vie complet.
 */
class EngineSession(private val binaryPath: String, private val log: (String) -> Unit) {

    private val queue = LinkedBlockingQueue<String>()
    private var reader: Thread? = null

    fun start(): Boolean {
        if (Stockfish.nativeStart(binaryPath) != 0) return false
        reader = thread(name = "stockfish-reader", isDaemon = true) {
            while (true) {
                val line = Stockfish.nativeReadLine() ?: break
                queue.put(line)
            }
        }
        return true
    }

    fun send(command: String) {
        log("> $command")
        Stockfish.nativeSend(command)
    }

    /**
     * Consomme les lignes jusqu'à ce que [predicate] accepte, ou jusqu'au
     * délai. Rend la ligne acceptée, ou `null` si le délai a expiré.
     * [onLine] voit passer TOUTES les lignes lues (utile pour capter les
     * `info` de la recherche).
     */
    fun awaitLine(
        timeoutMs: Long,
        onLine: (String) -> Unit = {},
        predicate: (String) -> Boolean,
    ): String? {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (true) {
            val remaining = deadline - System.currentTimeMillis()
            if (remaining <= 0) return null
            val line = queue.poll(remaining, TimeUnit.MILLISECONDS) ?: return null
            onLine(line)
            if (predicate(line)) return line
        }
    }

    fun stop() {
        Stockfish.nativeStop()
        reader?.join(3000)
    }
}
