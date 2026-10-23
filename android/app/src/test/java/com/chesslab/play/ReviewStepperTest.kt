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
}
