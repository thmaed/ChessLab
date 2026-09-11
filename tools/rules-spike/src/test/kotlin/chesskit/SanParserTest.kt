package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** Portage de `SANParserTests.swift` (ChessKit, MIT), repris un pour un. */
class SanParserTest {

    @Test fun castling() {
        val p1 = Position.fromFen("r3k3/8/8/8/8/8/8/4K2R w Kq - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.wK), SanParser.parse("O-O", p1)?.result)

        val p2 = Position.fromFen("r3k3/8/8/8/8/8/8/5RK1 b q - 0 1")!!
        assertEquals(Move.Result.Castle(Castling.bQ), SanParser.parse("O-O-O", p2)?.result)
    }

    @Test fun enPassant() {
        val p = Position.fromFen("rnbqkbnr/pp2pppp/8/2pP4/8/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 1")!!
        assertEquals(
            Move.Result.Capture(Piece(Piece.Kind.pawn, Piece.Color.black, Square.c5)),
            SanParser.parse("dxc6", p)?.result,
        )
    }

    @Test fun promotion() {
        val p = Position.fromFen("8/P7/8/8/8/8/8/8 w - - 0 1")!!
        assertEquals(
            Piece(Piece.Kind.queen, Piece.Color.white, Square.a8),
            SanParser.parse("a8=Q", p)?.promotedPiece,
        )
    }

    @Test fun checksAndMates() {
        val p1 = Position.fromFen("8/k7/7Q/6R1/8/8/8/8 w - - 0 1")!!
        assertEquals(Move.CheckState.check, SanParser.parse("Rg7+", p1)?.checkState)

        val p2 = Position.fromFen("8/k5R1/7Q/8/8/8/8/8 b - - 0 1")!!
        assertEquals(Move.CheckState.none, SanParser.parse("Ka8", p2)?.checkState)

        val p3 = Position.fromFen("k7/6R1/7Q/8/8/8/8/8 w - - 0 1")!!
        assertEquals(Move.CheckState.checkmate, SanParser.parse("Qh8#", p3)?.checkState)
    }

    @Test fun disambiguation() {
        val pw = Position.fromFen("3r3r/8/8/R7/4Q2Q/8/8/R6Q w - - 0 1")!!
        val pb = Position.fromFen("3r3r/8/8/R7/4Q2Q/8/8/R6Q b - - 0 1")!!
        val pbCheck = Position.fromFen("r4rk1/pp3pbp/1qp3p1/2B5/2BP2b1/Q1n2N2/P4PPP/3RK2R b K - 1 16")!!

        val rookByRank = SanParser.parse("R1a3", pw)!!
        assertEquals(Move.Result.Move, rookByRank.result)
        assertEquals(Piece.Kind.rook, rookByRank.piece.kind)
        assertEquals(Move.Disambiguation.ByRank(Square.Rank(1)), rookByRank.disambiguation)
        assertEquals(Square.a1, rookByRank.start)
        assertEquals(Square.a3, rookByRank.end)
        assertNull(rookByRank.promotedPiece)
        assertEquals(Move.CheckState.none, rookByRank.checkState)

        val rookByFile = SanParser.parse("Rdf8", pb)!!
        assertEquals(Move.Disambiguation.ByFile(Square.File.d), rookByFile.disambiguation)
        assertEquals(Square.d8, rookByFile.start)
        assertEquals(Square.f8, rookByFile.end)

        val rookCheck = SanParser.parse("Rfe8+", pbCheck)!!
        assertEquals(Move.Disambiguation.ByFile(Square.File.f), rookCheck.disambiguation)
        assertEquals(Square.f8, rookCheck.start)
        assertEquals(Square.e8, rookCheck.end)
        assertEquals(Move.CheckState.check, rookCheck.checkState)

        val queen = SanParser.parse("Qh4e1", pw)!!
        assertEquals(Piece.Kind.queen, queen.piece.kind)
        assertEquals(Move.Disambiguation.BySquare(Square.h4), queen.disambiguation)
        assertEquals(Square.h4, queen.start)
        assertEquals(Square.e1, queen.end)
    }

    @Test fun validSanButInvalidMove() {
        assertNull(SanParser.parse("axb5", Position.standard))
        assertNull(SanParser.parse("Bb5", Position.standard))
    }

    @Test fun invalidSan() {
        assertNull(SanParser.parse("bad move", Position.standard))
        assertNull(SanParser.parse("exf3", Position.standard))
        assertNull(SanParser.parse("aNf3", Position.standard))
        assertNull(SanParser.parse("e44", Position.standard))
    }
}
