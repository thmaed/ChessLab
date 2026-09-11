package chesskit

/**
 * Traduction Kotlin de `SANParser.swift` et `SANParser+Regex.swift`
 * (ChessKit, MIT) : la notation algébrique abrégée, celle qui s'affiche et
 * qui s'écrit dans un PGN.
 */
object SanParser {

    private object Pattern {
        // CORRIGÉ : l'original oublie `[+#]?` sur la branche du roque, si bien
        // que « O-O+ » était jugé invalide AVANT même d'être reconnu comme un
        // roque — alors que le motif du roque, lui, l'accepte.
        val full = Regex("""^([Oo0]-[Oo0](-[Oo0])?[+#]?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](=[QRBN])?[+#]?)$""")
        val pawnFile = Regex("""^[a-h]""")
        val pieceKind = Regex("""^[KQRBN]""")
        val shortCastle = Regex("""^[Oo0]-[Oo0]\+?#?$""")
        val longCastle = Regex("""^[Oo0]-[Oo0]-[Oo0]\+?#?$""")
        // Le préfixe est entièrement optionnel : sur « Nf3 » il trouve une
        // correspondance VIDE, ce qui vaut « pas de désambiguïsation ».
        // CORRIGÉ : l'original n'autorise pas le `x` entre l'indication et la
        // case d'arrivée, si bien que « R4xf3 » perdait son « 4 » et se
        // relisait sur la mauvaise tour.
        val disambiguation = Regex("""[a-h]?[1-8]?(?=x?([a-h][1-8][#+]?)$)""")
        val rank = Regex("""^[1-8]$""")
        val file = Regex("""^[a-h]$""")
        val square = Regex("""^[a-h][1-8]$""")
        val promotion = Regex("""=[QRBN]""")
        val targetSquare = Regex("""([a-h][1-8])(?!([a-h][1-8]))""")
    }

    /**
     * `null` si la notation est invalide OU si le coup qu'elle décrit n'est
     * pas jouable dans `position`. Le trait de `position` doit être correct.
     */
    fun parse(move: String, position: Position): Move? {
        if (!Pattern.full.containsMatchIn(move)) return null

        val color = position.sideToMove
        val checkState = when {
            move.contains("#") -> Move.CheckState.checkmate
            move.contains("+") -> Move.CheckState.check
            else -> Move.CheckState.none
        }

        // roque
        val castling = when {
            Pattern.shortCastle.containsMatchIn(move) -> Castling(Castling.Side.king, color)
            Pattern.longCastle.containsMatchIn(move) -> Castling(Castling.Side.queen, color)
            else -> null
        }
        if (castling != null) {
            return Move(
                Move.Result.Castle(castling),
                Piece(Piece.Kind.king, color, castling.kingStart),
                castling.kingStart, castling.kingEnd,
                checkState = checkState,
            )
        }

        val end = targetSquare(move) ?: return null
        val board = Board(position.copy())

        // pions
        val fileMatch = Pattern.pawnFile.find(move)
        if (fileMatch != null) {
            val startingFile = Square.File.named(fileMatch.value) ?: return null

            val pawn = position.pieces.firstOrNull {
                it.kind == Piece.Kind.pawn && it.color == color && it.square.file == startingFile &&
                    board.canMove(pieceAt = it.square, to = end)
            } ?: return null

            val start = pawn.square
            val moved = pawn.copy(square = end)

            val result: Move.Result? = if (move.contains("x")) {
                val captured = position.piece(end)
                val ep = position.enPassant
                when {
                    captured != null -> Move.Result.Capture(captured)
                    ep != null && ep.captureSquare == end -> Move.Result.Capture(ep.pawn)
                    else -> null
                }
            } else {
                Move.Result.Move
            }

            return result?.let {
                Move(it, moved, start, end, checkState = checkState).apply {
                    promotionKind(move)?.let { kind -> promotedPiece = Piece(kind, color, end) }
                }
            }
        }

        // autres pièces
        val kindMatch = Pattern.pieceKind.find(move) ?: return null
        val kind = Piece.Kind.entries.firstOrNull { it.notation == kindMatch.value } ?: return null
        val disambiguation = disambiguation(move)

        val piece = position.pieces.firstOrNull {
            it.kind == kind && it.color == color &&
                board.canMove(pieceAt = it.square, to = end) &&
                when (disambiguation) {
                    is Move.Disambiguation.ByFile -> it.square.file == disambiguation.file
                    is Move.Disambiguation.ByRank -> it.square.rank == disambiguation.rank
                    is Move.Disambiguation.BySquare -> it.square == disambiguation.square
                    null -> true
                }
        } ?: return null

        val start = piece.square
        val moved = piece.copy(square = end)
        val captured = if (move.contains("x")) position.piece(end) else null
        val result = if (captured != null) Move.Result.Capture(captured) else Move.Result.Move

        return Move(result, moved, start, end, checkState = checkState, disambiguation = disambiguation)
    }

    fun convert(move: Move): String {
        val castle = move.result as? Move.Result.Castle
        if (castle != null) return castle.castling.side.notation + move.checkState.notation

        val isCapture = move.result is Move.Result.Capture

        val pieceNotation =
            if (move.piece.kind == Piece.Kind.pawn && isCapture) move.start.file.letter
            else move.piece.kind.notation

        val disambiguationNotation = when (val d = move.disambiguation) {
            is Move.Disambiguation.ByFile -> d.file.letter
            is Move.Disambiguation.ByRank -> "${d.rank.value}"
            is Move.Disambiguation.BySquare -> d.square.notation
            null -> ""
        }

        val captureNotation = if (isCapture) "x" else ""
        val promotionNotation = move.promotedPiece?.let { "=${it.kind.notation}" } ?: ""

        return pieceNotation + disambiguationNotation + captureNotation +
            move.end.notation + promotionNotation + move.checkState.notation
    }

    private fun targetSquare(san: String): Square? =
        Pattern.targetSquare.find(san)?.let { Square(it.value) }

    private fun promotionKind(san: String): Piece.Kind? {
        val raw = Pattern.promotion.find(san)?.value?.removePrefix("=") ?: return null
        return Piece.Kind.entries.firstOrNull { it.notation == raw }
    }

    private fun disambiguation(san: String): Move.Disambiguation? {
        val value = Pattern.disambiguation.find(san)?.value ?: return null
        return when {
            Pattern.rank.matches(value) -> Move.Disambiguation.ByRank(Square.Rank(value.toInt()))
            Pattern.file.matches(value) -> Square.File.named(value)?.let { Move.Disambiguation.ByFile(it) }
            Pattern.square.matches(value) -> Move.Disambiguation.BySquare(Square(value))
            else -> null
        }
    }
}
