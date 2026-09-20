package com.chesslab.variants

import chesskit.Position
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * La FEN du moteur, assainie avant d'aller à `chesskit`.
 *
 * Ce test existe parce que `chesskit` ne lève JAMAIS d'exception : donné une
 * FEN qu'il ne comprend pas, il rend une position plausible plutôt qu'une
 * erreur. Une FEN mal assainie ne se voit donc ni au compilateur ni dans un
 * journal — elle se voit sur l'échiquier, sous la forme d'une pièce qui n'a
 * rien à y faire, et l'écran de revue des variantes en a montré une.
 */
class VariantFenTest {

    private fun pièces(fen: String) =
        Position.fromFen(fen)?.pieces?.sortedBy { it.square.ordinal }
            ?.joinToString(" ") { "${it.fen}${it.square.notation}" } ?: "nul"

    /**
     * La RÉSERVE du Crazyhouse n'est pas sur le plateau. Brute, elle y
     * atterrissait : le cavalier capturé apparaissait en h1.
     */
    @Test
    fun `la réserve du Crazyhouse ne se pose pas sur l'échiquier`() {
        val moteur = "8/8/8/8/8/8/4K3/4k3[n] w - - 0 1"
        assertEquals("ke1 nh1 Ke2", pièces(moteur))
        assertEquals("ke1 Ke2", pièces(VariantFen.forChessKit(moteur)))
    }

    /** Une poche à plusieurs pièces, et des deux couleurs. */
    @Test
    fun `une réserve fournie ne change rien au plateau`() {
        val moteur = "8/8/8/8/8/8/4K3/4k3[NNpq] b - - 3 12"
        assertEquals("ke1 Ke2", pièces(VariantFen.forChessKit(moteur)))
    }

    /** La marque `~` d'un pion promu ne doit pas décaler la rangée. */
    @Test
    fun `la marque de promotion disparaît sans décaler la rangée`() {
        val moteur = "8/8/8/8/8/5Q~2/4K3/4k3[] w - - 0 1"
        assertEquals("ke1 Ke2 Qf3", pièces(VariantFen.forChessKit(moteur)))
    }

    /** Le mur des Barricades n'est pas une pièce pour `chesskit`. */
    @Test
    fun `le mur des Barricades quitte la position`() {
        val moteur = "8/8/8/2W1b3/8/8/4K3/4k3 w - - 0 1"
        assertEquals("ke1 Ke2 be5", pièces(VariantFen.forChessKit(moteur)))
    }

    /**
     * Le compteur des Trois Échecs fait SEPT champs ; `chesskit` en attend
     * six, et rendait `null` — la position entière devenait illisible, sans
     * qu'aucune exception ne le dise.
     */
    @Test
    fun `le compteur des trois échecs quitte la FEN`() {
        val moteur = "4k3/8/8/8/8/8/8/4K3 b - - 0+3 1 2"
        assertEquals("nul", pièces(moteur))
        assertEquals("Ke1 ke8", pièces(VariantFen.forChessKit(moteur)))
    }

    /**
     * On ne retire QUE ce champ-là, et seulement s'il en a la forme : un
     * septième champ d'une autre nature ne doit pas disparaître en silence.
     */
    @Test
    fun `un septième champ d'une autre forme est laissé en place`() {
        val bizarre = "4k3/8/8/8/8/8/8/4K3 b - - 0 1 xyz"
        assertEquals(bizarre, VariantFen.forChessKit(bizarre))
    }

    /** Une FEN ordinaire traverse sans une retouche. */
    @Test
    fun `une position ordinaire passe telle quelle`() {
        val ordinaire = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        assertEquals(ordinaire, VariantFen.forChessKit(ordinaire))
    }
}
