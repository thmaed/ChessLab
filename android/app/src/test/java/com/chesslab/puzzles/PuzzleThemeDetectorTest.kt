package com.chesslab.puzzles

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Le thème déduit d'un puzzle importé. Pendant de `PuzzleThemeDetectorTests` (iOS), test pour
 * test — dont les fourchettes de Ron (08/11/2026) : sur douze « fourchettes » de son fichier,
 * cinq n'en étaient pas.
 */
class PuzzleThemeDetectorTest {
    private fun theme(fen: String, vararg solution: String) =
        PuzzleThemeDetector.detect(fen, solution.toList())

    @Test fun `un mat sur la position finale`() {
        assertEquals("checkmate", theme("6k1/5ppp/8/8/8/8/8/3QK3 w - - 0 1", "d1d8"))
    }

    @Test fun `une pièce capturée sans reprise possible est en prise`() {
        assertEquals("hangingPiece", theme("1k5n/8/8/8/8/8/8/Q3K3 w - - 0 1", "a1h8"))
    }

    @Test fun `un cavalier qui vise la dame et la tour fourche`() {
        assertEquals("fork", theme("3q2k1/2r5/8/2N5/8/8/8/4K3 w - - 0 1", "c5e6"))
    }

    @Test fun `sinon une tactique générique`() {
        assertEquals("tactic", theme("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", "e2e4"))
        assertEquals("tactic", theme("not a fen", "e2e4"))
        assertEquals("tactic", theme("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
    }

    @Test fun `une fourchette demande de vraies cibles`() {
        // Dame b7 prise : elle vise une dame et une tour PROTÉGÉES, et la dame adverse la reprend.
        assertEquals("tactic", theme("r4rk1/pbqn1ppp/1p1bp3/2p1N3/2PPQ3/6P1/PP3PBP/R1B1R1K1 w - - 0 14", "e4b7"))
        // Tour c4 : deux pièces protégées. Pas une fourchette non plus.
        assertEquals("tactic", theme("b1r5/p1r3k1/1p2pq1p/6p1/1PpbPpP1/1Q1P1B1P/2R1NPK1/2R5 w - - 0 31", "c2c4"))
    }

    @Test fun `une fourchette sur des cibles sans défense reste une fourchette`() {
        // Dame b5 : un fou et une tour SANS DÉFENSE.
        assertEquals("fork", theme("4r1k1/1b3p1p/3p2pb/1p1P4/4P3/P2Q2NP/3B1PP1/3q1NK1 w - - 7 29", "d3b5"))
        // Pion c5 : une dame sans défense et un cavalier.
        assertEquals("fork", theme("2r1r1k1/2p1qppp/pp1n4/8/1Q1N4/1P1RP2P/P4PP1/3R2K1 b - - 1 24", "c7c5"))
    }

    @Test fun `le roi en échec compte comme une cible`() {
        // Cavalier d5-c7+ : échec au roi e8 ET attaque de la tour a8.
        assertEquals("fork", theme("r3k3/8/8/3N4/8/8/8/4K3 w - - 0 1", "d5c7"))
    }

    @Test fun `un fourchetteur pris gratuitement ne fourche rien`() {
        // Cavalier e6 vise dame et tour, mais le pion f7 le prend.
        assertEquals("tactic", theme("3q2k1/2r2p2/8/2N5/8/8/8/4K3 w - - 0 1", "c5e6"))
    }

    @Test fun `un echec a la decouverte n'est pas une fourchette`() {
        // Le cavalier e5 démasque le fou a1 (échec au roi h8) et n'attaque, en c6, que la dame d8.
        assertEquals("tactic", theme("3q3k/8/8/4N3/8/8/8/B3K3 w - - 0 1", "e5c6"))
    }
}
