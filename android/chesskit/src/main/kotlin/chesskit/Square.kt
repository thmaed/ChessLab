package chesskit

/**
 * Traduction Kotlin de `Square.swift` (ChessKit, MIT — chesskit-app/chesskit-swift).
 *
 * Deux écarts assumés par rapport à l'original, tous deux sans effet sur le
 * comportement :
 *
 *  • les deux `switch` de 64 branches (file/rank ↔ case) sont remplacés par de
 *    l'arithmétique sur l'ordinal. L'ordre des cases est celui de ChessKit
 *    (a1…h1, a2…h2, …), donc `ordinal == rawValue` et les deux formulations
 *    coïncident case par case ;
 *  • `Rank` borne sa valeur à la construction, comme l'original, mais doit
 *    définir `equals`/`hashCode` à la main : une `data class` comparerait la
 *    valeur DEMANDÉE et non la valeur bornée, et `Rank(0)` cesserait d'être
 *    égal à `Rank(1)`.
 */
@Suppress("EnumEntryName")
enum class Square {
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8;

    /** La colonne, de a à h. */
    @Suppress("EnumEntryName")
    enum class File(val letter: String) {
        a("a"), b("b"), c("c"), d("d"), e("e"), f("f"), g("g"), h("h");

        val number: Int get() = ordinal + 1

        companion object {
            /** Hors de 1…8, l'original retombe sur `a` ou `h` : on fait pareil. */
            operator fun invoke(number: Int): File = when {
                number < 1 -> a
                number > 8 -> h
                else -> entries[number - 1]
            }

            fun named(letter: String): File? = entries.firstOrNull { it.letter == letter }
        }
    }

    /** La rangée, de 1 à 8. Toute valeur hors bornes est ramenée dedans. */
    class Rank(value: Int) {
        val value: Int = value.coerceIn(range.first, range.last)

        override fun equals(other: Any?): Boolean = other is Rank && other.value == value
        override fun hashCode(): Int = value
        override fun toString(): String = value.toString()

        companion object { val range = 1..8 }
    }

    val file: File get() = File.entries[ordinal % 8]
    val rank: Rank get() = Rank(ordinal / 8 + 1)
    val notation: String get() = file.letter + rank.value

    /** La couleur de la CASE, à ne pas confondre avec celle d'une pièce. */
    enum class Color { light, dark }

    val color: Color
        get() = if ((file.number % 2 == 0 && rank.value % 2 == 0) ||
            (file.number % 2 != 0 && rank.value % 2 != 0)
        ) Color.dark else Color.light

    /** Sur la colonne a, rend la même case — comme l'original. */
    val left: Square get() = Square(File(file.number - 1), rank)
    val right: Square get() = Square(File(file.number + 1), rank)
    val up: Square get() = Square(file, Rank(rank.value + 1))
    val down: Square get() = Square(file, Rank(rank.value - 1))

    companion object {
        operator fun invoke(file: File, rank: Rank): Square =
            entries[(rank.value - 1) * 8 + (file.number - 1)]

        /** Notation invalide : `a1`, comme l'original. */
        operator fun invoke(notation: String): Square {
            val file = File.named(notation.take(1)) ?: File.a
            val rank = Rank(notation.takeLast(1).toIntOrNull() ?: 1)
            return Square(file, rank)
        }
    }
}
