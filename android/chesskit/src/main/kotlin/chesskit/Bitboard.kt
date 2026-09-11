package chesskit

/**
 * Traduction Kotlin de `Bitboard.swift` et `Square+BB.swift` (ChessKit, MIT).
 *
 * `UInt64` côté Swift devient `ULong`. Les opérations qui débordent (`&*`,
 * `&-`) sont la norme en Kotlin sur les types non signés : pas de conversion
 * à prévoir. `trailingZeroBitCount` et `nonzeroBitCount` passent par `Long`,
 * dont le motif binaire est le même.
 */
typealias Bitboard = ULong

object BB {
    const val A_FILE: Bitboard = 0x0101010101010101uL
    val H_FILE: Bitboard = A_FILE shl 7
    const val RANK_1: Bitboard = 0xFFuL
    val RANK_8: Bitboard = RANK_1 shl (8 * 7)
    const val DARK: Bitboard = 0xAA55AA55AA55AA55uL
    val LIGHT: Bitboard = DARK.inv()
}

fun Bitboard.east(n: Int = 1): Bitboard = (this and BB.H_FILE.inv()) shl n
fun Bitboard.west(n: Int = 1): Bitboard = (this and BB.A_FILE.inv()) shr n
fun Bitboard.north(n: Int = 1): Bitboard = this shl (8 * n)
fun Bitboard.south(n: Int = 1): Bitboard = this shr (8 * n)
fun Bitboard.northEast(n: Int = 1): Bitboard = (this and BB.H_FILE.inv()) shl (9 * n)
fun Bitboard.northWest(n: Int = 1): Bitboard = (this and BB.A_FILE.inv()) shl (7 * n)
fun Bitboard.southEast(n: Int = 1): Bitboard = (this and BB.H_FILE.inv()) shr (7 * n)
fun Bitboard.southWest(n: Int = 1): Bitboard = (this and BB.A_FILE.inv()) shr (9 * n)

fun Bitboard.trailingZeros(): Int = this.toLong().countTrailingZeroBits()
fun Bitboard.oneBits(): Int = this.toLong().countOneBits()

/** Les cases occupées, de la plus basse à la plus haute. */
val Bitboard.squares: List<Square>
    get() {
        val out = ArrayList<Square>(oneBits())
        var bb = this
        while (bb != 0uL) {
            out += Square.entries[bb.trailingZeros()]
            bb = bb and (bb - 1uL)
        }
        return out
    }

val Square.bb: Bitboard get() = 1uL shl ordinal
val Square.File.bb: Bitboard get() = BB.A_FILE.east(number - 1)
val Square.Rank.bb: Bitboard get() = BB.RANK_1.north(value - 1)
val List<Square>.bb: Bitboard get() = fold(0uL) { acc, s -> acc or s.bb }

/** `null` si le bitboard est vide — comme l'initialiseur faillible de l'original. */
fun squareOf(bb: Bitboard): Square? = Square.entries.getOrNull(bb.trailingZeros())
