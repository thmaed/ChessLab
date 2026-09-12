package com.chesslab.engine

/**
 * Accès brut au moteur natif. Un seul moteur par process, comme côté iOS :
 * Stockfish a un état global, et le shim refuse un second démarrage.
 */
internal object Stockfish {
    init { System.loadLibrary("chesslab_engine") }

    /** 0 si démarré, -1 si un moteur tourne déjà. */
    external fun nativeStart(binaryPath: String): Int
    external fun nativeSend(command: String)
    /** Bloque jusqu'à la prochaine ligne ; `null` quand le moteur est arrêté. */
    external fun nativeReadLine(): String?
    external fun nativeStop()
    external fun nativeIsRunning(): Boolean

    /** Rend au système les pages que l'allocateur natif garde en réserve. */
    external fun nativePurge()
}
