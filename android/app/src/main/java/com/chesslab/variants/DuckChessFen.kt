package com.chesslab.variants

import chesskit.Castling
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import kotlin.math.abs

/**
 * L'écriture d'une FEN pour le Duck Chess. Pendant de `DuckChessFEN.swift`.
 *
 * Nécessaire parce que la variante joue des coups que `chesskit` REFUSE — il
 * filtre sur l'échec, notion absente ici. On ne peut donc pas lui demander
 * d'appliquer le coup et de rendre la position ; on écrit le plateau résultant
 * nous-mêmes, et on le relit.
 *
 * Le canard ne figure PAS dans la FEN : il n'est pas une pièce, il vit à part
 * dans le modèle. Une FEN de Duck Chess est donc une FEN ordinaire, relisible
 * par `chesskit` — c'est ce qui permet de réutiliser tout l'affichage sans le
 * toucher. La case de prise en passant vit à part elle aussi, pour la même
 * raison : elle se transmet en argument, pas dans le texte.
 */
object DuckChessFen {

    fun build(squares: Map<Square, Piece>, sideToMove: Piece.Color, castling: String): String {
        val ranks = ArrayList<String>()
        for (rank in 8 downTo 1) {
            val line = StringBuilder()
            var empty = 0
            for (file in "abcdefgh") {
                val piece = squares[Square("$file$rank")]
                if (piece != null) {
                    if (empty > 0) { line.append(empty); empty = 0 }
                    line.append(letter(piece))
                } else {
                    empty++
                }
            }
            if (empty > 0) line.append(empty)
            ranks += line.toString()
        }
        val rights = castling.ifEmpty { "-" }
        return "${ranks.joinToString("/")} ${if (sideToMove == Piece.Color.white) "w" else "b"} $rights - 0 1"
    }

    /**
     * Droits de roque après un coup : le roi les perd tous, une tour perd le
     * sien. Aucun ne se regagne.
     */
    fun updatedCastling(position: Position, moved: Piece, from: Square, to: Square): String {
        var rights = buildString {
            if (Castling.wK in position.legalCastlings) append('K')
            if (Castling.wQ in position.legalCastlings) append('Q')
            if (Castling.bK in position.legalCastlings) append('k')
            if (Castling.bQ in position.legalCastlings) append('q')
        }
        if (rights.isEmpty()) return ""

        fun drop(chars: String) { rights = rights.filterNot { it in chars } }
        if (moved.kind == Piece.Kind.king) drop(if (moved.color == Piece.Color.white) "KQ" else "kq")
        // Une tour qui bouge, ou qui se fait prendre sur sa case d'origine.
        for (square in listOf(from, to)) {
            when (square.notation) {
                "a1" -> drop("Q")
                "h1" -> drop("K")
                "a8" -> drop("q")
                "h8" -> drop("k")
            }
        }
        return rights
    }

    /**
     * La position APRÈS le coup. Le trait reste au MÊME camp : son tour n'est
     * pas fini, il lui reste le canard à poser. C'est la pose qui le passe, et
     * elle seule — faire les deux basculerait le trait deux fois par
     * demi-coup, donc jamais.
     */
    fun applied(move: DuckChessRules.Move, position: Position): Position {
        val squares = HashMap<Square, Piece>()
        for (piece in position.pieces) squares[piece.square] = piece

        val moving = squares[move.from] ?: return position
        squares.remove(move.from)

        // Prise en passant : le pion capturé n'est PAS sur la case d'arrivée.
        if (moving.kind == Piece.Kind.pawn && move.from.file != move.to.file && squares[move.to] == null) {
            squares.remove(Square("${move.to.file.letter}${move.from.rank.value}"))
        }
        // Roque : la tour suit le roi.
        if (moving.kind == Piece.Kind.king && abs(move.to.file.number - move.from.file.number) == 2) {
            val rank = move.from.rank.value
            val short = move.to.file.number > move.from.file.number
            val rookFrom = Square("${if (short) "h" else "a"}$rank")
            val rookTo = Square("${if (short) "f" else "d"}$rank")
            squares.remove(rookFrom)?.let { rook -> squares[rookTo] = Piece(rook.kind, rook.color, rookTo) }
        }
        squares[move.to] = Piece(move.promotion ?: moving.kind, moving.color, move.to)

        val fen = build(
            squares = squares,
            sideToMove = position.sideToMove,
            castling = updatedCastling(position, moving, move.from, move.to),
        )
        return FenParser.parse(fen) ?: position
    }

    /** La même position, le trait retourné : c'est la POSE du canard qui le passe. */
    fun flippedSideToMove(position: Position): Position {
        val fields = position.fen.split(" ").toMutableList()
        if (fields.size < 2) return position
        fields[1] = if (fields[1] == "w") "b" else "w"
        return FenParser.parse(fields.joinToString(" ")) ?: position
    }

    private fun letter(piece: Piece): String {
        val base = when (piece.kind) {
            Piece.Kind.pawn -> "p"
            Piece.Kind.knight -> "n"
            Piece.Kind.bishop -> "b"
            Piece.Kind.rook -> "r"
            Piece.Kind.queen -> "q"
            Piece.Kind.king -> "k"
        }
        return if (piece.color == Piece.Color.white) base.uppercase() else base
    }
}
