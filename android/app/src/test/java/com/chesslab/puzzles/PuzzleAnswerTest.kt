package com.chesslab.puzzles

import chesskit.Piece
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ce qui compte comme une bonne réponse, et ce qui entre dans une séance.
 * Pendant de `PuzzleSessionDrawerTests` côté iOS.
 */
class PuzzleAnswerTest {

    /** Deux mats du couloir : Ta8# et Tb8#. */
    private val backRank = Position.fromFen("7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1")!!

    @Test fun `un autre coup qui mate est accepté`() {
        assertTrue(PuzzleAnswer.deliversMate(backRank, Square("b1"), Square("b8")))
        assertTrue(PuzzleAnswer.deliversMate(backRank, Square("a1"), Square("a8")))
    }

    @Test fun `un coup qui ne mate pas reste faux`() {
        assertFalse(PuzzleAnswer.deliversMate(backRank, Square("b1"), Square("b7")))
    }

    @Test fun `juger un coup ne touche pas la position de l'appelant`() {
        val before = backRank.fen
        PuzzleAnswer.deliversMate(backRank, Square("b1"), Square("b8"))
        assertEquals(before, backRank.fen)
    }

    @Test fun `une promotion n'est jugée qu'une fois la pièce choisie`() {
        // a8=D# (le roi blanc tient g7 et h7) ; a8=C ne donne même pas échec.
        val promotion = Position.fromFen("7k/P7/6K1/8/8/8/8/8 w - - 0 1")!!
        assertFalse(PuzzleAnswer.deliversMate(promotion, Square("a7"), Square("a8")))
        assertTrue(PuzzleAnswer.deliversMate(promotion, Square("a7"), Square("a8"), Piece.Kind.queen))
        assertFalse(PuzzleAnswer.deliversMate(promotion, Square("a7"), Square("a8"), Piece.Kind.knight))
    }

    private fun puzzle(rating: Int, theme: String = "fork", phase: String? = "middlegame") =
        Puzzle(id = "p", fen = backRank.fen, solution = listOf("a1a8"), theme = theme, rating = rating, phase = phase)

    @Test fun `un niveau choisi exclut les puzzles maison, qui n'ont pas de cote`() {
        val beginner = PuzzleFilter(difficulty = DifficultyTier.beginner)
        assertFalse(PuzzleAnswer.accepts(puzzle(rating = 0), beginner, isOwn = true))
        assertTrue(PuzzleAnswer.accepts(puzzle(rating = 900), beginner, isOwn = false))
        assertFalse(PuzzleAnswer.accepts(puzzle(rating = 1700), beginner, isOwn = false))
    }

    @Test fun `sans niveau, thème et phase suffisent`() {
        val forks = PuzzleFilter(theme = PuzzleThemeKind.fork)
        assertTrue(PuzzleAnswer.accepts(puzzle(rating = 0), forks, isOwn = true))
        assertFalse(PuzzleAnswer.accepts(puzzle(rating = 0, theme = "pin"), forks, isOwn = true))
        assertFalse(PuzzleAnswer.accepts(puzzle(rating = 1500), PuzzleFilter(phase = GamePhase.endgame), isOwn = false))
    }

    @Test fun `provenance et ratés comptent comme des filtres`() {
        assertFalse(PuzzleFilter(source = PuzzleSource.ownGames).isEmpty)
        assertFalse(PuzzleFilter(missedOnly = true).isEmpty)
        assertTrue(PuzzleFilter().isEmpty)
    }
}
