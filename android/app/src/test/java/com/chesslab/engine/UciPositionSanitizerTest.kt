package com.chesslab.engine

import chesskit.Board
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pendant de `CastlingRightsTests` / `UCIPositionSanitizerTests` (iOS) — voir [UciPositionSanitizer]. */
class UciPositionSanitizerTest {

    private fun play(lans: List<String>): Board {
        val board = Board(Position.standard)
        for (lan in lans) {
            val move = board.move(Square(lan.substring(0, 2)), Square(lan.substring(2, 4)))
            requireNotNull(move) { "coup illégal $lan" }
        }
        return board
    }

    private fun field(fen: String) = fen.split(" ")[2]

    @Test fun `la partie du joueur - la FEN de la bibliotheque garde un droit perime, le garde-fou le retire`() {
        val lans = ("e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 f5g4 f1e2 g4f3 e2f3 e7e6 e1g1 c6c5 c2c4 c5d4 c4d5 e6d5 d1b3 b7b6 " +
            "b3d5 d8d5 f3d5 f7f6 d5a8 f6e5 c1g5 f8e7 f2f4 h7h6 g5e7 g8e7 f4e5 h8f8 f1f8").split(" ")
        val fen = play(lans).position.fen
        // Si la bibliothèque est corrigée un jour, ce garde-fou devient redondant — pas faux.
        println("FEN de la partie : $fen")
        assertEquals("-", field(UciPositionSanitizer.castlingFixed(fen)))
    }

    @Test fun `un droit de roque sans tour dans le coin est retire`() {
        val fen = "Bn2kR2/p3n1p1/1p5p/4P3/3p4/8/PP4PP/RN4K1 b kq - 0 18"
        assertEquals("Bn2kR2/p3n1p1/1p5p/4P3/3p4/8/PP4PP/RN4K1 b - - 0 18", UciPositionSanitizer.castlingFixed(fen))
    }

    @Test fun `les droits encore valides sont conserves`() {
        val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        assertEquals(start, UciPositionSanitizer.castlingFixed(start))
        assertEquals(
            "r3k3/8/8/8/8/8/8/R3K2R w KQq - 0 1",
            UciPositionSanitizer.castlingFixed("r3k3/8/8/8/8/8/8/R3K2R w KQkq - 0 1"),
        )
    }

    @Test fun `seule la FEN d'une commande position est touchee, et les coups suivent intacts`() {
        assertEquals("go depth 12", UciPositionSanitizer.sanitize("go depth 12"))
        assertEquals("position startpos moves e2e4", UciPositionSanitizer.sanitize("position startpos moves e2e4"))
        assertEquals(
            "position fen 4k3/8/8/8/8/8/8/4K3 w - - 0 1 moves e1e2 e8e7",
            UciPositionSanitizer.sanitize("position fen 4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1 moves e1e2 e8e7"),
        )
    }

    @Test fun `un echiquier qui n'est pas 8 x 8 ou une lettre de colonne ne sont pas touches`() {
        val shredder = "bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1"
        assertEquals(shredder, UciPositionSanitizer.castlingFixed(shredder))
        assertTrue(UciPositionSanitizer.castlingFixed("rnbqkbnrr/9/9/9/9/9/9/9/9/RNBQKBNRR w KQkq - 0 1").contains("KQkq"))
    }
}
