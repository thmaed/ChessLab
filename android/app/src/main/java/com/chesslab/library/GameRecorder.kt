package com.chesslab.library

import android.content.Context
import com.chesslab.R
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

    /**
     * Le résultat posé par [save] ; `null` tant que la partie n'est pas
     * rangée. Les exports le lisent ici : une partie finie se partage avec son
     * score, une partie en cours avec « * ».
     */
    var finalResult: String? = null
        private set

    fun reset(startingPosition: Position = Position.standard, startFen: String? = null) {
        game = Game(startingPosition)
        cursor = game.startingIndex
        finalResult = null
        if (startFen != null) {
            game.tags.setUp = "1"
            game.tags.fen = startFen
        }
    }

    val moveCount: Int get() = game.moves.indices.size

    /**
     * Le PGN de la partie TELLE QU'ELLE EST, pour l'envoyer à l'analyse sans
     * attendre qu'elle soit rangée dans la bibliothèque. Les tags `SetUp` et
     * `FEN` posés par [reset] en font partie : sans eux, l'analyse rejouerait
     * les coups depuis la position standard et n'afficherait rien.
     */
    val pgn: String get() = game.pgn

    /**
     * Le PGN À PARTAGER pendant la partie : les sept balises du standard en
     * plus — joueurs, date, et « * » tant que rien n'est joué jusqu'au bout.
     * Voir [PgnExport].
     */
    fun pgn(metadata: PgnExport.Metadata): String = PgnExport.pgn(game, metadata)

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
        /**
         * Le score, quand il ne se lit pas sur le plateau : un abandon, une
         * nulle acceptée, un drapeau tombé. `null` = on le déduit de l'état.
         */
        forcedResult: String? = null,
        variant: String? = null,
        /** Le personnage affronté, son niveau et sa couleur — ce que la progression ventile. */
        opponentId: String? = null,
        engineElo: Int? = null,
        engineColor: Piece.Color? = null,
        scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
    ) {
        if (moveCount == 0) return

        val result = forcedResult ?: when (state) {
            is Board.State.Checkmate -> if (state.color == Piece.Color.white) "0-1" else "1-0"
            is Board.State.Draw -> "1/2-1/2"
            else -> "*"
        }
        // Les balises portent les noms AFFICHÉS (le nom choisi, ou « Vous »
        // dans la langue du jour) ; les colonnes de l'enregistrement, elles,
        // gardent la sentinelle — c'est par elle que la progression sait de
        // quel côté on jouait. Événement = le MODE, comme côté iOS.
        val event = context.getString(
            if (source == "twoPlayer") R.string.route_two_players else R.string.route_play
        )
        val metadata = PgnExport.Metadata(
            event = event,
            white = PlayerName.display(context, white, PlayerName.white(context)),
            black = PlayerName.display(context, black, PlayerName.black(context)),
            result = result,
        )
        val exported = PgnExport.pgn(game, metadata)
        finalResult = result

        val record = GameRecord(
            playedAt = System.currentTimeMillis(),
            white = white, black = black, result = result,
            source = source, variant = variant,
            moveCount = moveCount,
            pgn = exported,
            opponentId = opponentId,
            engineElo = engineElo,
            engineColor = engineColor?.let { if (it == Piece.Color.white) "white" else "black" },
        )
        scope.launch { LibraryDatabase.get(context).games().insert(record) }
    }
}
