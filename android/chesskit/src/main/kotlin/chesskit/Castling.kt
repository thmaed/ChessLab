package chesskit

/** Traduction Kotlin de `Castling.swift` (ChessKit, MIT). */
data class Castling(val side: Side, val color: Piece.Color) {

    @Suppress("EnumEntryName")
    enum class Side(val notation: String) { king("O-O"), queen("O-O-O") }

    /** Les cases que le roi TRAVERSE — aucune ne doit être attaquée. */
    val squares: List<Square>
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) listOf(Square.c1, Square.d1) else listOf(Square.f1, Square.g1)
            Piece.Color.black -> if (side == Side.queen) listOf(Square.c8, Square.d8) else listOf(Square.f8, Square.g8)
        }

    /** Les cases qui doivent être VIDES entre le roi et la tour. */
    val path: List<Square>
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) listOf(Square.b1, Square.c1, Square.d1) else listOf(Square.f1, Square.g1)
            Piece.Color.black -> if (side == Side.queen) listOf(Square.b8, Square.c8, Square.d8) else listOf(Square.f8, Square.g8)
        }

    val kingStart: Square get() = if (color == Piece.Color.white) Square.e1 else Square.e8

    val kingEnd: Square
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) Square.c1 else Square.g1
            Piece.Color.black -> if (side == Side.queen) Square.c8 else Square.g8
        }

    val rookStart: Square
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) Square.a1 else Square.h1
            Piece.Color.black -> if (side == Side.queen) Square.a8 else Square.h8
        }

    val rookEnd: Square
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) Square.d1 else Square.f1
            Piece.Color.black -> if (side == Side.queen) Square.d8 else Square.f8
        }

    val fen: String
        get() = when (color) {
            Piece.Color.white -> if (side == Side.queen) "Q" else "K"
            Piece.Color.black -> if (side == Side.queen) "q" else "k"
        }

    companion object {
        val bK = Castling(Side.king, Piece.Color.black)
        val wK = Castling(Side.king, Piece.Color.white)
        val bQ = Castling(Side.queen, Piece.Color.black)
        val wQ = Castling(Side.queen, Piece.Color.white)
        val all = listOf(bK, wK, bQ, wQ)
    }
}

/**
 * Les roques encore permis par l'historique (le roi et la tour n'ont pas
 * bougé) — indépendamment des échecs, que `Board` vérifie séparément.
 *
 * Écart assumé : là où l'original mute son tableau (`invalidateCastling`),
 * cette version est immuable et rend une nouvelle valeur. Kotlin y gagne une
 * `data class` dont l'égalité est celle attendue par les tests.
 */
data class LegalCastlings(val legal: List<Castling> = Castling.all) {

    operator fun contains(castling: Castling): Boolean = castling in legal

    /** Retire les roques que le déplacement de `piece` rend impossibles. */
    fun invalidating(piece: Piece): LegalCastlings = when (piece.kind) {
        Piece.Kind.king -> LegalCastlings(legal.filterNot { it.color == piece.color })
        Piece.Kind.rook -> LegalCastlings(legal.filterNot { it.color == piece.color && it.rookStart == piece.square })
        else -> this
    }

    /** Trié : donne toujours « KQkq », par l'ordre des codes ASCII. */
    val fen: String
        get() = if (legal.isEmpty()) "-" else legal.map { it.fen }.sorted().joinToString("")
}

/** Le pion qui vient d'avancer de deux cases et peut être pris en passant. */
data class EnPassant(val pawn: Piece) {

    /** La case où arrive le pion qui capture. */
    val captureSquare: Square
        get() = Square(pawn.square.file, Square.Rank(if (pawn.color == Piece.Color.white) 3 else 6))

    /**
     * `capturingPiece` pourrait-il capturer ce pion ? Il doit être un pion de
     * la couleur opposée, sur la même rangée, à une colonne d'écart.
     */
    fun couldBeCaptured(by: Piece): Boolean =
        by.kind == Piece.Kind.pawn &&
            by.color == pawn.color.opposite &&
            by.square.rank == pawn.square.rank &&
            kotlin.math.abs(by.square.file.number - pawn.square.file.number) == 1
}

data class Clock(var halfmoves: Int = 0, var fullmoves: Int = 1) {
    companion object { const val HALF_MOVE_MAXIMUM = 100 }
}
