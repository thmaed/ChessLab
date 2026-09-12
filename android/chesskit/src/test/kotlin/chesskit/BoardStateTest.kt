package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * L'état d'un plateau CONSTRUIT depuis une position, sans qu'aucun coup n'y ait
 * été joué. C'est le cas de tout écran qui affiche une position venue d'une FEN
 * ou d'un PGN rejoué.
 */
class BoardStateTest {

    @Test fun `un mat posé sur le plateau est reconnu`() {
        // Mat du couloir : roi noir en g8 étouffé, tour blanche en e8.
        val board = Board(Position.fromFen("4R1k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1")!!)
        val state = board.state
        assertTrue(state is Board.State.Checkmate, "état = $state")
        assertEquals(Piece.Color.black, (state as Board.State.Checkmate).color)
    }

    @Test fun `un échec posé sur le plateau nomme le bon roi`() {
        val board = Board(Position.fromFen("6k1/5pp1/7p/8/8/8/5PPP/4R1K1 b - - 0 1")!!)
        assertEquals(Board.State.Active, board.state)

        val checking = Board(Position.fromFen("6k1/5p2/6p1/7p/8/8/5PPP/4R1K1 b - - 0 1")!!)
        assertEquals(Board.State.Active, checking.state)

        // Tour en e8 : échec au roi noir, qui a une case de fuite.
        val inCheck = Board(Position.fromFen("4R1k1/5p2/6p1/7p/8/8/5PPP/6K1 b - - 0 1")!!)
        val state = inCheck.state
        assertTrue(state is Board.State.Check, "état = $state")
        assertEquals(Piece.Color.black, (state as Board.State.Check).color)
    }

    @Test fun `le pat posé sur le plateau est une nulle`() {
        val board = Board(Position.fromFen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")!!)
        val state = board.state
        assertTrue(state is Board.State.Draw, "état = $state")
        assertEquals(Board.State.DrawReason.stalemate, (state as Board.State.Draw).reason)
    }

    @Test fun `la position initiale reste active`() {
        assertEquals(Board.State.Active, Board().state)
    }
}

/**
 * Le plateau ne doit RIEN écrire chez celui qui lui passe une position.
 *
 * L'original Swift est une `struct`, donc copiée d'office ; le port, lui, a dû
 * le faire exprès. Sans ça, rejouer une variante sur une position empruntée
 * réécrit la partie de l'appelant — et l'analyse classait des coups sur des
 * positions qui n'étaient pas les leurs.
 */
class BoardIsolationTest {

    @Test fun `jouer sur le plateau ne touche pas la position passée`() {
        val original = Position.standard
        val before = original.fen

        val board = Board(original)
        board.move(Square("e2"), Square("e4"))

        assertEquals(before, original.fen)
        assertTrue(board.position.fen != before)
    }

    @Test fun `update copie aussi`() {
        val position = Position.fromFen("6k1/8/8/8/8/8/8/6KQ w - - 0 1")!!
        val before = position.fen

        val board = Board()
        board.update(position)
        board.move(Square("h1"), Square("h5"))

        assertEquals(before, position.fen)
    }

    @Test fun `rejouer une longue variante ne bouge pas l'originale`() {
        val position = Position.standard
        val before = position.fen
        val board = Board(position)
        listOf("e2" to "e4", "e7" to "e5", "g1" to "f3", "b8" to "c6").forEach { (from, to) ->
            board.move(Square(from), Square(to))
        }
        assertEquals(before, position.fen)
    }
}
