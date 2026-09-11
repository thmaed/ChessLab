package chesskit

/**
 * Traduction Kotlin de `Board.swift` (ChessKit, MIT) : l'état du plateau, la
 * légalité des coups et les fins de partie.
 *
 * **Piège de traduction.** En Swift `&` est prioritaire sur `|` ; en Kotlin
 * `and` et `or` sont des fonctions infixes de MÊME priorité, évaluées de
 * gauche à droite. Toute expression de bitboard reprise telle quelle serait
 * fausse en silence. Elles sont donc re-parenthésées explicitement ici.
 *
 * Le `delegate` déprécié de l'original n'est pas porté : `state` suffit.
 */
class Board(position: Position = Position.standard) {

    var position: Position = position
        private set

    var state: State = State.Active
        private set

    private val positionCounts = HashMap<Position.RepetitionKey, Int>()

    private val set: PieceSet get() = position.pieceSet

    init {
        Attacks.create()
        updateState()
    }

    // MARK: - Public

    fun update(position: Position, resetPositionCounts: Boolean = false) {
        if (resetPositionCounts) positionCounts.clear()
        this.position = position
        updateState()
    }

    fun canMove(pieceAt: Square, to: Square): Boolean {
        val piece = set.get(pieceAt) ?: return false
        return (legalMoves(piece, set) and to.bb) != 0uL
    }

    fun legalMoves(forPieceAt: Square): List<Square> {
        val piece = set.get(forPieceAt) ?: return emptyList()
        return legalMoves(piece, set).squares
    }

    /** `null` si le coup n'est pas légal — dans ce cas rien n'est modifié. */
    fun move(pieceAt: Square, to: Square): Move? {
        if (!canMove(pieceAt, to)) return null
        val piece = set.get(pieceAt) ?: return null
        val start = pieceAt
        val end = to

        // prise en passant
        val ep = position.enPassant
        if (piece.kind == Piece.Kind.pawn && ep != null &&
            ep.pawn.color == piece.color.opposite && end == ep.captureSquare
        ) {
            position.remove(ep.pawn)
            position.move(piece, end)
            return process(Move(Move.Result.Capture(ep.pawn), piece, start, end))
        } else {
            // sans quoi la prise en passant resterait offerte au tour suivant
            position.enPassant = null
            position.enPassantIsPossible = false
        }

        // roque
        if (piece.kind == Piece.Kind.king) {
            for (side in Castling.Side.entries) {
                val castling = Castling(side, piece.color)
                if (canCastle(piece.color, castling, set) && end == castling.kingEnd) {
                    position.castle(castling)
                    return process(Move(Move.Result.Castle(castling), piece, start, end))
                }
            }
        }

        // prises et déplacements
        val endPiece = position.piece(end)
        if (endPiece != null && endPiece.color == piece.color.opposite) {
            val move = disambiguate(Move(Move.Result.Capture(endPiece), piece, start, end), set)
            position.remove(endPiece)
            position.move(piece, end)
            position.resetHalfmoveClock()
            return process(move)
        } else {
            val previousSet = set.copy()
            val updatedPiece = position.move(piece, end) ?: return null
            val move = disambiguate(Move(Move.Result.Move, updatedPiece, start, end), previousSet)

            if (updatedPiece.kind == Piece.Kind.pawn) {
                position.resetHalfmoveClock()
                if (kotlin.math.abs(start.rank.value - end.rank.value) == 2) {
                    position.enPassant = EnPassant(updatedPiece)
                    position.enPassantIsPossible = enPassantIsValid()
                }
            }
            return process(move)
        }
    }

    /** À appeler quand un pion atteint la dernière rangée et que le joueur a choisi. */
    fun completePromotion(of: Move, to: Piece.Kind): Move {
        val promoted = Piece(to, of.piece.color, of.end)
        val updated = of.copy(promotedPiece = promoted)
        position.promote(of.end, to)
        return process(updated)
    }

    // MARK: - Traitement du coup

    private fun process(move: Move): Move {
        val processed = move.copy(checkState = checkState(move.piece.color))
        updateState(processed)
        return processed
    }

    private fun updateState(move: Move? = null) {
        val moveColor = move?.piece?.color ?: position.sideToMove

        if (move != null) {
            if (move.piece.kind == Piece.Kind.pawn) {
                val promoting = (move.end.rank.value == 8 && move.piece.color == Piece.Color.white) ||
                    (move.end.rank.value == 1 && move.piece.color == Piece.Color.black)
                if (promoting && move.promotedPiece == null) {
                    // plus aucun changement d'état tant que la promotion n'est
                    // pas choisie : la position est incomplète
                    state = State.Promotion(move)
                    return
                }
            }
        } else {
            if (position.sideToMove == Piece.Color.black) {
                val pawnSquare = (set.bPawn and BB.RANK_1).squares.firstOrNull()
                if (pawnSquare != null) {
                    state = State.Promotion(
                        Move(
                            Move.Result.Move,
                            Piece(Piece.Kind.pawn, Piece.Color.black, pawnSquare),
                            pawnSquare.up, pawnSquare,
                        )
                    )
                    return
                }
            } else {
                val pawnSquare = (set.wPawn and BB.RANK_8).squares.firstOrNull()
                if (pawnSquare != null) {
                    state = State.Promotion(
                        Move(
                            Move.Result.Move,
                            Piece(Piece.Kind.pawn, Piece.Color.white, pawnSquare),
                            pawnSquare.down, pawnSquare,
                        )
                    )
                    return
                }
            }
        }

        val key = position.repetitionKey
        val count = (positionCounts[key] ?: 0) + 1
        positionCounts[key] = count

        val checkState = checkState(moveColor)

        state = when {
            checkState == Move.CheckState.checkmate -> State.Checkmate(moveColor.opposite)
            checkState == Move.CheckState.stalemate -> State.Draw(State.DrawReason.stalemate)
            position.clock.halfmoves >= Clock.HALF_MOVE_MAXIMUM -> State.Draw(State.DrawReason.fiftyMoves)
            position.hasInsufficientMaterial -> State.Draw(State.DrawReason.insufficientMaterial)
            count == 3 -> State.Draw(State.DrawReason.repetition)
            checkState == Move.CheckState.check -> State.Check(moveColor.opposite)
            else -> State.Active
        }
    }

    private fun checkState(color: Piece.Color): Move.CheckState {
        val opponent = color.opposite
        val moves = set.get(opponent).squares.flatMap { legalMoves(forPieceAt = it) }
        return if (isKingInCheck(opponent, set)) {
            if (moves.isEmpty()) Move.CheckState.checkmate else Move.CheckState.check
        } else {
            if (moves.isEmpty()) Move.CheckState.stalemate else Move.CheckState.none
        }
    }

    /** Deux pièces identiques peuvent-elles aller sur la même case ? */
    private fun disambiguate(move: Move, set: PieceSet): Move {
        val candidates = ((set.get(move.piece.color) and set.get(move.piece.kind)) and
            (set.pawns or set.kings).inv()) and move.start.bb.inv()

        val ambiguous = candidates.squares
            .mapNotNull { set.get(it) }
            .filter { (legalMoves(it, set) and move.end.bb) != 0uL }

        if (ambiguous.isEmpty()) return move

        val fileConflict = ambiguous.any { it.square.file == move.start.file }
        val rankConflict = ambiguous.any { it.square.rank == move.start.rank }

        return move.copy(
            disambiguation = when {
                !fileConflict -> Move.Disambiguation.ByFile(move.start.file)
                !rankConflict -> Move.Disambiguation.ByRank(move.start.rank)
                else -> Move.Disambiguation.BySquare(move.start)
            }
        )
    }

    // MARK: - Légalité

    private fun legalMoves(piece: Piece, set: PieceSet): Bitboard {
        val attacks = when (piece.kind) {
            Piece.Kind.king -> kingMoves(piece.color, piece.square, set)
            Piece.Kind.queen -> Attacks.queen(piece.square, set.all)
            Piece.Kind.rook -> Attacks.rook(piece.square, set.all)
            Piece.Kind.bishop -> Attacks.bishop(piece.square, set.all)
            Piece.Kind.knight -> Attacks.knight(piece.square)
            Piece.Kind.pawn -> pawnAttacks(piece.color, piece.square, set)
        }

        val pseudoLegal = attacks and set.get(piece.color).inv()
        return pseudoLegal.squares.filter { validate(piece, it) }.bb
    }

    /** Le coup laisse-t-il son propre roi hors d'échec ? */
    private fun validate(piece: Piece, to: Square): Boolean {
        val testSet = set.copy()
        testSet.remove(piece)
        testSet.add(piece.copy(square = to))

        val ep = position.enPassant
        if (ep != null && ep.couldBeCaptured(piece) && ep.captureSquare == to) {
            testSet.remove(ep.pawn)
        }

        return !isKingInCheck(piece.color, testSet)
    }

    /** Un pion adverse peut-il RÉELLEMENT prendre en passant ? */
    private fun enPassantIsValid(): Boolean {
        val ep = position.enPassant ?: return false
        for (square in listOf(ep.pawn.square.left, ep.pawn.square.right)) {
            val piece = position.piece(square) ?: continue
            if (ep.couldBeCaptured(piece) && validate(piece, ep.captureSquare)) return true
        }
        return false
    }

    private fun attackers(to: Bitboard, set: PieceSet): Bitboard {
        val square = squareOf(to) ?: return 0uL
        return (Attacks.king(square) and set.kings) or
            (Attacks.rook(square, set.all) and set.lines) or
            (Attacks.bishop(square, set.all) and set.diagonals) or
            (Attacks.knight(square) and set.knights) or
            (pawnCaptures(Piece.Color.white, to) and set.bPawn) or
            (pawnCaptures(Piece.Color.black, to) and set.wPawn)
    }

    private fun isKingInCheck(color: Piece.Color, set: PieceSet): Boolean {
        val us = set.get(color)
        val attacks = attackers(set.kings and us, set)
        return (attacks and us.inv()) != 0uL
    }

    // MARK: - Attaques par type de pièce

    /** Poussées et prise en passant — pour `Board`, la prise en passant n'est pas une « capture ». */
    private fun pawnMoves(color: Piece.Color, square: Square, set: PieceSet): Bitboard {
        val sq = square.bb
        val isOnStartingRank: Boolean
        val movement: (Int) -> Bitboard

        if (color == Piece.Color.white) {
            movement = { n -> sq.north(n) }
            isOnStartingRank = (sq and BB.RANK_1.north()) != 0uL
        } else {
            movement = { n -> sq.south(n) }
            isOnStartingRank = (sq and BB.RANK_8.south()) != 0uL
        }

        val singleMove = movement(1)
        val hasSingleMove = (singleMove and set.all.inv()) != 0uL
        val extraMove = if (isOnStartingRank && hasSingleMove) movement(2) else 0uL

        var enPassantMove: Bitboard = 0uL
        val ep = position.enPassant
        val piece = set.get(square)
        if (ep != null && piece != null && ep.couldBeCaptured(piece)) {
            enPassantMove = ep.captureSquare.bb
        }

        return (singleMove or extraMove or enPassantMove) and set.all.inv()
    }

    private fun pawnCaptures(color: Piece.Color, sq: Bitboard): Bitboard =
        if (color == Piece.Color.white) (sq.northWest() or sq.northEast())
        else (sq.southWest() or sq.southEast())

    private fun pawnAttacks(color: Piece.Color, square: Square, set: PieceSet): Bitboard =
        pawnMoves(color, square, set) or
            (pawnCaptures(color, square.bb) and set.get(color.opposite))

    private fun kingMoves(color: Piece.Color, square: Square, set: PieceSet): Bitboard {
        val castleMoves = Castling.Side.entries
            .map { Castling(it, color) }
            .filter { canCastle(color, it, set) }
            .map { it.kingEnd }

        // l'original additionne les deux bitboards ; ils sont disjoints (ni c1
        // ni g1 ne sont adjacents à e1), donc un « ou » donne le même résultat
        // sans risque de retenue.
        return Attacks.king(square) or castleMoves.bb
    }

    private fun canCastle(color: Piece.Color, castling: Castling, set: PieceSet): Boolean {
        val us = set.get(color)

        val validKing = (us and set.get(Piece.Kind.king)) and castling.kingStart.bb
        val validRook = (us and set.get(Piece.Kind.rook)) and castling.rookStart.bb
        val pathClear = castling.path.all { set.get(it) == null }
        val notThroughCheck = castling.squares.all { (attackers(it.bb, set) and us.inv()) == 0uL }

        return castling in position.legalCastlings &&
            validKing != 0uL &&
            validRook != 0uL &&
            pathClear &&
            notThroughCheck &&
            !isKingInCheck(color, set)
    }

    // MARK: - État

    sealed class State {
        data object Active : State()
        data class Promotion(val move: Move) : State()
        data class Check(val color: Piece.Color) : State()
        data class Checkmate(val color: Piece.Color) : State()
        data class Draw(val reason: DrawReason) : State()

        @Suppress("EnumEntryName")
        enum class DrawReason {
            agreement, fiftyMoves, insufficientMaterial, repetition, stalemate
        }
    }
}
