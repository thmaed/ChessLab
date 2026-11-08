package com.chesslab.analysis

import chesskit.MoveTree
import chesskit.Piece
import chesskit.PgnParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Une partie JOUÉE dans l'app (126 demi-coups, 08/11/2026) qui faisait quitter l'app à l'analyse
 * côté iOS : « Rbxd4 » (capture désambiguïsée) ET deux promotions (« g1=Q », « e1=Q+ »). Le
 * chargeur iOS oubliait les promotions et laissait un pion sur la dernière rangée, que
 * Stockfish 19 refuse en quittant le process. Pendant de `PGNLoaderPromotionTests` (iOS) : le
 * port Kotlin lit la partie correctement, ce test le garantit.
 */
class PgnPromotionTest {
    private val pgn = """
[Event "Contre l'ordinateur"]
[Site "ChessLab"]
[Date "2026.09.30"]
[Round "-"]
[White "Pablo"]
[Black "Thierry"]
[Result "0-1"]

1. d4 d5 2. Bf4 e6 3. Qd3 Nc6 4. Qg3 Bd6 5. e3 Bxf4 6. Qxf4 Qd6 7. Qxd6 cxd6 8. Bb5 Nf6 9. Bxc6+ bxc6 10. Nd2 Ba6 11. Nb3 Ne4 12. Nd2 O-O 13. Nxe4 dxe4 14. Ne2 d5 15. Ng3 f5 16. a4 Rab8 17. b3 Rb4 18. f4 exf3 19. gxf3 g6 20. O-O-O f4 21. exf4 Rxf4 22. Rdf1 h5 23. Rf2 Rbxd4 24. Rd1 h4 25. Rxd4 Rxd4 26. Nh1 Rf4 27. h3 e5 28. Kd2 Kg7 29. Kd1 Kf6 30. b4 Rxb4 31. c3 Rxa4 32. Rb2 Ra1+ 33. Kd2 Rxh1 34. Rb8 Rxh3 35. Rf8+ Ke6 36. Ra8 Rxf3 37. Rxa7 Be2 38. Rc7 Bf1 39. Ra7 h3 40. Rh7 e4 41. Ke1 Bd3 42. Kd2 g5 43. Ke1 g4 44. Kd2 g3 45. Rxh3 g2 46. Rh6+ Kf5 47. Rh5+ Kg4 48. Rh7 g1=Q 49. Rg7+ Kf4 50. Rxg1 Rg3 51. Rf1+ Rf3 52. Rh1 c5 53. Rh4+ Kf5 54. Rh5+ Kf4 55. Kc1 e3 56. Kd1 e2+ 57. Ke1 Rf1+ 58. Kd2 e1=Q+ 59. Kxd3 Qe3+ 60. Kc2 Rc1+ 61. Kb3 Qxc3+ 62. Ka4 Rb1 63. Rxd5 Qa1# 0-1
""".trimIndent()

    @Test fun `une partie rechargee garde ses pieces promues`() {
        val game = PgnParser.parse(PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(pgn)).first())
        val main = game.moves.indices
            .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
            .sortedWith(compareBy({ it.number }, { if (it.color == Piece.Color.black) 1 else 0 }))
        assertEquals(126, main.size)
        val fens = listOf(game.startingIndex).plus(main).map { game.positions[it]!!.fen }
        for ((ply, fen) in fens.withIndex()) {
            val ranks = fen.substringBefore(" ").split("/")
            assertFalse("pion sur la 8e rangée, demi-coup $ply : $fen", ranks.first().any { it == 'p' || it == 'P' })
            assertFalse("pion sur la 1re rangée, demi-coup $ply : $fen", ranks.last().any { it == 'p' || it == 'P' })
        }
        assertTrue("g1=Q : ${fens[96]}", fens[96].startsWith("8/7R/2p5/3p4/4p1k1/2Pb1r2/3K4/6q1 "))
        assertTrue(fens.last(), fens.last().startsWith("8/8/8/2pR4/K4k2/8/8/qr6 "))
    }
}
