package com.chesslab.spike

/**
 * Accès brut au moteur natif. Un seul moteur par process, exactement comme
 * côté iOS (Stockfish a un état global).
 */
object Stockfish {
    init { System.loadLibrary("chesslab_engine") }

    /** 0 si démarré, -1 si un moteur tourne déjà. */
    external fun nativeStart(binaryPath: String): Int
    external fun nativeSend(command: String)
    /** Bloque jusqu'à la prochaine ligne ; `null` quand le moteur est arrêté. */
    external fun nativeReadLine(): String?
    external fun nativeStop()
    external fun nativeIsRunning(): Boolean
}
