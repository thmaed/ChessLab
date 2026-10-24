package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * La consultation contre l'ordinateur avance et recule par coup COMPLET,
 * toujours vers une position où c'est au joueur de jouer. Pendant de
 * `ReviewStepperTests`.
 */
class ReviewStepperTest {

    @Test fun `aux Blancs, on avance et recule par coup complet`() {
        val stepper = ReviewStepper(totalPlies = 6, userMovesOnEvenPlies = true)
        assertEquals(4, stepper.previous(6))
        assertEquals(2, stepper.previous(4))
        assertEquals(0, stepper.previous(2))
        assertNull(stepper.previous(0))
        assertEquals(2, stepper.next(0))
        assertEquals(6, stepper.next(4))
        assertNull(stepper.next(6))
    }

    @Test fun `aux Noirs, les positions impaires, jamais le départ`() {
        val stepper = ReviewStepper(totalPlies = 6, userMovesOnEvenPlies = false)
        assertEquals(5, stepper.previous(6))
        assertEquals(3, stepper.previous(5))
        assertNull(stepper.previous(1))
        assertEquals(3, stepper.next(1))
        assertEquals("plus de position du joueur : retour au direct", 6, stepper.next(5))
    }

    @Test fun `quand le moteur réfléchit, le premier recul est d'un demi-coup`() {
        val stepper = ReviewStepper(totalPlies = 5, userMovesOnEvenPlies = true)
        assertEquals(4, stepper.previous(5))
        assertEquals(5, stepper.next(4))
    }

    @Test fun `depuis une position du moteur, les flèches se réalignent`() {
        val stepper = ReviewStepper(totalPlies = 8, userMovesOnEvenPlies = true)
        assertEquals(2, stepper.previous(3))
        assertEquals(4, stepper.next(3))
    }

    // MARK: Variantes (24/10)

    @Test fun `par la FEN, le joueur aux Noirs n'a le trait qu'aux positions b`() {
        val fens = listOf(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
            "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
        )
        val stepper = ReviewStepper.fromFens(4, fens, chesskit.Piece.Color.black)
        assertEquals(3, stepper.previous(4))
        assertEquals(1, stepper.previous(3))
        assertNull(stepper.previous(1))
        assertEquals(3, stepper.next(1))
        assertEquals(4, stepper.next(3))
    }

    @Test fun `Coup Volé, le milieu d'un tour double reste au joueur`() {
        val w = chesskit.Piece.Color.white
        val b = chesskit.Piece.Color.black
        val stepper = ReviewStepper.fromMovers(listOf(w, b, w, w, b, w), w)
        assertEquals(5, stepper.previous(6))
        assertEquals(3, stepper.previous(5))
        assertEquals(2, stepper.previous(3))
        assertEquals(0, stepper.previous(2))
        assertEquals(2, stepper.next(0))
        assertEquals(3, stepper.next(2))
        assertEquals(5, stepper.next(3))
        assertEquals(6, stepper.next(5))
    }

    @Test fun `à deux joueurs, chaque demi-coup est une étape`() {
        val stepper = ReviewStepper.everyPly(3)
        assertEquals(2, stepper.previous(3))
        assertEquals(1, stepper.next(0))
    }

    @Test fun `lit le camp au trait d'une FEN de variante`() {
        assertEquals(chesskit.Piece.Color.white, ReviewStepper.sideToMove("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[] w KQkq - 0 1"))
        assertNull(ReviewStepper.sideToMove("pas une fen"))
    }
}

