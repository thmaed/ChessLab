package com.chesslab.engine

/**
 * Accès brut à Fairy-Stockfish. Bibliothèque SÉPARÉE de Stockfish : les deux
 * moteurs ne partagent aucun symbole (`namespace Stockfish` contre
 * `namespace FairyEngine`), mais ils partagent le `std::cout` du process, que
 * leurs shims détournent tous deux — d'où la règle « un seul à la fois ».
 */
internal object FairyStockfish {
    init { System.loadLibrary("chesslab_fairy") }

    external fun nativeStart(binaryPath: String): Int
    external fun nativeSend(command: String)
    external fun nativeReadLine(): String?
    external fun nativeStop()
    external fun nativeIsRunning(): Boolean
}
