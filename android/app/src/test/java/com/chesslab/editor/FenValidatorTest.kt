package com.chesslab.editor

import com.chesslab.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ce qui fait qu'une FEN est jouable — les règles de `FENValidator.swift`. */
class FenValidatorTest {

    @Test fun `la position de depart est legale`() {
        assertTrue(FenValidator.isLegal("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
    }

    @Test fun `six champs sont exiges`() {
        assertEquals(listOf(R.string.fen_error_fields), FenValidator.errors("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"))
    }

    @Test fun `il faut un roi de chaque couleur`() {
        assertTrue(R.string.fen_error_kings in FenValidator.errors("8/8/8/8/8/8/8/4K3 w - - 0 1"))
        assertTrue(R.string.fen_error_kings in FenValidator.errors("4k3/8/8/8/8/8/8/4K2K w - - 0 1"))
    }

    @Test fun `un pion ne peut pas etre sur la premiere ou la derniere rangee`() {
        assertTrue(R.string.fen_error_pawn_rank in FenValidator.errors("4k2P/8/8/8/8/8/8/4K3 w - - 0 1"))
    }

    @Test fun `le camp qui n'a pas le trait ne peut pas etre deja en echec`() {
        // La tour e7 donne échec au roi e8, et c'est aux BLANCS de jouer.
        assertTrue(R.string.fen_error_opponent_in_check in FenValidator.errors("4k3/4R3/8/8/8/8/8/4K3 w - - 0 1"))
        // Aux Noirs de jouer : l'échec est normal.
        assertFalse(R.string.fen_error_opponent_in_check in FenValidator.errors("4k3/4R3/8/8/8/8/8/4K3 b - - 0 1"))
    }

    @Test fun `une position deja terminee est refusee`() {
        // Pat : roi h8, dame f7, roi g6, aux Noirs de jouer.
        assertTrue(R.string.fen_error_no_legal_move in FenValidator.errors("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))
    }

    @Test fun `un droit de roque sans sa tour est incoherent`() {
        val errors = FenValidator.errors("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBN1 w KQkq - 0 1")
        assertTrue(R.string.fen_error_castling_wk in errors)
        assertFalse(R.string.fen_error_castling_wq in errors)
    }

    @Test fun `la case en passant doit avoir son pion`() {
        assertTrue(FenValidator.isLegal("rnbqkbnr/pppp1ppp/8/4p3/8/8/PPPPPPPP/RNBQKBNR w KQkq e6 0 2"))
        assertTrue(R.string.fen_error_ep_pawn in FenValidator.errors("rnbqkbnr/pppp1ppp/4p3/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e6 0 2"))
        assertTrue(R.string.fen_error_ep_rank in FenValidator.errors("rnbqkbnr/pppp1ppp/8/4p3/8/8/PPPPPPPP/RNBQKBNR w KQkq e4 0 2"))
    }
}
