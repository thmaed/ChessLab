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
    /**
     * La variante porte des MURS : des cases hors du jeu, que le moteur
     * connaît comme des pièces et que `chesskit` ne doit jamais voir.
     */
    val hasWalls: Boolean = false,
    /**
     * Les murs se déplacent à chaque demi-coup. La position se RÉÉCRIT alors
     * entre les coups : le tirage ne figure dans aucun coup, donc rejouer
     * « position de départ + coups » ne le reproduirait pas.
     */
    val wallsMove: Boolean = false,
    /**
     * Les règles sont calculées DANS L'APP : aucun moteur ne connaît la
     * variante, et rien dans Fairy-Stockfish ne permet de la décrire.
     */
    val appRuled: Boolean = false,
    /**
     * Deux humains peuvent y jouer sur le même appareil. Le Duck Chess s'y
     * prête — il n'y a pas d'information cachée —, les variantes arbitrées
     * par le moteur aussi ; le Coup Volé non : son jeton se dépense en
     * secret.
     */
    val supportsTwoPlayers: Boolean = true,
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
        // La seule variante du hub où l'on POSE des pièces : elle a sa
        // réserve, lue dans la FEN, et son geste de pose.
        Variant(
            "crazyhouse", "crazyhouse", R.string.variant_crazyhouse,
            R.string.variant_crazyhouse_blurb, R.string.variant_crazyhouse_short,
        ),
        Variant(
            "antichess", "antichess", R.string.variant_antichess, R.string.variant_antichess_blurb,
            R.string.variant_antichess_short,
        ),
        // Les deux Barricades ne sont pas des variantes du moteur : c'est
        // `BarricadesConfiguration` qui les lui enseigne au démarrage.
        Variant(
            BarricadesConfiguration.variantId, BarricadesConfiguration.variantId,
            R.string.variant_barricades, R.string.variant_barricades_blurb,
            R.string.variant_barricades_short, hasWalls = true,
        ),
        Variant(
            BarricadesConfiguration.randomVariantId, BarricadesConfiguration.randomVariantId,
            R.string.variant_random_barricades, R.string.variant_random_barricades_blurb,
            R.string.variant_random_barricades_short, hasWalls = true, wallsMove = true,
        ),
        // Le Duck Chess n'est pas arbitré par le moteur : un coup y est DEUX
        // actions, ce que le protocole UCI ne sait pas exprimer.
        Variant(
            "duck", "chess", R.string.variant_duck, R.string.variant_duck_blurb,
            R.string.variant_duck_short, appRuled = true,
        ),
        // Le Coup Volé non plus : le tour double n'existe dans aucun moteur.
        // `chesskit` arbitre chaque coup, l'app tient le tour.
        Variant(
            "stolenmove", "chess", R.string.variant_stolen, R.string.variant_stolen_blurb,
            // Le jeton se dépense en SECRET : à deux sur le même écran, il n'y
            // aurait plus de surprise, et c'est toute la variante.
            R.string.variant_stolen_short, appRuled = true, supportsTwoPlayers = false,
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
