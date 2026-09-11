package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Portage de `FENParserTests.swift` (ChessKit, MIT). */
class FenParserTest {

    private val standardFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    private val complexFen = "r1b1k1nr/p2p1pNp/n2B4/1p1NP2P/6P1/3P1Q2/P1P1K3/q5b1 b kq - 0 20"
    private val epFen = "rnbqkbnr/ppppp1pp/8/8/4Pp2/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    private val castlingFen = "4k2r/6r1/8/8/8/8/3R4/R3K3 w Qk - 0 1"
    private val fiftyMoveFen = "8/5k2/3p4/1p1Pp2p/pP2Pp1P/P4P1K/8/8 b - - 99 50"

    @Test fun standardStartingPosition() {
        val p = Position.standard
        assertEquals(32, p.pieces.size)
        assertEquals(Piece.Color.white, p.sideToMove)
        assertEquals(
            LegalCastlings(listOf(Castling.bK, Castling.wK, Castling.bQ, Castling.wQ)),
            p.legalCastlings
        )
        assertNull(p.enPassant)
        assertEquals(0, p.clock.halfmoves)
        assertEquals(1, p.clock.fullmoves)
    }

    @Test fun complexPiecePlacement() {
        val p = Position.fromFen(complexFen)!!
        assertEquals(24, p.pieces.size)
        assertEquals(Piece.Color.black, p.sideToMove)
        assertEquals(LegalCastlings(listOf(Castling.bK, Castling.bQ)), p.legalCastlings)
        assertNull(p.enPassant)
        assertEquals(0, p.clock.halfmoves)
        assertEquals(20, p.clock.fullmoves)

        val expected = listOf(
            Piece(Piece.Kind.rook, Piece.Color.black, Square.a8),
            Piece(Piece.Kind.bishop, Piece.Color.black, Square.c8),
            Piece(Piece.Kind.king, Piece.Color.black, Square.e8),
            Piece(Piece.Kind.knight, Piece.Color.black, Square.g8),
            Piece(Piece.Kind.rook, Piece.Color.black, Square.h8),
            Piece(Piece.Kind.pawn, Piece.Color.black, Square.a7),
            Piece(Piece.Kind.pawn, Piece.Color.black, Square.d7),
            Piece(Piece.Kind.pawn, Piece.Color.black, Square.f7),
            Piece(Piece.Kind.knight, Piece.Color.white, Square.g7),
            Piece(Piece.Kind.pawn, Piece.Color.black, Square.h7),
            Piece(Piece.Kind.knight, Piece.Color.black, Square.a6),
            Piece(Piece.Kind.bishop, Piece.Color.white, Square.d6),
            Piece(Piece.Kind.pawn, Piece.Color.black, Square.b5),
            Piece(Piece.Kind.knight, Piece.Color.white, Square.d5),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.e5),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.h5),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.g4),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.d3),
            Piece(Piece.Kind.queen, Piece.Color.white, Square.f3),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.a2),
            Piece(Piece.Kind.pawn, Piece.Color.white, Square.c2),
            Piece(Piece.Kind.king, Piece.Color.white, Square.e2),
            Piece(Piece.Kind.queen, Piece.Color.black, Square.a1),
            Piece(Piece.Kind.bishop, Piece.Color.black, Square.g1),
        )
        for (piece in expected) {
            assertTrue(piece in p.pieces, "pièce manquante : $piece")
        }
    }

    @Test fun enPassantPosition() {
        val whiteEP = Position.fromFen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")!!
        assertEquals(Piece.Color.black, whiteEP.sideToMove)
        assertEquals(
            EnPassant(Piece(Piece.Kind.pawn, Piece.Color.white, Square.e4)),
            whiteEP.enPassant
        )

        val blackEP = Position.fromFen("rnbqkbnr/pppppppp/8/4P3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")!!
        assertEquals(Piece.Color.white, blackEP.sideToMove)
        assertEquals(
            EnPassant(Piece(Piece.Kind.pawn, Piece.Color.black, Square.e5)),
            blackEP.enPassant
        )
    }

    @Test fun invalidFen() {
        assertNull(Position.fromFen("invalid"))

        val invalidSideToMove = Position.fromFen("8/8/8/4p1K1/2k1P3/8/8/8 B - - 0 1")!!
        assertEquals(Piece.Color.white, invalidSideToMove.sideToMove)
    }

    @Test fun convertPosition() {
        assertEquals(standardFen, Position.standard.fen)
        assertEquals(complexFen, Position.fromFen(complexFen)!!.fen)
        assertEquals(epFen, Position.fromFen(epFen)!!.fen)
        assertEquals(castlingFen, Position.fromFen(castlingFen)!!.fen)
        assertEquals(fiftyMoveFen, Position.fromFen(fiftyMoveFen)!!.fen)
    }
}
