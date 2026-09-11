package com.chesslab.variants

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
    val title: String,
    val blurb: String,
    val chess960: Boolean = false,
)

object VariantCatalog {

    val all = listOf(
        Variant(
            "chess960", "chess", "Chess960",
            "Les pièces du fond sont mélangées, identiquement des deux côtés. " +
                "La théorie d'ouverture ne sert plus à rien : il faut jouer.",
            chess960 = true,
        ),
        Variant(
            "kingofthehill", "kingofthehill", "Roi de la colline",
            "Amener son roi sur l'une des quatre cases centrales gagne la partie, " +
                "immédiatement. Le mat reste possible.",
        ),
        Variant(
            "3check", "3check", "Trois échecs",
            "Donner échec trois fois gagne la partie. Le mat compte toujours.",
        ),
        Variant(
            "horde", "horde", "Horde",
            "Les Blancs n'ont que des pions — trente-six — et doivent mater. " +
                "Les Noirs gagnent en les capturant tous.",
        ),
        Variant(
            "racingkings", "racingkings", "Course des rois",
            "Le premier roi arrivé sur la huitième rangée gagne. " +
                "Aucun échec n'est autorisé, dans aucun sens.",
        ),
        Variant(
            "atomic", "atomic", "Atomique",
            "Toute capture fait exploser la case d'arrivée et ses voisines, " +
                "pions exceptés. La partie s'arrête dès qu'un roi explose.",
        ),
        Variant(
            "antichess", "antichess", "Antichecs",
            "La capture est OBLIGATOIRE quand elle est possible, et le but est " +
                "de perdre toutes ses pièces. Le roi n'est plus sacré.",
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
