package com.chesslab.variants

import chesskit.Piece
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les cinq règles du Coup Volé, chacune vérifiée à part. Ce sont elles seules
 * qui distinguent la variante des échecs ordinaires — tout le reste est
 * arbitré par `chesskit`.
 */
class StolenMoveRulesTest {

    @Test fun `un jeton tous les N coups joues par le camp`() {
        val n = StolenMoveRules.defaultTokenInterval
        assertEquals(7, n)
        for (coup in 1..21) {
            assertEquals("coup $coup", coup % 7 == 0, StolenMoveRules.earnsToken(coup, n))
        }
        // Le zéroième coup n'existe pas : on ne commence pas la partie avec un jeton.
        assertFalse(StolenMoveRules.earnsToken(0, n))
        // Et l'intervalle est réglable.
        assertTrue(StolenMoveRules.earnsToken(4, 4))
        assertTrue(StolenMoveRules.earnsToken(8, 8))
        assertFalse(StolenMoveRules.earnsToken(7, 8))
        assertEquals(4..8, StolenMoveRules.tokenIntervalRange)
    }

    @Test fun `on ne depense pas un jeton en echec`() {
        assertTrue(StolenMoveRules.canSpend(hasToken = true, inCheck = false))
        assertFalse("règle 3", StolenMoveRules.canSpend(hasToken = true, inCheck = true))
        assertFalse(StolenMoveRules.canSpend(hasToken = false, inCheck = false))
    }

    @Test fun `le tour double s'arrete si le premier coup donne echec`() {
        assertTrue(StolenMoveRules.turnContinues(firstMoveGivesCheck = false))
        assertFalse("règle 4", StolenMoveRules.turnContinues(firstMoveGivesCheck = true))
    }

    @Test fun `la position revient au trait de celui qui joue son second coup`() {
        // Après 1.e4, chesskit a passé le trait aux Noirs.
        val afterE4 = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        val second = StolenMoveRules.fenForSecondMove(afterE4, Piece.Color.white, null)!!
        assertEquals("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e3 0 1", second)
    }

    /**
     * Règle 5 : la prise en passant ouverte par le dernier coup adverse
     * survit au coup qui s'intercale — le seul cas où cela peut arriver.
     */
    @Test fun `la prise en passant d'avant le tour double est rendue`() {
        // Les Noirs viennent de jouer d7d5 : « d6 » est prenable en passant.
        val beforeFirst = "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3"
        assertEquals("d6", StolenMoveRules.enPassantTarget(beforeFirst))
        // Les Blancs dépensent leur jeton et jouent autre chose d'abord : la
        // FEN n'a plus de prise en passant.
        val afterFirst = "rnbqkbnr/ppp1pppp/8/3pP3/8/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 3"
        assertNull(StolenMoveRules.enPassantTarget(afterFirst))
        // On la leur rend pour leur second coup.
        val second = StolenMoveRules.fenForSecondMove(afterFirst, Piece.Color.white, "d6")!!
        assertEquals("d6", StolenMoveRules.enPassantTarget(second))
        assertEquals("w", second.split(" ")[1])
    }

    @Test fun `une prise en passant deja presente n'est pas ecrasee`() {
        val fen = "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR b KQkq d6 0 3"
        val second = StolenMoveRules.fenForSecondMove(fen, Piece.Color.white, "e6")!!
        assertEquals("d6", StolenMoveRules.enPassantTarget(second))
    }

    @Test fun `une FEN incomplete ne fabrique rien`() {
        assertNull(StolenMoveRules.fenForSecondMove("pas une fen", Piece.Color.white, null))
        assertNull(StolenMoveRules.enPassantTarget("pas une fen"))
    }
}
