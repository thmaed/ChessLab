package com.chesslab.library

import android.content.Context
import chesskit.Board
import chesskit.Game
import chesskit.Move
import chesskit.MoveTree
import chesskit.Piece
import chesskit.Position
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Tient la partie en cours sous forme de `Game`, et l'enregistre quand elle
 * se termine.
 *
 * Pourquoi un `Game` en plus du `Board` : le plateau connaît la POSITION,
 * pas l'HISTOIRE. C'est le `Game` qui porte l'arbre des coups et sait rendre
 * un PGN — celui-là même que l'app iOS exporte.
 */
class GameRecorder(startingPosition: Position = Position.standard) {

    private var game = Game(startingPosition)
    private var cursor = game.startingIndex

    fun record(move: Move) {
        cursor = game.make(move, from = cursor)
    }

    fun reset(startingPosition: Position = Position.standard, startFen: String? = null) {
        game = Game(startingPosition)
        cursor = game.startingIndex
        if (startFen != null) {
            game.tags.setUp = "1"
            game.tags.fen = startFen
        }
    }

    val moveCount: Int get() = game.moves.indices.size

    /**
     * Écrit la partie. `null` si elle est vide — une partie sans coup n'a rien
     * à faire dans la bibliothèque.
     */
    fun save(
        context: Context,
        white: String,
        black: String,
        source: String,
        state: Board.State,
        variant: String? = null,
        scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
    ) {
        if (moveCount == 0) return

        val result = when (state) {
            is Board.State.Checkmate -> if (state.color == Piece.Color.white) "0-1" else "1-0"
            is Board.State.Draw -> "1/2-1/2"
            else -> "*"
        }
        game.tags.white = white
        game.tags.black = black
        game.tags.result = result
        game.tags.date = SimpleDateFormat("yyyy.MM.dd", Locale.FRANCE).format(Date())
        game.tags.event = "ChessLab"

        val record = GameRecord(
            playedAt = System.currentTimeMillis(),
            white = white, black = black, result = result,
            source = source, variant = variant,
            moveCount = moveCount,
            pgn = game.pgn,
        )
        scope.launch { LibraryDatabase.get(context).games().insert(record) }
    }
}
