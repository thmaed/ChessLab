package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Portage de `PGNParserTests.swift` (ChessKit, MIT). */
class PgnTest {

    private val fischerSpassky = """
        [Event "F/S Return Match"]
        [Site "Belgrade, Serbia JUG"]
        [Date "1992.11.04"]
        [Round "29"]
        [White "Fischer, Robert J."]
        [Black "Spassky, Boris V."]
        [Result "1/2-1/2"]
        [Annotator "Mr. Annotator"]
        [PlyCount "85"]
        [TimeControl "?"]
        [Time "??:??:??"]
        [Termination "normal"]
        [Mode "OTB"]
        [FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]
        [SetUp "1"]
        [CustomTag "test"]

        1. e4 ${'$'}4 e5 ${'$'}3 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}
        4. Ba4 {test comment} Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 ${'$'}135 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7
        11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5
        Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6
        23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5
        hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5
        35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6
        Nf2 42. g4 Bd3 43. Re6 1/2-1/2
    """.trimIndent()

    @Test fun gameFromEmptyPgn() {
        val game = PgnParser.parse("")
        assertTrue(game.moves.isEmpty)
        assertEquals(Position.standard.fen, game.startingPosition!!.fen)
    }

    @Test fun pgnFromGame() {
        val game = Game()
        game.make(listOf("e4", "e5", "Nf3", "Nc6", "Bc4"), from = MoveTree.Index.minimum)
        assertEquals("1. e4 e5 2. Nf3 Nc6 3. Bc4", PgnWriter.convert(game))
    }

    @Test fun pgnFromEmptyGame() {
        assertEquals("", PgnWriter.convert(Game()))
    }

    @Test fun tagParsing() {
        val tags = PgnParser.parse(fischerSpassky).tags
        assertEquals("F/S Return Match", tags.event)
        assertEquals("Belgrade, Serbia JUG", tags.site)
        assertEquals("1992.11.04", tags.date)
        assertEquals("29", tags.round)
        assertEquals("Fischer, Robert J.", tags.white)
        assertEquals("Spassky, Boris V.", tags.black)
        assertEquals("1/2-1/2", tags.result)
        assertEquals("Mr. Annotator", tags.annotator)
        assertEquals("85", tags.plyCount)
        assertEquals("?", tags.timeControl)
        assertEquals("??:??:??", tags.time)
        assertEquals("normal", tags.termination)
        assertEquals("OTB", tags.mode)
        assertEquals("test", tags.other["CustomTag"])
    }

    @Test fun tagParsingIrregularWhitespace() {
        val tags = PgnParser.parse("""
            [Tag1 "A"     ]
              [      Tag2   "B"]

            1. e4
        """.trimIndent()).tags
        assertEquals("A", tags.other["Tag1"])
        assertEquals("B", tags.other["Tag2"])
    }

    @Test fun movesAnnotationsAndComments() {
        val game = PgnParser.parse(fischerSpassky)
        val first = MoveTree.Index(1, Piece.Color.white)
        assertEquals("e4", game.moves[first]?.san)
        assertEquals(Move.Assessment.blunder, game.moves[first]?.assessment)

        val third = MoveTree.Index(3, Piece.Color.black)
        assertEquals("a6", game.moves[third]?.san)
        assertEquals("This opening is called the Ruy Lopez.", game.moves[third]?.comment)

        // 85 demi-coups annoncés par le tag PlyCount
        assertEquals(85, game.moves.indices.size)
    }

    @Test fun roundTrip() {
        val game = PgnParser.parse(fischerSpassky)
        val written = PgnWriter.convert(game)
        val reread = PgnParser.parse(written)

        assertEquals(game.moves.indices.size, reread.moves.indices.size)
        assertEquals(PgnWriter.convert(reread), written)

        // et la position finale doit coïncider
        val lastIndex = game.moves.indices.maxOrNull()!!
        assertEquals(game.position(lastIndex)!!.fen, reread.position(reread.moves.indices.maxOrNull()!!)!!.fen)
    }

    @Test fun variations() {
        val game = PgnParser.parse("1. e4 e5 (1... c5 2. Nf3) 2. Nf3 Nc6")
        // la ligne principale garde ses quatre demi-coups
        val main = game.moves.indices.filter { it.variation == MoveTree.Index.MAIN_VARIATION }
        assertEquals(4, main.size)
        // la variante sicilienne s'ajoute à côté
        assertTrue(game.moves.indices.size > 4, "la variante doit être conservée")
        assertTrue(game.moves.indices.any { game.moves[it]?.san == "c5" }, "1... c5 doit être présent")
    }
}
