package chesskit

/** Traduction Kotlin de `Piece.swift` (ChessKit, MIT). */
data class Piece(val kind: Kind, val color: Color, val square: Square) {

    @Suppress("EnumEntryName")
    enum class Color(val raw: String) {
        black("b"), white("w");

        val opposite: Color get() = if (this == black) white else black

        companion object {
            fun named(raw: String): Color? = entries.firstOrNull { it.raw == raw }
        }
    }

    @Suppress("EnumEntryName")
    enum class Kind(val notation: String) {
        pawn(""), knight("N"), bishop("B"), rook("R"), queen("Q"), king("K")
    }

    /** La notation FEN de la pièce — ne dit rien de sa case. */
    val fen: String
        get() {
            val letter = when (kind) {
                Kind.pawn -> "p"; Kind.bishop -> "b"; Kind.knight -> "n"
                Kind.rook -> "r"; Kind.queen -> "q"; Kind.king -> "k"
            }
            return if (color == Color.white) letter.uppercase() else letter
        }

    companion object {
        /** `null` si la lettre n'est pas une pièce FEN valide. */
        fun fromFen(fen: String, square: Square): Piece? {
            val kind = when (fen.lowercase()) {
                "p" -> Kind.pawn; "b" -> Kind.bishop; "n" -> Kind.knight
                "r" -> Kind.rook; "q" -> Kind.queen; "k" -> Kind.king
                else -> return null
            }
            if (fen.length != 1) return null
            val color = if (fen[0].isUpperCase()) Color.white else Color.black
            return Piece(kind, color, square)
        }
    }
}
