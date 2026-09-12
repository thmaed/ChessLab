package com.chesslab.variants

import androidx.annotation.StringRes
import com.chesslab.R
import kotlin.random.Random

/**
 * Une variante jouable, arbitrée par Fairy-Stockfish.
 *
 * [uci] est le nom que le moteur attend pour `UCI_Variant`. [chess960] met
 * aussi `UCI_Chess960`, qui change les règles du roque.
 */
data class Variant(
    val id: String,
    val uci: String,
    /** Le nom et la description sont des ressources : elles se traduisent. */
    @StringRes val titleRes: Int,
    @StringRes val blurbRes: Int,
    /** L'accroche COURTE de la tuile : trois mots, pas un paragraphe. */
    @StringRes val shortRes: Int,
    val chess960: Boolean = false,
)

object VariantCatalog {

    val all = listOf(
        Variant(
            "chess960", "chess", R.string.variant_chess960, R.string.variant_chess960_blurb,
            R.string.variant_chess960_short,
            chess960 = true,
        ),
        Variant(
            "kingofthehill", "kingofthehill", R.string.variant_koth, R.string.variant_koth_blurb,
            R.string.variant_koth_short,
        ),
        Variant(
            "3check", "3check", R.string.variant_3check, R.string.variant_3check_blurb,
            R.string.variant_3check_short,
        ),
        Variant(
            "horde", "horde", R.string.variant_horde, R.string.variant_horde_blurb,
            R.string.variant_horde_short,
        ),
        Variant(
            "racingkings", "racingkings", R.string.variant_racing, R.string.variant_racing_blurb,
            R.string.variant_racing_short,
        ),
        Variant(
            "atomic", "atomic", R.string.variant_atomic, R.string.variant_atomic_blurb,
            R.string.variant_atomic_short,
        ),
        // Crazyhouse attend : le moteur la connaît, mais elle demande de
        // PARACHUTER les pièces prises, donc une réserve et un geste de pose.
        // Sans eux, le moteur jouerait des parachutages que l'utilisateur ne
        // pourrait pas rendre — une variante à moitié jouable est pire que
        // pas de variante.
        Variant(
            "antichess", "antichess", R.string.variant_antichess, R.string.variant_antichess_blurb,
            R.string.variant_antichess_short,
        ),
    )

    fun byId(id: String): Variant? = all.firstOrNull { it.id == id }

    /**
     * Une position de départ Chess960, tirée au sort.
     *
     * Les contraintes sont celles du jeu : les deux fous sur des cases de
     * couleurs opposées, et le roi entre les deux tours. Les droits de roque
     * sont écrits en COLONNES (« HFhf ») — la forme Shredder, seule non
     * ambiguë quand les tours ne sont plus en a1 et h1.
     */
    fun randomChess960Fen(random: Random = Random.Default): String {
        val row = CharArray(8) { ' ' }

        // un fou sur case claire, un sur case sombre
        row[random.nextInt(4) * 2] = 'b'
        row[random.nextInt(4) * 2 + 1] = 'b'

        fun placeInEmpty(index: Int, piece: Char) {
            var seen = -1
            for (i in row.indices) {
                if (row[i] == ' ') {
                    seen++
                    if (seen == index) { row[i] = piece; return }
                }
            }
        }

        placeInEmpty(random.nextInt(6), 'q')
        placeInEmpty(random.nextInt(5), 'n')
        placeInEmpty(random.nextInt(4), 'n')

        // le roi entre les deux tours : les trois cases restantes, dans l'ordre
        val rest = row.indices.filter { row[it] == ' ' }
        row[rest[0]] = 'r'; row[rest[1]] = 'k'; row[rest[2]] = 'r'

        val black = String(row)
        val white = black.uppercase()
        val files = "abcdefgh"
        val castling = "${files[rest[2]].uppercaseChar()}${files[rest[0]].uppercaseChar()}" +
            "${files[rest[2]]}${files[rest[0]]}"

        return "$black/pppppppp/8/8/8/8/PPPPPPPP/$white w $castling - 0 1"
    }
}
