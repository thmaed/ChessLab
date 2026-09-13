package com.chesslab.courses

import chesskit.Board
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * Import d'un répertoire PGN dans le graphe indexé par FEN — les cas
 * d'`OpeningPGNImporterTests.swift`, un à un.
 *
 * Le test central est « les variantes deviennent des branches » : un
 * répertoire n'est pas une partie, c'est un arbre, et tout l'intérêt de la
 * fonctionnalité tient à ce que les parenthèses du PGN deviennent de vraies
 * alternatives jouables — pas à ce qu'on retienne la ligne principale en
 * jetant le reste.
 */
class OpeningPgnImporterTest {

    private fun import(pgn: String, name: String = "Test", side: String = "white") =
        OpeningPgnImporter.course(pgn, name, side, "user-test", fallbackName = "Répertoire importé") { "Chapitre $it" }

    private fun keyAfter(vararg moves: Pair<String, String>): String {
        val board = Board(Position.standard)
        for ((from, to) in moves) requireNotNull(board.move(Square(from), Square(to)))
        return CourseRepository.key(board.position)
    }

    @Test fun `une ligne simple devient une chaine`() {
        val result = import("1. e4 e5 2. Nf3 Nc6 *")
        val course = result.course
        assertTrue(OpeningCourseValidator.validate(course).isEmpty())
        assertEquals(5, course.positions.size)          // départ + 4 coups
        assertEquals(CourseRepository.key(Position.standard), course.rootFEN)
        assertEquals(listOf("e4"), course.moves(course.rootFEN).map { it.san })
        assertEquals(0, result.skippedMoves)
    }

    @Test fun `les variantes deviennent des branches`() {
        val course = import("1. e4 e5 (1... c5 2. Nf3) (1... e6 2. d4) 2. Nf3 *").course
        assertTrue(OpeningCourseValidator.validate(course).isEmpty())
        val afterE4 = keyAfter("e2" to "e4")
        val replies = course.moves(afterE4)
        assertEquals(setOf("e5", "c5", "e6"), replies.map { it.san }.toSet())
        // La ligne principale garde son rang : c'est elle que le lecteur
        // propose en « coup à venir ».
        assertEquals("mainLine", replies.first { it.san == "e5" }.role)
        assertEquals("sideline", replies.first { it.san == "c5" }.role)
    }

    @Test fun `les transpositions fusionnent en un seul noeud`() {
        // La variante remplace le coup qu'elle SUIT : ici 1…e6 au lieu de
        // 1…Cf6. Les deux ordres arrivent sur la même position après 2 coups.
        val course = import("1. d4 Nf6 (1... e6 2. c4 Nf6) 2. c4 e6 *").course
        assertTrue(OpeningCourseValidator.validate(course).isEmpty())
        val tabiya = keyAfter("d2" to "d4", "g8" to "f6", "c2" to "c4", "e7" to "e6")
        assertTrue(tabiya in course.positions)
        // UN seul nœud, atteint par DEUX arêtes distinctes : c'est ce qui
        // distingue le graphe d'un empilement d'arbres — et ce qui fait qu'on
        // ne réapprend pas deux fois la même position.
        val incoming = course.positions.values.flatten().filter { it.toFEN == tabiya }
        assertEquals(2, incoming.size)
        assertEquals(setOf("e6", "Nf6"), incoming.map { it.san }.toSet())
    }

    @Test fun `les annotations deviennent des roles`() {
        val course = import("1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?! 4. Nxe5?? Qg5 *").course
        val edges = course.positions.values.flatten()
        assertEquals("inaccuracy", edges.first { it.san == "Nd4" }.role)
        assertEquals("trap", edges.first { it.san == "Nxe5" }.role)
    }

    @Test fun `les commentaires suivent, et s'affichent`() {
        val course = import("1. e4 {Le coup du centre} e5 *").course
        assertEquals("Le coup du centre", course.moves(course.rootFEN).first().comment)
    }

    @Test fun `plusieurs parties deviennent plusieurs chapitres`() {
        val pgn = """
            [Event "Contre 1.e4"]

            1. e4 e5 *

            [Event "Contre 1.d4"]

            1. d4 d5 *
        """.trimIndent()
        val course = import(pgn).course
        assertTrue(OpeningCourseValidator.validate(course).isEmpty())
        assertEquals(listOf("Contre 1.e4", "Contre 1.d4"), course.chapters.map { it.title })
        assertEquals(setOf("e4", "d4"), course.moves(course.rootFEN).map { it.san }.toSet())
    }

    @Test fun `un texte vide est refuse`() {
        try { import("   \n  "); fail("un texte vide devrait être refusé") }
        catch (e: OpeningPgnImporter.ImportException.Empty) { /* attendu */ }
    }

    @Test fun `une partie sans coup est refusee`() {
        try { import("[Event \"Vide\"]\n\n*"); fail("une partie sans coup devrait être refusée") }
        catch (e: OpeningPgnImporter.ImportException) { /* attendu */ }
    }

    @Test fun `le camp etudie est conserve`() {
        assertEquals("black", import("1. e4 c5 *", side = "black").course.side)
    }

    @Test fun `le nom se devine dans le PGN`() {
        assertEquals("Ma Scandinave", OpeningPgnImporter.suggestedName("[Event \"Ma Scandinave: Chapitre 1\"]\n\n1. e4 d5 *"))
        assertEquals("Scandinavian", OpeningPgnImporter.suggestedName("[Event \"x\"]\n[Opening \"Scandinavian\"]\n\n1. e4 d5 *"))
        assertEquals(null, OpeningPgnImporter.suggestedName("[Event \"?\"]\n\n1. e4 *"))
    }

    /** Le validateur lui-même, sur ce qui est LIVRÉ : les 137 cours doivent passer sans une remarque. */
    @Test fun `les cours embarques passent le validateur sans remarque`() {
        val dir = File("../../ChessLab/Resources/openings")
        require(dir.isDirectory)
        var checked = 0
        for (file in dir.listFiles { f -> f.name.endsWith(".json") && f.name != "opening_catalog.json" }!!) {
            val course = CourseRepository.parse(file.readText())
            val issues = OpeningCourseValidator.validate(course)
            assertTrue("${file.name} : ${issues.take(3)}", issues.isEmpty())
            checked++
        }
        assertTrue(checked > 130)
    }

    @Test fun `rejouer un coup rend la cle canonique, promotion comprise`() {
        val fen = "8/P6k/8/8/8/8/8/K7 w - -"
        val landed = OpeningCourseValidator.resultingKey("a7a8q", fen)
        assertNotNull(landed)
        assertTrue(landed!!.startsWith("Q7/7k/"))
        assertEquals(null, OpeningCourseValidator.resultingKey("a7a6", fen))   // un pion ne recule pas
    }
}
