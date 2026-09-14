package com.chesslab.play

import chesskit.Board
import chesskit.Piece
import chesskit.Square
import com.chesslab.maia.SafetyNet
import com.chesslab.maia.SafetyNetPolicy

/**
 * Un coup de personnage, ARBITRÉ : Maia propose, le filet dispose. Pendant de
 * `MaiaTurnResolver.swift`.
 *
 * Les quatre cas sont bornés, et c'est volontaire : ailleurs, le personnage
 * joue ce qu'il veut — y compris se tromper, ce qui est tout l'intérêt d'un
 * réseau entraîné sur des parties humaines. Le filet n'existe que pour les
 * choses qu'un joueur de ce niveau ne raterait pas : un mat en deux, une
 * finale technique, une répétition en position gagnée.
 */
object MaiaTurnResolver {

    /** Ce qu'une recherche courte de Stockfish à pleine puissance a rendu. */
    data class Quick(val lan: String?, val cp: Int?, val mate: Int?)

    sealed class Decision {
        /** Le coup de Maia, tel quel. */
        data object Play : Decision()
        /** Le coup de Stockfish à la place. */
        data class Override(val lan: String) : Decision()
        /**
         * Finale technique : l'appelant doit lancer une recherche BRIDÉE au
         * niveau du personnage et jouer son résultat.
         */
        data object SearchBridled : Decision()
    }

    fun resolve(
        maiaUci: String,
        quick: Quick?,
        level: Int,
        pieceCount: Int,
        policy: SafetyNetPolicy,
        board: Board,
    ): Decision {
        if (quick == null) return Decision.Play
        val best = quick.lan
        if (best != null && SafetyNet.overridesForMate(policy, level, quick.mate)) {
            return Decision.Override(best)
        }
        if (SafetyNet.overridesEndgame(policy, level, pieceCount)) return Decision.SearchBridled
        val after = stateAfter(maiaUci, board)
        if (best != null && after != null && SafetyNet.overridesRepetition(policy, after, quick.cp)) {
            return Decision.Override(best)
        }
        return Decision.Play
    }

    /** L'état du plateau APRÈS le coup, sans toucher au plateau de la partie. */
    fun stateAfter(lan: String, board: Board): Board.State? {
        if (lan.length < 4) return null
        val made = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4))) ?: return null
        if (board.state is Board.State.Promotion) {
            val kind = if (lan.length == 5) when (lan[4]) {
                'r' -> Piece.Kind.rook
                'b' -> Piece.Kind.bishop
                'n' -> Piece.Kind.knight
                else -> Piece.Kind.queen
            } else Piece.Kind.queen
            board.completePromotion(made, kind)
        }
        return board.state
    }
}
