package com.chesslab.variants

import androidx.annotation.StringRes
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import com.chesslab.R

/**
 * Pourquoi une partie de variante s'est arrêtée, et qui l'a gagnée. Pendant de
 * `EngineLegalityVariant.outcome` et de `FairyVariant.specialOutcome`.
 *
 * Android s'en remettait au moteur pour TOUT : plus aucun coup légal, donc
 * « Partie terminée ». C'est exact et muet — on ne savait ni qui avait gagné
 * ni pourquoi, alors que l'iPhone affiche « Vous avez gagné (roi au centre) ».
 * Le moteur reste l'arbitre de la LÉGALITÉ ; ce fichier ne fait que LIRE la
 * position qu'il rend pour nommer la fin.
 *
 * L'ordre des tests n'est pas indifférent : l'explosion d'un roi termine la
 * partie même s'il reste des coups, et la nulle par matériel se constate avant
 * de compter les coups restants.
 */
object VariantOutcome {

    /** [winner] nul = partie nulle. */
    data class Result(val winner: Piece.Color?, @StringRes val reasonRes: Int)

    /** Les quatre cases qui gagnent au Roi de la colline. */
    private val hillSquares = setOf(Square.d4, Square.e4, Square.d5, Square.e5)

    /**
     * @param variantId la variante, telle que le catalogue la nomme.
     * @param fen la position APRÈS le coup, telle que le moteur l'écrit.
     * @param legalMoves les coups légaux du camp au trait, du moteur.
     * @param inCheck le camp au trait est-il en échec, du moteur.
     * @param pocketIsEmpty les deux réserves du Crazyhouse sont-elles vides ?
     */
    fun detect(
        variantId: String,
        fen: String,
        legalMoves: List<String>,
        inCheck: Boolean,
        pocketIsEmpty: Boolean = true,
    ): Result? {
        val position = Position.fromFen(VariantFen.forChessKit(fen)) ?: return null
        val next = position.sideToMove
        val kings = position.pieces.filter { it.kind == Piece.Kind.king }

        // L'explosion d'un roi termine la partie qu'il reste ou non des coups
        // légaux ensuite — vérifiée EN PREMIER.
        if (variantId == "atomic") {
            if (kings.none { it.color == Piece.Color.white }) {
                return Result(Piece.Color.black, R.string.reason_atomic_king)
            }
            if (kings.none { it.color == Piece.Color.black }) {
                return Result(Piece.Color.white, R.string.reason_atomic_king)
            }
        }

        // Le Roi de la colline et les Trois Échecs se gagnent SANS que la
        // partie soit bloquée : le moteur ferme la partie, mais il faut lire
        // la position pour savoir pourquoi.
        if (variantId == "kingofthehill") {
            kings.firstOrNull { it.square in hillSquares }?.let {
                return Result(it.color, R.string.reason_king_of_the_hill)
            }
        }
        if (variantId == "3check") {
            checksExhausted(fen)?.let { return Result(it, R.string.reason_three_checks) }
        }

        // Plus personne ne peut mater : nulle, avant même de regarder s'il
        // reste des coups. La règle ne vaut PAS pour toutes les variantes —
        // voir [VariantDrawRules.declaresInsufficientMaterial].
        if (VariantDrawRules.isInsufficientMaterial(fen, variantId, pocketIsEmpty)) {
            return Result(null, R.string.draw_material)
        }

        if (legalMoves.isNotEmpty()) return null

        return when (variantId) {
            "horde" -> {
                // Le camp aux PIONS n'a plus rien : l'autre gagne. Sinon, la
                // Horde se mate comme aux échecs ordinaires.
                if (position.pieces.none { it.color == Piece.Color.white }) {
                    Result(Piece.Color.black, R.string.reason_horde_extinct)
                } else {
                    classicEnd(next, inCheck)
                }
            }

            "racingkings" -> {
                val onEighth = kings.filter { it.square.rank.value == 8 }.map { it.color }.toSet()
                when {
                    onEighth.size == 2 -> Result(null, R.string.reason_racing_draw)
                    onEighth.isNotEmpty() -> Result(onEighth.first(), R.string.reason_racing_goal)
                    // Ni l'un ni l'autre : pat générique, hors course.
                    else -> Result(null, R.string.reason_stalemate)
                }
            }

            // Bloqué, plus de coup possible : le camp au trait GAGNE — le but
            // est inversé (perdre ses pièces, ou être immobilisé).
            "antichess" -> Result(next, R.string.reason_antichess_stuck)

            // MAT OU PAT AU SENS CLASSIQUE — et c'est volontairement le cas
            // par DÉFAUT, non une liste d'identifiants. Nommer les variantes
            // une à une ferait qu'une treizième, ajoutée plus tard, n'aurait
            // aucune fin de partie : un mat s'y jouerait sans que rien ne
            // l'annonce. C'est arrivé côté iOS avec les Barricades.
            else -> classicEnd(next, inCheck)
        }
    }

    private fun classicEnd(next: Piece.Color, inCheck: Boolean): Result =
        if (inCheck) Result(next.opposite, R.string.reason_checkmate)
        else Result(null, R.string.reason_stalemate)

    /**
     * Le camp qui a épuisé les échecs de l'adversaire, au Trois Échecs.
     *
     * Fairy-Stockfish écrit les échecs RESTANTS dans un septième champ de la
     * FEN (« 3+3 » au départ, « 0+3 » quand les Blancs ont donné leurs trois).
     * Lu plutôt que compté : le compter demanderait de rejouer la partie, et
     * le moteur tient déjà le décompte exact.
     */
    private fun checksExhausted(fen: String): Piece.Color? {
        val fields = fen.trim().split(" ")
        if (fields.size < 7) return null
        val counts = fields[4].split("+")
        if (counts.size != 2) return null
        val white = counts[0].toIntOrNull() ?: return null
        val black = counts[1].toIntOrNull() ?: return null
        return when {
            white == 0 -> Piece.Color.white
            black == 0 -> Piece.Color.black
            else -> null
        }
    }
}
