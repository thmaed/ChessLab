package com.chesslab.variants

import chesskit.Piece
import com.chesslab.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pourquoi une partie de variante s'arrête, et qui la gagne.
 *
 * Android n'en disait rien : le moteur annonçait « plus aucun coup légal » et
 * l'écran affichait « Partie terminée », sans vainqueur ni raison. Ces cas-là
 * ne se rencontrent qu'en jouant une partie entière de chacune des douze
 * variantes — d'où ces tests, qui les posent d'un coup.
 */
class VariantOutcomeTest {

    @Test
    fun `le roi sur la colline gagne`() {
        val r = VariantOutcome.detect("kingofthehill", "4k3/8/8/8/4K3/8/8/8 b - - 0 1", emptyList(), false)
        assertEquals(Piece.Color.white, r?.winner)
        assertEquals(R.string.reason_king_of_the_hill, r?.reasonRes)
    }

    /** Il gagne MÊME s'il reste des coups : la partie s'arrête à l'instant. */
    @Test
    fun `le roi sur la colline gagne avant le blocage`() {
        val r = VariantOutcome.detect("kingofthehill", "4k3/8/8/8/4K3/8/8/8 b - - 0 1", listOf("e8d8"), false)
        assertEquals(Piece.Color.white, r?.winner)
    }

    /**
     * Les Trois Échecs se LISENT dans la FEN : le moteur y écrit les échecs
     * restants, « 3+3 » au départ, « 0+3 » quand les Blancs ont donné les
     * leurs. Compter nous-mêmes demanderait de rejouer la partie.
     */
    @Test
    fun `trois échecs blancs donnent la victoire aux Blancs`() {
        val fen = "rnbqkbnr/ppp1pppp/8/1B1p4/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 0+3 1 2"
        val r = VariantOutcome.detect("3check", fen, emptyList(), true)
        assertEquals(Piece.Color.white, r?.winner)
        assertEquals(R.string.reason_three_checks, r?.reasonRes)
    }

    @Test
    fun `des échecs restants ne terminent rien`() {
        val fen = "rnbqkbnr/ppp1pppp/8/1B1p4/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 2+3 1 2"
        assertNull(VariantOutcome.detect("3check", fen, listOf("c7c6"), true))
    }

    @Test
    fun `la horde éteinte perd`() {
        val r = VariantOutcome.detect("horde", "4k3/8/8/8/8/8/8/8 w - - 0 1", emptyList(), false)
        assertEquals(Piece.Color.black, r?.winner)
        assertEquals(R.string.reason_horde_extinct, r?.reasonRes)
    }

    @Test
    fun `un roi explosé termine l'Atomique`() {
        val r = VariantOutcome.detect("atomic", "4k3/8/8/8/8/8/8/8 w - - 0 1", listOf("e8d8"), false)
        assertEquals(Piece.Color.black, r?.winner)
        assertEquals(R.string.reason_atomic_king, r?.reasonRes)
    }

    @Test
    fun `le roi arrivé en 8e gagne la course`() {
        val r = VariantOutcome.detect("racingkings", "4K3/8/8/8/8/8/krbnNBRQ/qrbnNBRQ b - - 0 1", emptyList(), false)
        assertEquals(Piece.Color.white, r?.winner)
        assertEquals(R.string.reason_racing_goal, r?.reasonRes)
    }

    @Test
    fun `les deux rois arrivés ensemble font nulle`() {
        val r = VariantOutcome.detect("racingkings", "3kK3/8/8/8/8/8/8/8 b - - 0 1", emptyList(), false)
        assertNull(r?.winner)
        assertEquals(R.string.reason_racing_draw, r?.reasonRes)
    }

    /** Aux Antéchecs, être BLOQUÉ est une victoire : le but est inversé. */
    @Test
    fun `l'Antéchecs bloqué gagne`() {
        val r = VariantOutcome.detect("antichess", "8/8/8/8/8/8/8/7k w - - 0 1", emptyList(), false)
        assertEquals(Piece.Color.white, r?.winner)
        assertEquals(R.string.reason_antichess_stuck, r?.reasonRes)
    }

    /**
     * Le cas par DÉFAUT, et c'est volontaire : une variante qui ne redéfinit
     * pas la fin hérite de celle des échecs. Côté iOS, nommer les variantes
     * une à une avait laissé les Barricades sans fin de partie — un mat s'y
     * jouait sans que rien ne l'annonce.
     */
    @Test
    fun `une variante sans règle propre se mate comme aux échecs`() {
        val mat = VariantOutcome.detect("barricades", "7k/5QK1/8/8/8/8/8/8 b - - 0 1", emptyList(), true)
        assertEquals(Piece.Color.white, mat?.winner)
        assertEquals(R.string.reason_checkmate, mat?.reasonRes)

        val pat = VariantOutcome.detect("barricades", "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1", emptyList(), false)
        assertNull(pat?.winner)
        assertEquals(R.string.reason_stalemate, pat?.reasonRes)
    }

    /**
     * Le matériel insuffisant NE VAUT PAS partout : il suppose que gagner
     * c'est mater, ce qui est faux dans la moitié du hub. Roi + fou contre roi
     * est nul aux Barricades, et encore gagnable à l'Atomique.
     */
    @Test
    fun `le matériel insuffisant ne vaut que là où l'on gagne par mat`() {
        val fen = "4k3/8/8/8/8/8/8/3BK3 b - - 0 1"
        assertEquals(R.string.draw_material, VariantOutcome.detect("barricades", fen, listOf("e8d8"), false)?.reasonRes)
        assertNull(VariantOutcome.detect("atomic", fen, listOf("e8d8"), false))
        assertNull(VariantOutcome.detect("antichess", fen, listOf("e8d8"), false))
        assertNull(VariantOutcome.detect("racingkings", fen, listOf("e8d8"), false))
        assertNull(VariantOutcome.detect("kingofthehill", fen, listOf("e8d8"), false))
    }

    /** Une réserve NON VIDE au Crazyhouse : une pièce en main mate encore. */
    @Test
    fun `une réserve pleine empêche la nulle par matériel`() {
        val fen = "4k3/8/8/8/8/8/8/3BK3[Q] b - - 0 1"
        assertNull(VariantOutcome.detect("crazyhouse", fen, listOf("e8d8"), false, pocketIsEmpty = false))
        assertEquals(
            R.string.draw_material,
            VariantOutcome.detect("crazyhouse", fen, listOf("e8d8"), false, pocketIsEmpty = true)?.reasonRes,
        )
    }

    /** Une partie en cours ne produit aucun verdict. */
    @Test
    fun `une partie en cours n'a pas de fin`() {
        val départ = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        assertNull(VariantOutcome.detect("crazyhouse", départ, listOf("e2e4"), false))
        assertNull(VariantOutcome.detect("kingofthehill", départ, listOf("e2e4"), false))
    }
}
