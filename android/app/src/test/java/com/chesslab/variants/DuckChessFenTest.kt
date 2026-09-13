package com.chesslab.variants

import chesskit.Castling
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'application d'un coup de Duck Chess : `chesskit` REFUSE ces coups — il
 * filtre sur l'échec —, donc on écrit le plateau résultant nous-mêmes. Tout ce
 * qui suit vérifie qu'on l'écrit juste, y compris les trois cas qu'on oublie :
 * le roque, la prise en passant et la promotion.
 */
class DuckChessFenTest {

    private fun position(fen: String): Position = FenParser.parse(fen)!!

    private val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    @Test fun `un coup ordinaire deplace la piece et GARDE le trait`() {
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("e2"), Square("e4")), position(start))
        assertNull(after.piece(Square("e2")))
        assertEquals(Piece.Kind.pawn, after.piece(Square("e4"))?.kind)
        // Le tour n'est pas fini : il reste le canard à poser.
        assertEquals(Piece.Color.white, after.sideToMove)
        assertEquals(Piece.Color.black, DuckChessFen.flippedSideToMove(after).sideToMove)
    }

    @Test fun `la prise retire la piece de la case d'arrivee`() {
        val fen = "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1"
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("e1"), Square("e2")), position(fen))
        assertEquals(Piece.Kind.king, after.piece(Square("e2"))?.kind)
        assertEquals(Piece.Color.white, after.piece(Square("e2"))?.color)
    }

    @Test fun `le roque emmene la tour, et les droits tombent`() {
        val fen = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1"
        val short = DuckChessFen.applied(DuckChessRules.Move(Square("e1"), Square("g1")), position(fen))
        assertEquals(Piece.Kind.king, short.piece(Square("g1"))?.kind)
        assertEquals(Piece.Kind.rook, short.piece(Square("f1"))?.kind)
        assertNull(short.piece(Square("h1")))
        assertFalse(Castling.wK in short.legalCastlings)
        assertFalse(Castling.wQ in short.legalCastlings)

        val long = DuckChessFen.applied(DuckChessRules.Move(Square("e1"), Square("c1")), position(fen))
        assertEquals(Piece.Kind.king, long.piece(Square("c1"))?.kind)
        assertEquals(Piece.Kind.rook, long.piece(Square("d1"))?.kind)
        assertNull(long.piece(Square("a1")))
    }

    @Test fun `une tour qui bouge perd SON droit, pas l'autre`() {
        val fen = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1"
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("h1"), Square("h5")), position(fen))
        assertFalse("le petit roque tombe", Castling.wK in after.legalCastlings)
        assertTrue("le grand roque survit", Castling.wQ in after.legalCastlings)
    }

    @Test fun `une tour PRISE dans son coin fait tomber le droit adverse`() {
        val fen = "r3k3/8/8/8/8/8/8/R3K3 w Qq - 0 1"
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("a1"), Square("a8")), position(fen))
        assertFalse("la tour noire est prise en a8", Castling.bQ in after.legalCastlings)
        assertFalse("et la tour blanche a quitté a1", Castling.wQ in after.legalCastlings)
    }

    @Test fun `la prise en passant retire un pion qui n'est PAS sur la case d'arrivee`() {
        val fen = "4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1"
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("e5"), Square("d6")), position(fen))
        assertEquals(Piece.Kind.pawn, after.piece(Square("d6"))?.kind)
        assertNull("le pion noir de d5 disparaît", after.piece(Square("d5")))
        assertNull(after.piece(Square("e5")))
    }

    @Test fun `la promotion pose la piece demandee`() {
        val fen = "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"
        val queen = DuckChessFen.applied(
            DuckChessRules.Move(Square("a7"), Square("a8"), Piece.Kind.queen), position(fen),
        )
        assertEquals(Piece.Kind.queen, queen.piece(Square("a8"))?.kind)
        val knight = DuckChessFen.applied(
            DuckChessRules.Move(Square("a7"), Square("a8"), Piece.Kind.knight), position(fen),
        )
        assertEquals(Piece.Kind.knight, knight.piece(Square("a8"))?.kind)
    }

    /**
     * Le canard ne figure PAS dans la FEN : c'est ce qui permet de rendre la
     * position à `chesskit` et de réutiliser tout l'affichage sans le toucher.
     */
    @Test fun `la FEN ecrite reste une FEN ordinaire`() {
        val after = DuckChessFen.applied(DuckChessRules.Move(Square("e2"), Square("e4")), position(start))
        assertEquals("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1", after.fen)
    }

    @Test fun `la centralite prefere le centre aux coins`() {
        assertTrue(DuckChessEngine.centrality(Square("d4")) > DuckChessEngine.centrality(Square("a1")))
        assertTrue(DuckChessEngine.centrality(Square("e5")) > DuckChessEngine.centrality(Square("h8")))
        assertEquals(DuckChessEngine.centrality(Square("d4")), DuckChessEngine.centrality(Square("e5")))
    }
}
