package com.chesslab.puzzles

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square

/**
 * Ce qui compte comme une bonne réponse. Pendant de
 * `PuzzleSolveViewModel.validate` et de `PuzzleSessionDrawer` sur iOS.
 *
 * Fonctions pures : ni base, ni écran — elles se vérifient en JVM.
 */
object PuzzleAnswer {

    /**
     * Le coup MATE-t-il ? Un mat est toujours juste, même s'il n'est pas celui
     * de la solution enregistrée : beaucoup de positions offrent deux mats au
     * dernier coup (Lichess accepte d'ailleurs n'importe lequel), et la
     * solution d'un puzzle maison n'est qu'UNE variante du moteur. Le compter
     * faux punissait une bonne réponse.
     *
     * [promotion] `null` pour une promotion encore en attente de choix : le
     * coup n'est pas jugé tant que la pièce n'est pas choisie.
     */
    fun deliversMate(position: Position, from: Square, to: Square, promotion: Piece.Kind? = null): Boolean {
        val board = Board(position)
        val move = board.move(pieceAt = from, to = to) ?: return false
        if (board.state is Board.State.Promotion) {
            board.completePromotion(of = move, to = promotion ?: return false)
        }
        return board.state is Board.State.Checkmate
    }

    /**
     * Ce puzzle répond-il aux critères de la séance ? Un puzzle maison n'a pas
     * de cote : un niveau choisi l'exclut, comme sur iOS (sa cote y vaut -1).
     */
    fun accepts(puzzle: Puzzle, filter: PuzzleFilter, isOwn: Boolean): Boolean =
        (filter.theme == null || puzzle.theme == filter.theme.raw) &&
            (filter.phase == null || puzzle.phase == filter.phase.raw) &&
            (filter.difficulty == null || (!isOwn && puzzle.rating in filter.ratings))
}
