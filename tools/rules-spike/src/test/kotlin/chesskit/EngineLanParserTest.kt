package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** Portage de `EngineLANParserTests.swift` (ChessKit, MIT), repris un pour un. */
class EngineLanParserTest {

    @Test fun capture() {
        val position = Position.fromFen("8/8/8/4p3/3P4/8/8/8 w - - 0 1")!!
        val move = EngineLanParser.parse("d4e5", Piece.Color.white, position)
        assertEquals(
            Move.Result.Capture(Piece(Piece.Kind.pawn, Piece.Color.black, Square.e5)),
            move?.result,
        )
    }

    @Test fun castling() {
        val p1 = Position.fromFen("8/8/8/8/8/8/8/4K2R w KQ - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.wK), EngineLanParser.parse("e1g1", Piece.Color.white, p1)?.result)

        val p2 = Position.fromFen("8/8/8/8/8/8/8/R3K3 w KQ - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.wQ), EngineLanParser.parse("e1c1", Piece.Color.white, p2)?.result)

        val p3 = Position.fromFen("4k2r/8/8/8/8/8/8/8 b kq - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.bK), EngineLanParser.parse("e8g8", Piece.Color.black, p3)?.result)

        val p4 = Position.fromFen("r3k3/8/8/8/8/8/8/8 b kq - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.bQ), EngineLanParser.parse("e8c8", Piece.Color.black, p4)?.result)
    }

    @Test fun promotion() {
        val p = Position.fromFen("8/P7/8/8/8/8/8/8 w - - 0 1")!!
        val expected = mapOf(
            "a7a8q" to Piece.Kind.queen, "a7a8r" to Piece.Kind.rook,
            "a7a8b" to Piece.Kind.bishop, "a7a8n" to Piece.Kind.knight,
        )
        for ((lan, kind) in expected) {
            assertEquals(
                Piece(kind, Piece.Color.white, Square.a8),
                EngineLanParser.parse(lan, Piece.Color.white, p)?.promotedPiece,
                lan,
            )
        }
    }

    @Test fun validLanButInvalidMove() {
        assertNull(EngineLanParser.parse("a4b5", Piece.Color.white, Position.standard))
        assertNull(EngineLanParser.parse("f8b5", Piece.Color.black, Position.standard))
    }

    @Test fun invalidLan() {
        assertNull(EngineLanParser.parse("bad move", Piece.Color.white, Position.standard))
    }
}
