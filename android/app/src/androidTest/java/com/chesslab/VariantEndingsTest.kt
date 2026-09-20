package com.chesslab

import androidx.test.platform.app.InstrumentationRegistry
import chesskit.Piece
import com.chesslab.R
import com.chesslab.engine.FairyEngine
import com.chesslab.variants.VariantOutcome
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Les DOUZE fins de partie, lues sur les FEN que le moteur rend vraiment.
 *
 * Les tests JVM de `VariantOutcome` travaillent sur des FEN écrites à la main :
 * ils vérifient le raisonnement, pas le contrat avec Fairy-Stockfish. Or c'est
 * là qu'on s'est déjà trompé — le septième champ des Trois Échecs, que
 * `chesskit` refusait, ne se voyait dans aucun journal.
 *
 * Ici chaque variante reçoit une position à un coup de la fin, le coup est
 * joué PAR LE MOTEUR, et c'est sa réponse qui est jugée. Onze variantes sur
 * douze : le Duck Chess est arbitré dans l'app, sans moteur, et se vérifie
 * ailleurs.
 */
class VariantEndingsTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    /** Une variante, une position, un coup, et le verdict attendu. */
    private data class Cas(
        val nom: String,
        val uci: String,
        val fen: String?,
        val coups: List<String>,
        val gagnant: Piece.Color?,
        val raison: Int,
    )

    private val cas = listOf(
        // Le mat ordinaire, hérité par toutes celles qui ne redéfinissent rien.
        Cas("Chess960", "chess", "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1", listOf("f7g7"),
            Piece.Color.white, R.string.reason_checkmate),
        Cas("Coup Volé", "chess", "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1", listOf("f7g7"),
            Piece.Color.white, R.string.reason_checkmate),
        Cas("Crazyhouse", "crazyhouse", "7k/5Q2/6K1/8/8/8/8/8[] w - - 0 1", listOf("f7g7"),
            Piece.Color.white, R.string.reason_checkmate),
        Cas("Barricades", "barricades", "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1", listOf("f7g7"),
            Piece.Color.white, R.string.reason_checkmate),
        Cas("Barricades mobiles", "randombarricades", "7k/5Q2/6K1/8/8/8/8/8 w - - 0 1", listOf("f7g7"),
            Piece.Color.white, R.string.reason_checkmate),

        // Le roi qui atteint le centre : la partie s'arrête à l'instant.
        Cas("Roi de la colline", "kingofthehill", "4k3/8/8/8/8/4K3/8/8 w - - 0 1", listOf("e3e4"),
            Piece.Color.white, R.string.reason_king_of_the_hill),

        // Le troisième échec. Le compteur est DANS la FEN, et c'est lui qu'on lit.
        Cas("Trois échecs", "3check", "4k3/8/8/8/8/8/8/3QK3 w - - 1+3 0 1", listOf("d1d8"),
            Piece.Color.white, R.string.reason_three_checks),

        // La horde perd sa dernière pièce.
        Cas("Horde", "horde", "4k3/8/8/8/8/8/1r6/1P6 b - - 0 1", listOf("b2b1"),
            Piece.Color.black, R.string.reason_horde_extinct),

        // Le roi arrivé en 8e rangée gagne la course.
        Cas("Course des rois", "racingkings", "8/K7/8/8/8/8/8/7k w - - 0 1", listOf("a7a8"),
            Piece.Color.white, R.string.reason_racing_goal),

        // L'explosion emporte le roi adverse : la dame prend le pion d7.
        Cas("Atomique", "atomic", "4k3/3p4/8/8/8/8/8/3QK3 w - - 0 1", listOf("d1d7"),
            Piece.Color.white, R.string.reason_atomic_king),

        // Aux Antéchecs, être BLOQUÉ gagne. La prise est OBLIGATOIRE : la dame
        // blanche doit prendre le dernier pion noir, et les Noirs se
        // retrouvent sans une pièce — donc sans un coup, donc vainqueurs.
        Cas("Antéchecs", "antichess", "8/8/8/8/8/8/6p1/7Q w - - 0 1", listOf("h1g2"),
            Piece.Color.black, R.string.reason_antichess_stuck),
    )

    @Test
    fun lesFinsDePartieSeNomment() = runBlocking {
        val échecs = mutableListOf<String>()
        FairyEngine.use(context) { engine ->
            for (c in cas) {
                val q = engine.queryPosition(c.uci, c.fen, c.coups)
                if (q == null) { échecs += "${c.nom} : le moteur n'a pas répondu"; continue }
                val verdict = VariantOutcome.detect(c.uci, q.fen, q.legalMoves, q.inCheck)
                val rendu = verdict?.let { "${it.winner} / ${context.getString(it.reasonRes)}" } ?: "AUCUN"
                val attendu = "${c.gagnant} / ${context.getString(c.raison)}"
                println("FIN ${c.nom} : $rendu  (attendu $attendu)  fen=${q.fen} coups=${q.legalMoves.size}")
                if (rendu != attendu) échecs += "${c.nom} : $rendu au lieu de $attendu"
            }
            true
        }
        assertEquals("fins mal nommées", emptyList<String>(), échecs.toList())
    }
}
