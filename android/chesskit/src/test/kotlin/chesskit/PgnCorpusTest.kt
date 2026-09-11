package chesskit

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * Le PGN à l'épreuve du réel : construire une partie à partir d'un puzzle,
 * l'écrire, la relire, et vérifier qu'on retrouve la même suite de coups.
 *
 * C'est exactement ce que fait l'export de l'app. Les positions viennent de
 * vraies parties, avec leurs roques, prises en passant et promotions.
 */
class PgnCorpusTest {

    private val corpus = File("../../ChessLab/Resources/lichess_puzzles.json")

    /** Un puzzle sur cinq : la lecture d'un PGN coûte une analyse par coup. */
    private val stride = 5

    @Test fun everyExportedGameCanBeReadBack() {
        assertTrue(corpus.exists(), "corpus introuvable : ${corpus.absolutePath}")

        val record = Regex("\"fen\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"solutionLANs\"\\s*:\\s*\\[([^\\]]*)]")
        val puzzles = record.findAll(corpus.readText()).toList()

        val failures = mutableListOf<String>()
        var examined = 0
        var movesWritten = 0

        for ((index, match) in puzzles.withIndex()) {
            if (index % stride != 0) continue

            val fen = match.groupValues[1]
            val lans = Regex("\"([a-h][1-8][a-h][1-8][qrbn]?)\"")
                .findAll(match.groupValues[2]).map { it.groupValues[1] }.toList()
            if (lans.isEmpty()) continue

            val start = Position.fromFen(fen) ?: continue
            val board = Board(start.copy())
            val game = Game(start.copy())
            game.tags.setUp = "1"
            game.tags.fen = fen
            game.tags.result = "*"

            var cursor = game.startingIndex
            val expected = mutableListOf<String>()

            for (lan in lans) {
                var move = board.move(pieceAt = Square(lan.substring(0, 2)), to = Square(lan.substring(2, 4)))
                    ?: break
                if (lan.length == 5) {
                    val kind = when (lan[4]) {
                        'q' -> Piece.Kind.queen
                        'r' -> Piece.Kind.rook
                        'b' -> Piece.Kind.bishop
                        else -> Piece.Kind.knight
                    }
                    move = board.completePromotion(of = move, to = kind)
                }
                cursor = game.make(move, from = cursor)
                expected += move.san
                movesWritten++
            }
            if (expected.isEmpty()) continue
            examined++

            val pgn = PgnWriter.convert(game)
            val reread = try {
                PgnParser.parse(pgn)
            } catch (e: PgnException) {
                if (failures.size < 8) failures += "relecture impossible (${e.message}) :\n    $pgn"
                continue
            }

            val actual = reread.moves.indices
                .filter { it.variation == MoveTree.Index.MAIN_VARIATION }
                .sorted()
                .mapNotNull { reread.moves[it]?.san }

            if (actual != expected && failures.size < 8) {
                failures += "suite différente :\n    écrit  $expected\n    relu   $actual\n    pgn    $pgn"
            }
        }

        println("PGN : $examined parties écrites et relues, $movesWritten coups, ${failures.size} écart(s)")
        if (failures.isNotEmpty()) fail("${failures.size} écart(s) :\n" + failures.joinToString("\n"))
    }
}
