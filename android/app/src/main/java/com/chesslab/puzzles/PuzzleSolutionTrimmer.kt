package com.chesslab.puzzles

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.play.CapturedMaterial

/**
 * Tronque la variante du moteur en une solution COURTE ET NETTE, pour les
 * puzzles tirés d'une partie de l'utilisateur. Pendant de
 * `PuzzleSolutionTrimmer.swift`.
 *
 * Exiger la séquence complète du moteur est fragile : la queue d'une variante
 * n'est pas fiable, et un coup gagnant ALTERNATIF y serait compté faux. Les
 * puzzles Lichess, eux, sont curés pour l'unicité — cette troncature ne
 * concerne QUE les puzzles maison.
 *
 * L'heuristique est purement MATÉRIELLE, donc sans moteur : déterministe, et
 * vérifiable sur des positions écrites à la main. On rejoue la variante et on
 * coupe dès qu'après un coup du résolveur son avantage devient décisif (une
 * pièce mineure) ET stable — ou à un mat.
 */
object PuzzleSolutionTrimmer {

    fun trim(
        pv: List<String>,
        startFen: String,
        decisiveGain: Int = 3,
        maxPlies: Int = 6,
    ): List<String> {
        val start = Position.fromFen(startFen)
            ?: return endingOnSolverMove(pv.take(maxPlies))
        val solver = start.sideToMove
        val baseDiff = materialDiff(start, solver)

        val board = Board(start)
        val applied = ArrayList<String>()

        pv.take(maxPlies).forEachIndexed { ply, lan ->
            if (!apply(lan, board)) return endingOnSolverMove(applied)
            applied += lan

            // Un mat est décisif quel que soit le matériel.
            if (board.state is Board.State.Checkmate) return applied

            // pv[0] est le coup du résolveur : il joue les index pairs.
            if (ply % 2 != 0) return@forEachIndexed

            val gain = materialDiff(board.position, solver) - baseDiff
            if (gain < decisiveGain) return@forEachIndexed

            // Stabilité : la riposte forcée ne doit pas résorber l'avantage,
            // sinon c'est un échange en cours et la tactique n'est pas résolue.
            val replyIndex = ply + 1
            if (replyIndex < pv.size && replyIndex < maxPlies) {
                val probe = Board(board.position.copy())
                if (apply(pv[replyIndex], probe)) {
                    val after = materialDiff(probe.position, solver) - baseDiff
                    if (after >= decisiveGain) return applied
                    return@forEachIndexed
                }
            }
            return applied
        }
        return endingOnSolverMove(applied)
    }

    /**
     * Une solution se termine toujours sur un coup du RÉSOLVEUR (longueur
     * impaire) : sinon le dernier demi-coup est une riposte auto-jouée, ce qui
     * n'a pas de sens comme état « résolu ».
     */
    private fun endingOnSolverMove(moves: List<String>): List<String> =
        if (moves.size > 1 && moves.size % 2 == 0) moves.dropLast(1) else moves

    /** Le matériel de [color] moins celui de l'adversaire (le roi vaut 0). */
    private fun materialDiff(position: Position, color: Piece.Color): Int =
        position.pieces.sumOf {
            val v = CapturedMaterial.value(it.kind)
            if (it.color == color) v else -v
        }

    private fun apply(lan: String, board: Board): Boolean {
        if (lan.length < 4) return false
        val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return false
        if (board.state is Board.State.Promotion) {
            val kind = when (lan.getOrNull(4)?.lowercaseChar()) {
                'n' -> Piece.Kind.knight
                'b' -> Piece.Kind.bishop
                'r' -> Piece.Kind.rook
                else -> Piece.Kind.queen
            }
            board.completePromotion(move, kind)
        }
        return true
    }
}
