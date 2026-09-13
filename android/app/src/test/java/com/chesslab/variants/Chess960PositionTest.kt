package com.chesslab.variants

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les 960 positions, comparées UNE PAR UNE au fichier que python-chess a
 * écrit — le même que lit la suite iOS. C'est ce qui rend la numérotation
 * interchangeable avec Lichess et les moteurs : si la 518 n'est pas la partie
 * classique, tout le reste est faux sans que rien ne le dise.
 */
class Chess960PositionTest {

    private val fixture = File("../../ChessLabTests/Fixtures_chess960_starts.json")

    @Test fun `les 960 positions sont celles de python-chess`() {
        require(fixture.exists()) { "fixture introuvable : ${fixture.absolutePath}" }
        val expected = Regex("\"(\\d+)\"\\s*:\\s*\"([^\"]+)\"")
            .findAll(fixture.readText())
            .associate { it.groupValues[1].toInt() to it.groupValues[2] }
        assertEquals(960, expected.size)
        for ((number, fen) in expected) {
            assertEquals("position $number", fen, Chess960Position.startingFen(number))
        }
    }

    @Test fun `la 518 est la partie classique`() {
        assertEquals(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1",
            Chess960Position.startingFen(Chess960Position.classic),
        )
    }

    @Test fun `hors bornes, il n'y a pas de position`() {
        assertNull(Chess960Position.backRank(-1))
        assertNull(Chess960Position.backRank(960))
        assertNull(Chess960Position.startingFen(1000))
    }

    @Test fun `une rangee illegale est refusee`() {
        // Le roi hors des tours.
        assertFalse(Chess960Position.isLegalBackRank("KRRBBNNQ".toCharArray()))
        // Les deux fous sur la même couleur de case : ici en a et en c, toutes
        // deux sombres. (« BB » en a et b serait légal — cases opposées.)
        assertFalse(Chess960Position.isLegalBackRank("BRBKRNNQ".toCharArray()))
        assertTrue("a et b sont de couleurs opposées", Chess960Position.isLegalBackRank("BBRKRNNQ".toCharArray()))
        // Le mauvais jeu de pièces.
        assertFalse(Chess960Position.isLegalBackRank("RNBQKBNP".toCharArray()))
        assertFalse(Chess960Position.isLegalBackRank("RNBQKBN".toCharArray()))
    }

    @Test fun `chaque rangee retrouve son numero`() {
        for (number in listOf(0, 1, 42, 518, 959)) {
            val rank = Chess960Position.backRank(number)!!
            assertTrue(Chess960Position.isLegalBackRank(rank))
            assertEquals(number, Chess960Position.number(rank))
        }
        assertNull(Chess960Position.number("RNBQKBNP".toCharArray()))
    }
}
