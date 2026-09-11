package chesskit

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Le juge de paix de toute génération de coups : compter les feuilles de
 * l'arbre à une profondeur donnée, et comparer aux valeurs publiées.
 *
 * Les tests unitaires de ChessKit vérifient que les coups légaux sont acceptés.
 * Perft vérifie l'inverse aussi — qu'aucun coup illégal ne se glisse et
 * qu'aucun coup légal ne manque. Les positions retenues sont les classiques du
 * domaine : elles concentrent clouages, roques, prises en passant et
 * promotions, exactement ce qu'un portage casse sans le dire.
 */
class PerftTest {

    private fun perft(position: Position, depth: Int): Long {
        if (depth == 0) return 1L

        val board = Board(position)
        val mover = position.sideToMove
        var nodes = 0L

        for (from in position.pieceSet.get(mover).squares) {
            val piece = position.piece(from) ?: continue
            for (to in board.legalMoves(forPieceAt = from)) {
                val isPromotion = piece.kind == Piece.Kind.pawn &&
                    ((to.rank.value == 8 && mover == Piece.Color.white) ||
                        (to.rank.value == 1 && mover == Piece.Color.black))

                if (depth == 1) {
                    // une promotion compte pour quatre coups distincts
                    nodes += if (isPromotion) 4 else 1
                    continue
                }

                if (isPromotion) {
                    for (kind in listOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight)) {
                        val next = Board(position.copy())
                        val move = next.move(pieceAt = from, to = to) ?: continue
                        next.completePromotion(of = move, to = kind)
                        nodes += perft(next.position, depth - 1)
                    }
                } else {
                    val next = Board(position.copy())
                    next.move(pieceAt = from, to = to) ?: continue
                    nodes += perft(next.position, depth - 1)
                }
            }
        }
        return nodes
    }

    private fun check(fen: String, expected: List<Long>, label: String) {
        expected.forEachIndexed { index, value ->
            val depth = index + 1
            assertEquals(value, perft(Position.fromFen(fen)!!, depth), "$label, profondeur $depth")
        }
    }

    @Test fun startingPosition() = check(
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        listOf(20, 400, 8902, 197_281), "position initiale",
    )

    /** « Kiwipete » : roques des deux côtés, clouages, pions doublés. */
    @Test fun kiwipete() = check(
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        listOf(48, 2039, 97_862), "kiwipete",
    )

    /** Finale de tours et pions : prises en passant et échecs à répétition. */
    @Test fun endgameWithEnPassant() = check(
        "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        listOf(14, 191, 2812, 43_238), "finale avec prise en passant",
    )

    /** Promotions multiples, roque noir encore possible. */
    @Test fun promotions() = check(
        "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        listOf(6, 264, 9467), "promotions",
    )

    @Test fun tacticalMiddlegame() = check(
        "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        listOf(44, 1486, 62_379), "milieu de jeu tactique",
    )
}
