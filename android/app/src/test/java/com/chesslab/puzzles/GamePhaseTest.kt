package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Test

/** La phase lue sur la FEN. Mêmes positions que `GamePhaseAndDifficultyTests` (iOS). */
class GamePhaseTest {

    @Test fun `après 1 e4, c'est l'ouverture`() {
        assertEquals(GamePhase.opening, GamePhase.classify("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"))
    }

    @Test fun `dame et pièces mineures, c'est le milieu de partie`() {
        assertEquals(
            GamePhase.middlegame,
            GamePhase.classify("r2q1rk1/pb2ppbp/1pn3p1/2p1n3/Q7/2P2NP1/PP1N1PBP/R1B1R1K1 w - - 0 14"),
        )
    }

    @Test fun `sans dame et peu de pièces, c'est la finale`() {
        assertEquals(GamePhase.endgame, GamePhase.classify("8/p1k5/1p2p3/PPK1Pp1p/8/6P1/7P/8 w - - 0 33"))
        assertEquals(GamePhase.endgame, GamePhase.classify("8/4R3/1p2P3/p4r2/P6p/1P3Pk1/4K3/8 w - - 1 64"))
    }

    @Test fun `une FEN illisible retombe sur le milieu de partie`() {
        assertEquals(GamePhase.middlegame, GamePhase.classify("not a fen"))
    }

    @Test fun `un puzzle maison porte désormais sa phase`() {
        val own = OwnPuzzle(
            uid = "x", fen = "8/4R3/1p2P3/p4r2/P6p/1P3Pk1/4K3/8 w - - 1 64", playedSan = "Kf2",
            solution = "e7e8", theme = "tactic", rating = 0, createdAt = 0, sourcePgn = "",
        )
        assertEquals("endgame", own.toPuzzle().phase)
    }
}
