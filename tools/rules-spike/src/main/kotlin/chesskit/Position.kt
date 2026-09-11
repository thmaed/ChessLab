package chesskit

/** Traduction Kotlin de `Castling.swift` (ChessKit, MIT), réduite au FEN. */
data class Castling(val side: Side, val color: Piece.Color) {

    @Suppress("EnumEntryName")
    enum class Side { king, queen }

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
    }
}

/**
 * Les roques encore légaux. L'ordre est significatif pour l'égalité, comme
 * dans l'original (un tableau Swift) ; le FEN, lui, est trié — ce qui donne
 * toujours « KQkq » par l'ordre des codes ASCII.
 */
data class LegalCastlings(val legal: List<Castling> = emptyList()) {
    val fen: String
        get() = if (legal.isEmpty()) "-" else legal.map { it.fen }.sorted().joinToString("")
}

/** Le pion qui vient d'avancer de deux cases et peut être pris en passant. */
data class EnPassant(val pawn: Piece) {
    /** La case où arrive le pion qui capture. */
    val captureSquare: Square
        get() = Square(pawn.square.file, Square.Rank(if (pawn.color == Piece.Color.white) 3 else 6))
}

data class Clock(val halfmoves: Int = 0, val fullmoves: Int = 1)

/** Traduction Kotlin de `Position.swift` (ChessKit, MIT), réduite au FEN. */
data class Position(
    val pieces: List<Piece>,
    val sideToMove: Piece.Color = Piece.Color.white,
    val legalCastlings: LegalCastlings = LegalCastlings(),
    val enPassant: EnPassant? = null,
    val clock: Clock = Clock(),
) {
    fun piece(at: Square): Piece? = pieces.firstOrNull { it.square == at }

    val fen: String get() = FenParser.convert(this)

    companion object {
        fun fromFen(fen: String): Position? = FenParser.parse(fen)

        val standard: Position
            get() = fromFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")!!
    }
}
