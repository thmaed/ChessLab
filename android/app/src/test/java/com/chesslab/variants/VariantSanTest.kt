package com.chesslab.variants

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * La notation des coups de variante, construite à la main.
 *
 * Elle doit l'être : `chesskit` ne joue aucun de ces coups — il ne fait que
 * lire une position rendue par le moteur —, et Fairy-Stockfish ne parle
 * qu'UCI. Sans ce fichier, la revue d'une partie affichait « b5b6 a7b6 » :
 * exact, illisible, et différent de l'iPhone à côté.
 */
class VariantSanTest {

    private val départ = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    @Test
    fun `une poussée de pion ne s'écrit que par sa case d'arrivée`() {
        assertEquals("e4", VariantSan.build("e2e4", départ, emptyList(), false, false))
    }

    @Test
    fun `une pièce porte sa lettre`() {
        assertEquals("Nf3", VariantSan.build("g1f3", départ, emptyList(), false, false))
    }

    @Test
    fun `une prise de pion porte sa colonne de départ`() {
        val fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2"
        assertEquals("exd5", VariantSan.build("e4d5", fen, emptyList(), false, false))
    }

    /** La prise EN PASSANT : la case d'arrivée est vide, et c'est pourtant une prise. */
    @Test
    fun `la prise en passant est une prise`() {
        val fen = "rnbqkbnr/pp1ppppp/8/2pP4/8/8/PPP1PPPP/RNBQKBNR w KQkq c6 0 3"
        assertEquals("dxc6", VariantSan.build("d5c6", fen, emptyList(), false, false))
    }

    @Test
    fun `la promotion s'écrit avec la pièce obtenue`() {
        val fen = "8/4P3/8/8/8/8/4k3/4K3 w - - 0 1"
        assertEquals("e8=Q", VariantSan.build("e7e8q", fen, emptyList(), false, false))
    }

    @Test
    fun `le roque se reconnaît au roi qui saute deux colonnes`() {
        val fen = "rnbqk2r/pppppppp/5n2/8/8/5N2/PPPPPPPP/RNBQK2R w KQkq - 0 1"
        assertEquals("O-O", VariantSan.build("e1g1", fen, emptyList(), false, false))
        val grand = "r3kbnr/pppppppp/8/8/8/8/PPPPPPPP/R3KBNR w KQkq - 0 1"
        assertEquals("O-O-O", VariantSan.build("e1c1", grand, emptyList(), false, false))
    }

    /**
     * La DÉSAMBIGUÏSATION, la seule raison pour laquelle il faut les coups
     * légaux : deux cavaliers peuvent atteindre d2, il faut dire lequel.
     */
    @Test
    fun `deux pièces sur la même case se distinguent par la colonne`() {
        val fen = "4k3/8/8/8/8/8/8/1N1K1N2 w - - 0 1"
        val légaux = listOf("b1d2", "f1d2")
        assertEquals("Nbd2", VariantSan.build("b1d2", fen, légaux, false, false))
        assertEquals("Nfd2", VariantSan.build("f1d2", fen, légaux, false, false))
    }

    /** Quand la colonne ne suffit pas, c'est la rangée qui départage. */
    @Test
    fun `sur la même colonne c'est la rangée qui départage`() {
        val fen = "4k3/8/8/1N6/8/1N6/8/3K4 w - - 0 1"
        val légaux = listOf("b5d4", "b3d4")
        assertEquals("N5d4", VariantSan.build("b5d4", fen, légaux, false, false))
        assertEquals("N3d4", VariantSan.build("b3d4", fen, légaux, false, false))
    }

    /** L'échec et le mat se marquent, comme partout. */
    @Test
    fun `l'échec et le mat portent leur signe`() {
        assertEquals("Nf3+", VariantSan.build("g1f3", départ, emptyList(), true, false))
        assertEquals("Nf3#", VariantSan.build("g1f3", départ, emptyList(), true, true))
    }

    /**
     * Le PARACHUTAGE du Crazyhouse s'écrit déjà en SAN. Il n'a pas de case de
     * départ, et tout le reste du calcul en suppose une : traité en premier.
     */
    @Test
    fun `le parachutage du Crazyhouse garde sa forme`() {
        assertEquals("P@e4", VariantSan.build("P@e4", départ, emptyList(), false, false))
        assertEquals("N@f6+", VariantSan.build("N@f6", départ, emptyList(), true, false))
    }

    /**
     * La position d'AVANT vient du moteur : elle porte la réserve du
     * Crazyhouse. Sans assainissement, `chesskit` posait cette réserve sur
     * l'échiquier et la notation s'en trouvait fausse.
     */
    @Test
    fun `la réserve du Crazyhouse ne change pas la notation`() {
        val moteur = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[Pn] w KQkq - 0 1"
        assertEquals("e4", VariantSan.build("e2e4", moteur, emptyList(), false, false))
    }

    /** Un coup illisible reste affiché tel quel : mieux vaut brut que faux. */
    @Test
    fun `un coup trop court est rendu inchangé`() {
        assertEquals("e2", VariantSan.build("e2", départ, emptyList(), false, false))
    }
}
