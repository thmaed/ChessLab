package com.chesslab.maia

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * L'encodeur, prouvé BIT À BIT contre les fixtures de l'app iOS.
 *
 * `ChessLabTests/Fixtures_maia3.json` contient, pour 56 parties, l'encodage
 * attendu : 64 cases × 96 bits, en hexadécimal. C'est la même référence qui
 * prouve l'encodeur Swift — les deux plateformes sont donc comparées à un
 * étalon commun, et non l'une à l'autre.
 *
 * Sur JVM, sans émulateur : l'encodeur ne dépend que des règles du jeu.
 */
class MaiaEncoderTest {

    private val fixtures = File("../../ChessLabTests/Fixtures_maia3.json")

    @Test fun everyFixtureEncodesExactly() {
        assertTrue(fixtures.exists(), "fixtures introuvables : ${fixtures.absolutePath}")
        val text = fixtures.readText()

        val cases = Regex(
            "\"startFEN\"\\s*:\\s*\"([^\"]+)\"\\s*,\\s*\"moves\"\\s*:\\s*\\[([^\\]]*)]" +
                "[^\\[]*?\"tokens\"\\s*:\\s*\\[([^\\]]*)]"
        ).findAll(text).toList()

        assertTrue(cases.size >= 50, "cas attendus : au moins 50, trouvés ${cases.size}")

        val failures = mutableListOf<String>()
        var checked = 0

        for (match in cases) {
            val startFen = match.groupValues[1]
            val lans = Regex("\"([a-h][1-8][a-h][1-8][qrbn]?)\"")
                .findAll(match.groupValues[2]).map { it.groupValues[1] }.toList()
            val rows = Regex("\"([0-9a-f]{24})\"")
                .findAll(match.groupValues[3]).map { it.groupValues[1] }.toList()
            if (rows.size != 64) { failures += "tokens malformés ($startFen)"; continue }

            val start = Position.fromFen(startFen) ?: continue
            val board = Board(start.copy())
            val history = mutableListOf(start.copy())
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
                history += board.position.copy()
            }

            val tensor = MaiaEncoder.tokens(history)
            checked++

            for (square in 0 until 64) {
                val bits = java.math.BigInteger(rows[square], 16)
                for (feature in 0 until 96) {
                    val expected = if (bits.testBit(95 - feature)) 1f else 0f
                    val actual = tensor[square * MaiaEncoder.FEATURES_PER_SQUARE + feature]
                    if (expected != actual && failures.size < 5) {
                        failures += "case $square, colonne $feature : attendu $expected, obtenu $actual " +
                            "(fen $startFen, ${lans.size} coups)"
                    }
                }
            }
            // la 97e colonne — temps de réflexion — reste nulle à l'inférence
            for (square in 0 until 64) {
                val last = tensor[square * MaiaEncoder.FEATURES_PER_SQUARE + 96]
                if (last != 0f && failures.size < 5) failures += "97e colonne non nulle, case $square"
            }
        }

        println("encodeur Maia : $checked cas vérifiés, ${failures.size} écart(s)")
        if (failures.isNotEmpty()) fail("${failures.size} écart(s) :\n" + failures.joinToString("\n"))
    }
}
