package chesskit

/**
 * Traduction Kotlin de `FENParser.swift` (ChessKit, MIT).
 *
 * Traduction littérale, y compris les tolérances de l'original : un camp au
 * trait illisible vaut « blanc », une prise en passant hors des rangées 3 et 6
 * est ignorée, une pendule illisible repart à 0/1.
 */
object FenParser {

    /** Placement, trait, roques, prise en passant, demi-coups, coups. */
    private const val COMPONENT_COUNT = 6

    fun parse(fen: String): Position? {
        val sections = fen.split(" ").filter { it.isNotEmpty() }
        if (sections.size != COMPONENT_COUNT) return null

        val pieces = mutableListOf<Piece>()
        sections[0].split("/").forEachIndexed { index, rankString ->
            val rank = Square.Rank(Square.Rank.range.last - index)
            var fileNumber = 0
            for (c in rankString) {
                val digit = c.digitToIntOrNull()
                if (digit != null && digit in Square.Rank.range) {
                    fileNumber += digit
                } else {
                    fileNumber += 1
                    val square = Square(Square.File(fileNumber), rank)
                    Piece.fromFen(c.toString(), square)?.let { pieces += it }
                }
            }
        }

        val sideToMove = Piece.Color.named(sections[1]) ?: Piece.Color.white

        val ability = sections[2]
        val legalCastlings = buildList {
            if (ability.contains("k")) add(Castling.bK)
            if (ability.contains("K")) add(Castling.wK)
            if (ability.contains("q")) add(Castling.bQ)
            if (ability.contains("Q")) add(Castling.wQ)
        }

        var enPassant: EnPassant? = null
        val ep = sections[3]
        if (ep != "-" && ep.length == 2) {
            val epFile = Square.File.named(ep.substring(0, 1))
            val epRank = ep.substring(1, 2).toIntOrNull()
            if (epFile != null && epRank == 3) {
                enPassant = EnPassant(
                    Piece(Piece.Kind.pawn, Piece.Color.white, Square(epFile, Square.Rank(epRank + 1)))
                )
            } else if (epFile != null && epRank == 6) {
                enPassant = EnPassant(
                    Piece(Piece.Kind.pawn, Piece.Color.black, Square(epFile, Square.Rank(epRank - 1)))
                )
            }
        }

        val halfmoves = sections[4].toIntOrNull()
        val fullmoves = sections[5].toIntOrNull()
        val clock = if (halfmoves != null && fullmoves != null) Clock(halfmoves, fullmoves) else Clock()

        return Position(pieces, sideToMove, LegalCastlings(legalCastlings), enPassant, clock)
    }

    fun convert(position: Position): String {
        val fen = StringBuilder()

        for (r in Square.Rank.range.reversed()) {
            val rank = Square.Rank(r)
            var empty = 0
            for (file in Square.File.entries) {
                val piece = position.piece(Square(file, rank))
                if (piece != null) {
                    if (empty > 0) { fen.append(empty); empty = 0 }
                    fen.append(piece.fen)
                } else {
                    empty += 1
                }
            }
            if (empty > 0) fen.append(empty)
            fen.append("/")
        }
        fen.setLength(fen.length - 1)

        fen.append(" ").append(position.sideToMove.raw)
        fen.append(" ").append(position.legalCastlings.fen)
        fen.append(" ").append(position.enPassant?.captureSquare?.notation ?: "-")
        fen.append(" ").append(position.clock.halfmoves).append(" ").append(position.clock.fullmoves)

        return fen.toString()
    }
}
