package chesskit

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * L'épreuve du réel pour la génération de coups : rejouer les solutions des
 * puzzles Lichess que l'app embarque déjà.
 *
 * Perft prouve que le compte des coups est juste ; ceci prouve que des coups
 * issus de VRAIES parties sont acceptés — échecs, clouages, roques, prises en
 * passant et promotions compris, sur des positions que personne n'a choisies
 * pour arranger le portage.
 */
class PuzzleCorpusTest {

    private val corpus = File("../../ChessLab/Resources/lichess_puzzles.json")

    /** Le corpus entier : il passe en quelques secondes, autant tout prendre. */
    private val stride = 1

    @Test fun everyPuzzleSolutionIsPlayable() {
        assertTrue(corpus.exists(), "corpus introuvable : ${corpus.absolutePath}")

        val record = Regex("\"fen\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"solutionLANs\"\\s*:\\s*\\[([^\\]]*)]")
        val puzzles = record.findAll(corpus.readText()).toList()
        assertTrue(puzzles.size > 10_000, "corpus trop maigre : ${puzzles.size} puzzles")

        val failures = mutableListOf<String>()
        var played = 0
        var promotions = 0
        var examined = 0

        for ((index, match) in puzzles.withIndex()) {
            if (index % stride != 0) continue
            examined++

            val fen = match.groupValues[1]
            val lans = Regex("\"([a-h][1-8][a-h][1-8][qrbn]?)\"")
                .findAll(match.groupValues[2])
                .map { it.groupValues[1] }
                .toList()

            val position = Position.fromFen(fen)
            if (position == null) {
                if (failures.size < 10) failures += "FEN illisible : $fen"
                continue
            }

            val board = Board(position)
            for (lan in lans) {
                val start = Square(lan.substring(0, 2))
                val end = Square(lan.substring(2, 4))
                val move = board.move(pieceAt = start, to = end)

                if (move == null) {
                    if (failures.size < 10) failures += "coup refusé $lan dans $fen"
                    break
                }
                played++

                if (lan.length == 5) {
                    val kind = when (lan[4]) {
                        'q' -> Piece.Kind.queen
                        'r' -> Piece.Kind.rook
                        'b' -> Piece.Kind.bishop
                        else -> Piece.Kind.knight
                    }
                    board.completePromotion(of = move, to = kind)
                    promotions++
                }
            }
        }

        println("puzzles : $examined examinés sur ${puzzles.size}, $played coups joués " +
            "(dont $promotions promotions), ${failures.size} refus")

        if (failures.isNotEmpty()) {
            fail("${failures.size} refus :\n" + failures.joinToString("\n"))
        }
    }
}
