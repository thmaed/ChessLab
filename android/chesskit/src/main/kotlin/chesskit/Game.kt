package chesskit

/**
 * Traduction Kotlin de `Game.swift` (ChessKit, MIT) : une partie complète —
 * l'arbre des coups, la position à chaque index, et les tags PGN.
 *
 * Comme l'original, `make` ne vérifie PAS la légalité : c'est à l'appelant de
 * passer par [Board]. Cette classe applique le coup qu'on lui donne.
 */
class Game(startingPosition: Position = Position.standard, tags: Tags = Tags()) {

    /**
     * Les tags PGN. L'original les déclare avec un `@propertyWrapper` et les
     * énumère par réflexion ; ici la liste est explicite — moins magique, et
     * l'ordre d'écriture est celui du « Seven Tag Roster » puis le reste.
     */
    class Tags {
        var event: String = ""
        var site: String = ""
        var date: String = ""
        var round: String = ""
        var white: String = ""
        var black: String = ""
        var result: String = ""
        var annotator: String = ""
        var plyCount: String = ""
        var timeControl: String = ""
        var time: String = ""
        var termination: String = ""
        var mode: String = ""
        var fen: String = ""
        var setUp: String = ""

        /** Tags non standard, conservés tels quels. */
        var other: MutableMap<String, String> = LinkedHashMap()

        /** Les tags nommés, dans l'ordre d'écriture du PGN. */
        val named: List<Pair<String, String>>
            get() = listOf(
                "Event" to event, "Site" to site, "Date" to date, "Round" to round,
                "White" to white, "Black" to black, "Result" to result,
                "Annotator" to annotator, "PlyCount" to plyCount,
                "TimeControl" to timeControl, "Time" to time,
                "Termination" to termination, "Mode" to mode,
                "FEN" to fen, "SetUp" to setUp,
            )

        /** Les sept tags obligatoires d'un PGN d'archive sont-ils renseignés ? */
        val isValid: Boolean
            get() = listOf(event, site, date, round, white, black, result).all { it.isNotEmpty() }

        /** Renseigne un tag par son nom PGN ; les inconnus vont dans [other]. */
        fun set(name: String, value: String) {
            when (name) {
                "Event" -> event = value
                "Site" -> site = value
                "Date" -> date = value
                "Round" -> round = value
                "White" -> white = value
                "Black" -> black = value
                "Result" -> result = value
                "Annotator" -> annotator = value
                "PlyCount" -> plyCount = value
                "TimeControl" -> timeControl = value
                "Time" -> time = value
                "Termination" -> termination = value
                "Mode" -> mode = value
                "FEN" -> fen = value
                "SetUp" -> setUp = value
                else -> other[name] = value
            }
        }
    }

    val moves = MoveTree()

    /** L'index de la position de départ : `minimum` si les blancs ont le trait. */
    val startingIndex: MoveTree.Index =
        if (startingPosition.sideToMove == Piece.Color.white) MoveTree.Index.minimum
        else MoveTree.Index.minimum.next

    private val _positions = LinkedHashMap<MoveTree.Index, Position>()

    var tags: Tags = tags

    init {
        _positions[startingIndex] = startingPosition
        moves.minimumIndex = startingIndex
    }

    val positions: Map<MoveTree.Index, Position> get() = _positions

    val startingPosition: Position? get() = _positions[startingIndex]

    fun position(index: MoveTree.Index): Position? = _positions[index]

    /**
     * Joue `move` depuis `index`. Si le coup EXISTE déjà comme suite de
     * `index`, il n'est pas rejoué — sans quoi on créerait une variante
     * identique à la ligne principale.
     */
    fun make(move: Move, from: MoveTree.Index): MoveTree.Index {
        moves.nextIndex(containing = move, forIndex = from)?.let { return it }

        val newIndex = moves.add(move, parentIndex = from)
        val current = _positions[from] ?: return from
        val next = current.copy()

        when (val result = move.result) {
            is Move.Result.Move -> {
                next.move(pieceAt = move.start, to = move.end)
                if (move.piece.kind == Piece.Kind.pawn) next.resetHalfmoveClock()
            }
            is Move.Result.Capture -> {
                next.remove(result.piece)
                next.move(pieceAt = move.start, to = move.end)
                next.resetHalfmoveClock()
            }
            is Move.Result.Castle -> next.castle(result.castling)
        }

        move.promotedPiece?.let { next.promote(pieceAt = move.end, to = it.kind) }

        // CORRIGÉ : l'original n'arme JAMAIS la prise en passant après une
        // poussée de deux cases. La position rejouée ne l'offrait donc pas, et
        // relire un PGN contenant « exd6 » échouait sur un coup illégal — le
        // défaut que `ChessLab/Analysis/PGNLoader.swift` contourne côté iOS en
        // reconstruisant la partie, au prix des variantes et des commentaires.
        next.enPassant = null
        next.enPassantIsPossible = false
        if (move.piece.kind == Piece.Kind.pawn &&
            kotlin.math.abs(move.start.rank.value - move.end.rank.value) == 2
        ) {
            next.piece(move.end)?.let { next.enPassant = EnPassant(it) }
        }

        _positions[newIndex] = next
        return newIndex
    }

    /** Joue un coup donné en notation abrégée. */
    fun make(san: String, from: MoveTree.Index): MoveTree.Index {
        val position = _positions[from] ?: return from
        val move = SanParser.parse(san, position) ?: return from
        return make(move, from)
    }

    /** Joue une suite de coups en notation abrégée. */
    fun make(sans: List<String>, from: MoveTree.Index): MoveTree.Index {
        var index = from
        for (san in sans) index = make(san, index)
        return index
    }

    fun annotate(moveAt: MoveTree.Index, assessment: Move.Assessment = Move.Assessment.null_, comment: String = "") {
        moves.annotate(moveAt = moveAt, assessment = assessment, comment = comment)
    }

    fun annotate(positionAt: MoveTree.Index, assessment: PositionAssessment) {
        moves.annotate(positionAt = positionAt, assessment = assessment)
        _positions[positionAt]?.assessment = assessment
    }

    val pgn: String get() = PgnWriter.convert(this)

    override fun toString(): String = pgn
}
