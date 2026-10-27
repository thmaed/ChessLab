package com.chesslab.analysis

import org.junit.Assert.assertEquals
import org.junit.Test

/** Le récapitulatif de fin d'analyse sépare les mats manqués des erreurs. Pendant de `PuzzleOfferTests` (iOS). */
class PuzzleOfferTest {

    private fun candidate(isMate: Boolean, move: Int) = PuzzleCandidate(
        fen = "8/8/8/8/8/8/8/K6k w - - 0 1", playedSan = "Kb1", solution = listOf("a1a2"),
        theme = if (isMate) "checkmate" else "fork", isMate = isMate, moveNumber = move, blackToMove = false,
    )

    @Test fun `les mats et les erreurs se rangent a part`() {
        val offer = PuzzleOffer("k", listOf(candidate(true, 4), candidate(false, 9), candidate(false, 15)))
        assertEquals(1, offer.mates.size)
        assertEquals(2, offer.mistakes.size)
        assertEquals(4, offer.mates.first().moveNumber)
        assertEquals(3, offer.candidates.size)
    }
}
