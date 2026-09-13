package com.chesslab.editor

import chesskit.Board
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R

/**
 * Ce qui fait qu'une FEN décrit une position JOUABLE. Pendant de
 * `FENValidator.swift`.
 *
 * Le parseur est permissif : six jetons quelconques lui font un échiquier
 * vide sans broncher. Ici on exige ce que le jeu exige — deux rois, pas de
 * pion sur la première ou la dernière rangée, et le camp qui n'a pas le trait
 * pas déjà en échec (sinon il aurait dû jouer autre chose).
 */
object FenValidator {

    fun isLegal(fen: String): Boolean = errors(fen).isEmpty()

    /** Les défauts trouvés, en clés de ressources (`R.string`) — l'écran les met en mots. */
    fun errors(fen: String): List<Int> {
        val trimmed = fen.trim()
        if (trimmed.split(" ").filter { it.isNotEmpty() }.size != 6) return listOf(R.string.fen_error_fields)
        val position = FenParser.parse(trimmed) ?: return listOf(R.string.fen_error_fields)

        val errors = ArrayList<Int>()
        val whiteKings = position.pieces.count { it.kind == Piece.Kind.king && it.color == Piece.Color.white }
        val blackKings = position.pieces.count { it.kind == Piece.Kind.king && it.color == Piece.Color.black }
        if (whiteKings != 1 || blackKings != 1) errors += R.string.fen_error_kings

        if (position.pieces.any { it.kind == Piece.Kind.pawn && it.square.rank.value.let { r -> r == 1 || r == 8 } }) {
            errors += R.string.fen_error_pawn_rank
        }

        // Le camp qui N'A PAS le trait est-il déjà en échec ? On lui rend le
        // trait le temps de regarder : si ce plateau le dit en échec, la
        // position ne peut pas venir d'une partie.
        if (whiteKings == 1 && blackKings == 1) {
            val flipped = Position(
                position.pieces, position.sideToMove.opposite, position.legalCastlings, null, position.clock,
            )
            val state = Board(flipped).state
            if (state is Board.State.Check || state is Board.State.Checkmate) errors += R.string.fen_error_opponent_in_check

            // Le symétrique : un camp au trait sans aucun coup légal est une
            // position déjà terminée (mat ou pat). Le moteur, interrogé
            // dessus, répondrait `bestmove (none)` — écran de jeu figé.
            if (!hasLegalMove(position)) errors += R.string.fen_error_no_legal_move
        }

        val castling = trimmed.split(" ")[2]
        if (castling != "-") {
            if ('K' in castling && !hasRookAndKing(position, "e1", "h1", Piece.Color.white)) errors += R.string.fen_error_castling_wk
            if ('Q' in castling && !hasRookAndKing(position, "e1", "a1", Piece.Color.white)) errors += R.string.fen_error_castling_wq
            if ('k' in castling && !hasRookAndKing(position, "e8", "h8", Piece.Color.black)) errors += R.string.fen_error_castling_bk
            if ('q' in castling && !hasRookAndKing(position, "e8", "a8", Piece.Color.black)) errors += R.string.fen_error_castling_bq
        }

        val enPassant = trimmed.split(" ")[3]
        if (enPassant != "-" && enPassant.length == 2) {
            val file = enPassant[0]
            val (pawnSquare, pawnColor) = when (enPassant[1]) {
                '3' -> "${file}4" to Piece.Color.white
                '6' -> "${file}5" to Piece.Color.black
                else -> null to null
            }
            if (pawnSquare == null) errors += R.string.fen_error_ep_rank
            else {
                val pawn = position.piece(Square(pawnSquare))
                if (pawn?.kind != Piece.Kind.pawn || pawn.color != pawnColor) errors += R.string.fen_error_ep_pawn
            }
        }
        return errors
    }

    /** `legalMoves` ne consulte pas le trait : on interroge les pièces du camp au trait. */
    private fun hasLegalMove(position: Position): Boolean {
        val board = Board(position)
        return position.pieces.any { it.color == position.sideToMove && board.legalMoves(it.square).isNotEmpty() }
    }

    private fun hasRookAndKing(position: Position, king: String, rook: String, color: Piece.Color): Boolean {
        val k = position.piece(Square(king)); val r = position.piece(Square(rook))
        return k?.kind == Piece.Kind.king && k.color == color && r?.kind == Piece.Kind.rook && r.color == color
    }
}
