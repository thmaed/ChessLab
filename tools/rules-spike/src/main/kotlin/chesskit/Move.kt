package chesskit

/**
 * Traduction Kotlin de `Move.swift` (ChessKit, MIT).
 *
 * `san` et `lan` ne sont pas encore là : ils demandent `SANParser` et
 * `EngineLANParser`, qui restent à porter.
 */
data class Move(
    val result: Result,
    val piece: Piece,
    val start: Square,
    val end: Square,
    var promotedPiece: Piece? = null,
    var disambiguation: Disambiguation? = null,
    var checkState: CheckState = CheckState.none,
    var assessment: Assessment = Assessment.null_,
    var comment: String = "",
) {
    /** La notation abrégée, celle qui s'affiche. */
    val san: String get() = SanParser.convert(this)

    /** La notation longue des moteurs UCI. */
    val lan: String get() = EngineLanParser.convert(this)

    sealed class Result {
        data object Move : Result()
        data class Capture(val piece: Piece) : Result()
        data class Castle(val castling: Castling) : Result()
    }

    @Suppress("EnumEntryName")
    enum class CheckState(val notation: String) {
        none(""), check("+"), checkmate("#"), stalemate("")
    }

    sealed class Disambiguation {
        data class ByFile(val file: Square.File) : Disambiguation()
        data class ByRank(val rank: Square.Rank) : Disambiguation()
        data class BySquare(val square: Square) : Disambiguation()
    }

    /** La valeur brute est ce qui s'écrit dans un PGN. */
    enum class Assessment(val raw: String, val notation: String) {
        null_("$0", ""), good("$1", "!"), mistake("$2", "?"), brilliant("$3", "!!"),
        blunder("$4", "??"), interesting("$5", "!?"), dubious("$6", "?!"),
        forced("$7", "□"), singular("$8", ""), worst("$9", "")
    }
}
