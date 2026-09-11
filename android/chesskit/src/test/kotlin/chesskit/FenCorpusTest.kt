package chesskit

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * L'épreuve qui vaut plus que les tests unitaires : faire l'aller-retour sur
 * TOUTES les positions réelles que l'app embarque déjà.
 *
 * `lichess_puzzles.json` porte plus de cent mille FEN issues de vraies parties
 * — promotions, prises en passant, roques partiels, pendules à 99 demi-coups.
 * Si le parseur et le sérialiseur portés sont fidèles, chacune doit se relire
 * à l'identique.
 */
class FenCorpusTest {

    private val corpus = File("../../ChessLab/Resources/lichess_puzzles.json")

    @Test fun everyRealFenSurvivesARoundTrip() {
        assertTrue(corpus.exists(), "corpus introuvable : ${corpus.absolutePath}")

        val fens = Regex("\"fen\"\\s*:\\s*\"([^\"]+)\"")
            .findAll(corpus.readText())
            .map { it.groupValues[1] }
            .toList()

        assertTrue(fens.size > 10_000, "corpus trop maigre : ${fens.size} positions")

        val failures = mutableListOf<String>()
        var parsed = 0
        for (fen in fens) {
            val position = Position.fromFen(fen)
            if (position == null) {
                if (failures.size < 10) failures += "illisible : $fen"
                continue
            }
            parsed++
            val round = position.fen
            if (round != fen && failures.size < 10) {
                failures += "aller-retour :\n    attendu $fen\n    obtenu  $round"
            }
        }

        println("corpus : ${fens.size} positions, $parsed lues, ${failures.size} écart(s) relevé(s)")
        if (failures.isNotEmpty()) {
            fail("${failures.size} écart(s) sur ${fens.size} positions :\n" + failures.joinToString("\n"))
        }
    }
}
