package chesskit

/**
 * Traduction Kotlin de `Position.swift` (ChessKit, MIT).
 *
 * L'original est un `struct` à méthodes `mutating`, donc à sémantique de
 * valeur. Ici c'est une classe mutable : `Board` en détient une et la modifie
 * en place, ce qui correspond à l'usage. Les endroits où ChessKit s'appuyait
 * sur une COPIE implicite (le jeu d'essai de `Board.validate`) copient
 * explicitement le `PieceSet`, qui est une `data class` de `ULong`.
 */
class Position(
    pieces: List<Piece>,
    sideToMove: Piece.Color = Piece.Color.white,
    legalCastlings: LegalCastlings = LegalCastlings(),
    enPassant: EnPassant? = null,
    clock: Clock = Clock(),
) {
    var pieceSet: PieceSet = PieceSet(pieces)
        private set

    var sideToMove: Piece.Color = sideToMove
        private set

    var legalCastlings: LegalCastlings = legalCastlings
    var enPassant: EnPassant? = enPassant
    var enPassantIsPossible: Boolean = enPassant != null
    var clock: Clock = clock

    /** L'annotation de la position, écrite dans le PGN. */
    var assessment: PositionAssessment = PositionAssessment.null_

    val pieces: List<Piece> get() = pieceSet.pieces

    fun piece(at: Square): Piece? = pieceSet.get(at)

    val fen: String get() = FenParser.convert(this)

    /**
     * Déplace `piece` vers `end`.
     *
     * Ne PAS utiliser pour un roque — voir [castle], qui bouge aussi la tour.
     */
    fun move(piece: Piece, to: Square, updateClockAndSideToMove: Boolean = true): Piece? {
        if (pieceSet.get(piece.square) == null) return null

        legalCastlings = legalCastlings.invalidating(piece)
        pieceSet.move(piece, to)

        if (updateClockAndSideToMove) {
            clock.halfmoves += 1
            if (piece.color == Piece.Color.black) clock.fullmoves += 1
            sideToMove = sideToMove.opposite
        }

        return pieceSet.get(to)
    }

    fun move(pieceAt: Square, to: Square, updateClockAndSideToMove: Boolean = true): Piece? {
        val piece = pieceSet.get(pieceAt) ?: return null
        return move(piece, to, updateClockAndSideToMove)
    }

    /** La tour ne bouge que si le coup du roi a abouti. */
    fun castle(castling: Castling): Piece? {
        val kingMove = move(castling.kingStart, castling.kingEnd)
        if (kingMove != null) {
            move(castling.rookStart, castling.rookEnd, updateClockAndSideToMove = false)
        }
        return kingMove
    }

    fun remove(piece: Piece) = pieceSet.remove(piece)

    fun promote(pieceAt: Square, to: Piece.Kind) {
        val piece = pieceSet.get(pieceAt) ?: return
        pieceSet.replace(to, piece)
    }

    fun resetHalfmoveClock() { clock = clock.copy(halfmoves = 0) }

    /** Matériel insuffisant pour mater : roi seul, roi + fou, roi + cavalier… */
    val hasInsufficientMaterial: Boolean
        get() {
            val set = pieceSet
            if ((set.pawns or set.rooks or set.queens) != 0uL) return false
            if (set.all.oneBits() <= 3) return true
            val allLight = set.bishops and BB.DARK == 0uL
            val allDark = set.bishops and BB.LIGHT == 0uL
            return set.knights == 0uL && (allLight || allDark)
        }

    /**
     * Une copie indépendante. L'original est un `struct` : Swift la fait
     * gratuitement à chaque affectation. Ici elle est explicite, et le
     * `PieceSet` comme la pendule sont bien dupliqués.
     */
    fun copy(): Position {
        val other = Position(emptyList(), sideToMove, legalCastlings, enPassant, clock.copy())
        other.pieceSet = pieceSet.copy()
        other.enPassantIsPossible = enPassantIsPossible
        return other
    }

    /**
     * La clé de répétition : ce qui doit coïncider pour que deux positions
     * comptent comme identiques — les pièces, le trait, les roques encore
     * permis et la possibilité d'une prise en passant. La pendule en est
     * exclue, à dessein.
     *
     * Écart assumé et volontaire : l'original compte les répétitions dans un
     * dictionnaire indexé par `hashValue`, donc deux positions différentes qui
     * entrent en collision de hachage y comptent comme une répétition. On
     * indexe ici la clé elle-même, ce qui supprime ce faux nul sans rien
     * changer d'autre.
     */
    data class RepetitionKey(
        val pieces: PieceSet,
        val sideToMove: Piece.Color,
        val legalCastlings: LegalCastlings,
        val enPassantIsPossible: Boolean,
    )

    val repetitionKey: RepetitionKey
        get() = RepetitionKey(pieceSet.copy(), sideToMove, legalCastlings, enPassantIsPossible)

    companion object {
        fun fromFen(fen: String): Position? = FenParser.parse(fen)

        val standard: Position
            get() = fromFen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")!!
    }
}
