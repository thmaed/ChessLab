package chesskit

/**
 * Traduction Kotlin de `EngineLANParser.swift` (ChessKit, MIT) : la notation
 * longue des moteurs UCI — `e2e4`, `e1g1` (petit roque blanc), `e7e8q`.
 *
 * Ce parseur ne cherche ni échec ni mat : `checkState` reste toujours `none`.
 */
object EngineLanParser {

    private val movePattern = Regex("""^([a-h][1-8]){2}[qrbn]?$""")

    fun parse(move: String, color: Piece.Color, position: Position): Move? {
        if (!movePattern.containsMatchIn(move)) return null

        val start = Square(move.substring(0, 2))
        val end = Square(move.substring(2, 4))

        val promotedPiece = if (move.length == 5) {
            val kind = Piece.Kind.entries.firstOrNull { it.notation == move.last().uppercase() }
            kind?.let { Piece(it, color, end) }
        } else null

        val board = Board(position.copy())
        if (!board.canMove(pieceAt = start, to = end)) return null
        val piece = position.piece(start) ?: return null

        val captured = position.piece(end)
        val result = when {
            captured != null -> Move.Result.Capture(captured)
            // Écart assumé : l'original déduit le roque du seul couple de cases,
            // si bien qu'une DAME allant de e1 à g1 sur une case vide était
            // annoncée « O-O ». On exige en plus que la pièce soit un roi.
            piece.kind == Piece.Kind.king -> castlingFor(move)?.let { Move.Result.Castle(it) } ?: Move.Result.Move
            else -> Move.Result.Move
        }

        return Move(result, piece, start, end, promotedPiece = promotedPiece)
    }

    fun convert(move: Move): String =
        move.start.notation + move.end.notation + (move.promotedPiece?.fen?.lowercase() ?: "")

    private fun castlingFor(lan: String): Castling? = when (lan) {
        "e1g1" -> Castling.wK
        "e1c1" -> Castling.wQ
        "e8g8" -> Castling.bK
        "e8c8" -> Castling.bQ
        else -> null
    }
}
