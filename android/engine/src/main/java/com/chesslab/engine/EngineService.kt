package com.chesslab.engine

import android.content.Context
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Le moteur, partagé par toute l'app.
 *
 * Stockfish n'accepte qu'UNE instance par process — c'est une contrainte de
 * son état global, pas un choix. Côté iOS, l'ignorer avait coûté cher : deux
 * écrans démarraient chacun le leur, le second échouait en silence et
 * attendait un `uciok` qui n'arrivait jamais, pendant que ses commandes
 * polluaient le flux de l'autre.
 *
 * D'où ce service : un seul moteur, démarré à la première demande, et un
 * verrou qui garantit qu'un écran a le moteur pour lui seul le temps de sa
 * question.
 */
object EngineService {

    private val mutex = Mutex()
    private var engine: StockfishEngine? = null
    private var failed = false

    /** L'identité annoncée par le moteur, une fois démarré. */
    var identity: String? = null
        private set

    val threads: Int
        get() = (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, 4)

    /**
     * Donne le moteur à [block], seul. Rend `null` si le moteur n'a pas pu
     * démarrer — l'appelant doit alors le dire à l'utilisateur plutôt que
     * d'attendre.
     */
    suspend fun <T> use(context: Context, block: suspend (StockfishEngine) -> T): T? =
        mutex.withLock {
            val e = start(context) ?: return@withLock null
            block(e)
        }

    private suspend fun start(context: Context): StockfishEngine? {
        engine?.let { return it }
        if (failed) return null

        val app = context.applicationContext
        val assets = app.assets
        val nets = assets.list("")!!.filter { it.endsWith(".nnue") }
        val path = StockfishEngine.prepare(nets, app.filesDir) { assets.open(it) }

        val e = StockfishEngine(path)
        if (!e.start()) { failed = true; return null }
        identity = e.handshake(threads, hashMb = 64)
        if (identity == null) { failed = true; e.stop(); return null }

        engine = e
        return e
    }
}
