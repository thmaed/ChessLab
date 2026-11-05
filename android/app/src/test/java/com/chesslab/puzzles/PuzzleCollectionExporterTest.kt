package com.chesslab.puzzles

import com.chesslab.puzzles.PuzzleCollectionImporter.SkipReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'export d'une collection : ce qu'il écrit, et que l'import le relit à
 * l'identique. Pendant de `PuzzleCollectionExporterTests` (iOS), test pour test.
 */
class PuzzleCollectionExporterTest {
    private val corridorFen = "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    private fun entry(
        fen: String = corridorFen,
        setup: String? = "a7a6",
        solution: List<String> = listOf("e3e8", "a8e8", "e1e8"),
    ) = PuzzleCollectionExporter.Entry(fen, setup, solution)

    @Test fun `ecrit la solution en SAN avec ses en-tetes`() {
        val pgn = PuzzleCollectionExporter.pgn("Couloirs", listOf(entry()))
        assertTrue(pgn.contains("[Event \"Couloirs\"]"))
        assertTrue(pgn.contains("[FEN \"$corridorFen\"]"))
        assertTrue(pgn.contains("[PuzzleSetup \"a7a6\"]"))
        assertTrue(pgn.contains("23. Re8+ Rxe8 24. Rxe8# *"))
    }

    @Test fun `un premier coup noir est numerote avec des points de suspension`() {
        val pgn = PuzzleCollectionExporter.pgn(
            "N", listOf(entry(fen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 b - - 0 7", setup = null, solution = listOf("g8f8", "e1e8", "f8e8")))
        )
        assertTrue(pgn.contains("7... Kf8 8. Re8+ Kxe8 *"))
        assertTrue(pgn.contains("[PuzzleSetup \"-\"]"))
    }

    @Test fun `une promotion s'ecrit avec sa piece`() {
        val pgn = PuzzleCollectionExporter.pgn(
            "P", listOf(entry(fen = "8/4P3/7k/8/8/8/8/K7 w - - 0 1", setup = null, solution = listOf("e7e8n")))
        )
        assertTrue(pgn.contains("1. e8=N"))
    }

    @Test fun `importer l'export redonne les memes puzzles`() {
        val entries = listOf(
            entry(),
            entry(fen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 b - - 0 7", setup = "h2h3", solution = listOf("g8f8", "e1e8", "f8e8")),
            entry(fen = "8/4P3/7k/8/8/8/8/K7 w - - 0 1", setup = null, solution = listOf("e7e8n")),
        )
        val result = PuzzleCollectionImporter.parse(PuzzleCollectionExporter.pgn("C", entries))
        assertTrue(result.skipped.isEmpty())
        assertEquals(entries.map { it.fen }, result.puzzles.map { it.fen })
        assertEquals(entries.map { it.setup }, result.puzzles.map { it.setup })
        assertEquals(entries.map { it.solution }, result.puzzles.map { it.solution })
    }

    @Test fun `un puzzle qui ne se rejoue pas est laisse de cote`() {
        val pgn = PuzzleCollectionExporter.pgn(
            "X", listOf(entry(solution = listOf("a1a8")), entry(), entry(fen = "n'importe quoi"))
        )
        assertEquals(1, PuzzleCollectionImporter.parse(pgn).puzzles.size)
    }

    @Test fun `une collection vide n'ecrit rien`() {
        assertTrue(PuzzleCollectionExporter.pgn("Vide", emptyList()).isEmpty())
    }

    @Test fun `le nom du fichier est sur pour le systeme de fichiers`() {
        assertEquals("Fourchettes.pgn", PuzzleCollectionExporter.fileName("Fourchettes"))
        assertEquals("a-b-c.pgn", PuzzleCollectionExporter.fileName("a/b:c"))
        assertEquals("ChessLab.pgn", PuzzleCollectionExporter.fileName("  "))
    }

    @Test fun `un fichier sans l'en-tete lit encore le premier coup comme preparation`() {
        val text = "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22\"]\n\n22... a6 23. Re8+ Rxe8 24. Rxe8# *"
        val result = PuzzleCollectionImporter.parse(text)
        assertEquals("a7a6", result.puzzles.first().setup)
        assertEquals(listOf("e3e8", "a8e8", "e1e8"), result.puzzles.first().solution)
    }

    @Test fun `un export sans aucun coup est refuse`() {
        val text = "[FEN \"$corridorFen\"]\n[PuzzleSetup \"a7a6\"]\n\n*"
        assertEquals(listOf<SkipReason>(SkipReason.NoMoves), PuzzleCollectionImporter.parse(text).skipped.map { it.reason })
    }
}
