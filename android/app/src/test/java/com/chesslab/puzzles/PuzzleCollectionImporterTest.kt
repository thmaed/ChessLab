package com.chesslab.puzzles

import com.chesslab.puzzles.PuzzleCollectionImporter.Skip
import com.chesslab.puzzles.PuzzleCollectionImporter.SkipReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * L'import d'un fichier PGN de puzzles : ce qu'il lit, ce qu'il refuse et pourquoi.
 * Pendant de `PuzzleCollectionImporterTests` (iOS), test pour test.
 */
class PuzzleCollectionImporterTest {
    /** Le mat en deux du couloir : Te8+ Txe8 Txe8#. */
    private val corridorFen = "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    private fun game(moves: String, fen: String? = corridorFen, extra: String = ""): String {
        var text = ""
        if (fen != null) text += "[SetUp \"1\"]\n[FEN \"$fen\"]\n"
        return text + extra + "\n$moves\n"
    }

    @Test fun `lit la solution sur la ligne principale`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Rxe8# 1-0"))
        assertEquals(1, result.puzzles.size)
        assertEquals(corridorFen, result.puzzles[0].fen)
        assertEquals(listOf("e3e8", "a8e8", "e1e8"), result.puzzles[0].solution)
        assertEquals("checkmate", result.puzzles[0].theme)
        assertTrue(result.skipped.isEmpty())
    }

    @Test fun `une riposte adverse en queue de ligne est retiree`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8"))
        assertEquals(listOf("e3e8"), result.puzzles[0].solution)
    }

    @Test fun `un seul coup est un puzzle valide`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8#", fen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1"))
        assertEquals(listOf(listOf("e1e8")), result.puzzles.map { it.solution })
    }

    @Test fun `ignore variantes, commentaires, annotations et NAG`() {
        val moves = "1. Re8+! {the only move} (1. Rd3 Rxa2) 1... Rxe8 \$1 2. Rxe8#!! 1-0"
        val result = PuzzleCollectionImporter.parse(game(moves))
        assertEquals(listOf(listOf("e3e8", "a8e8", "e1e8")), result.puzzles.map { it.solution })
    }

    @Test fun `une promotion garde sa piece`() {
        val result = PuzzleCollectionImporter.parse(game("1. e8=N", fen = "8/4P2k/8/8/8/8/8/K7 w - - 0 1"))
        assertEquals(listOf(listOf("e7e8n")), result.puzzles.map { it.solution })
    }

    @Test fun `refuse une partie sans FEN et le dit`() {
        val result = PuzzleCollectionImporter.parse(game("1. e4 e5 2. Nf3", fen = null, extra = "[Event \"x\"]\n"))
        assertTrue(result.puzzles.isEmpty())
        assertEquals(listOf(Skip(1, SkipReason.MissingFen)), result.skipped)
    }

    @Test fun `refuse un FEN illisible`() {
        val result = PuzzleCollectionImporter.parse(game("1. e4", fen = "not a fen"))
        assertEquals(listOf<SkipReason>(SkipReason.InvalidFen), result.skipped.map { it.reason })
    }

    @Test fun `refuse une partie sans coups`() {
        val result = PuzzleCollectionImporter.parse(game("*"))
        assertEquals(listOf<SkipReason>(SkipReason.NoMoves), result.skipped.map { it.reason })
    }

    @Test fun `un coup illegal ecarte toute la partie`() {
        // Rien n'est deviné : une solution tronquée serait un autre puzzle.
        val result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Qh5"))
        assertTrue(result.puzzles.isEmpty())
        assertEquals(listOf<SkipReason>(SkipReason.IllegalMove("Qh5")), result.skipped.map { it.reason })
    }

    @Test fun `une mauvaise partie n'arrete pas les autres`() {
        val text = game("1. Re8+ Rxe8 2. Rxe8#") + "\n" + game("1. Kd4") + "\n" +
            game("1. Re8#", fen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")
        val result = PuzzleCollectionImporter.parse(text)
        assertEquals(3, result.gameCount)
        assertEquals(2, result.puzzles.size)
        assertEquals(listOf(Skip(2, SkipReason.IllegalMove("Kd4"))), result.skipped)
    }

    @Test fun `decoupe les parties sans en-tete Event`() {
        // Un fichier de puzzles n'a souvent que [FEN] : pas de [Event] pour couper.
        val text = game("1. Re8+ Rxe8 2. Rxe8#") + game("1. Re8#", fen = "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")
        assertEquals(2, PuzzleCollectionImporter.splitIntoGames(text).size)
    }

    @Test fun `une ligne de commentaire commencant par un crochet ne coupe pas une partie`() {
        val moves = "1. Re8+ {\n[%clk 0:03:00]\n} Rxe8 2. Rxe8#"
        assertEquals(1, PuzzleCollectionImporter.splitIntoGames(game(moves)).size)
    }

    @Test fun `compte une fois les puzzles repetes`() {
        val one = game("1. Re8+ Rxe8 2. Rxe8#")
        val result = PuzzleCollectionImporter.parse(one + "\n" + one)
        assertEquals(1, result.puzzles.size)
        assertEquals(1, result.duplicates)
    }

    @Test fun `tolere les fins de ligne Windows et un BOM`() {
        val text = "﻿" + game("1. Re8+ Rxe8 2. Rxe8#").replace("\n", "\r\n")
        assertEquals(1, PuzzleCollectionImporter.parse(text).puzzles.size)
    }

    @Test fun `un fichier vide ne donne rien`() {
        val result = PuzzleCollectionImporter.parse("  \n\n")
        assertEquals(0, result.gameCount)
        assertTrue(result.puzzles.isEmpty())
    }

    /** Le fichier de Ron : environ mille puzzles, 400 Ko. Il doit se lire vite. */
    @Test fun `mille puzzles se lisent vite`() {
        val text = (0 until 1000).joinToString("\n") { index ->
            game("1. Re8+ Rxe8 2. Rxe8#", fen = "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 ${index + 1}")
        }
        val started = System.currentTimeMillis()
        val result = PuzzleCollectionImporter.parse(text)
        assertEquals(1000, result.puzzles.size)
        assertTrue("trop lent : ${System.currentTimeMillis() - started} ms", System.currentTimeMillis() - started < 10_000)
    }

    /**
     * Le programme Woodpecker d'une collection de mille puzzles reste de taille
     * raisonnable, même après sept cycles — sur Android il tient dans une colonne
     * SQLite, mais le même plan voyage dans le `.clab`.
     */
    @Test fun `le plan Woodpecker de mille puzzles reste petit`() {
        val items = (0 until 1000).map {
            WoodpeckerPlan.Item("r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 ${it + 1}", listOf("e3e8", "a8e8", "e1e8"), "checkmate", "endgame", 0)
        }
        var plan = WoodpeckerPlan.start(items, now = 0)!!
        repeat(7) {
            repeat(1000) { plan = plan.record(true, 12.5, now = 0) }
            if (it < 6) plan = plan.startNextCycle(now = 0)
        }
        val size = plan.toJson().length
        assertTrue("plan de $size octets", size < 800_000)
    }

    @Test fun `les collections se trient en ordre naturel`() {
        val sorted = listOf("Mats 10", "mats 2", "Clouages", "Mats 1").sortedWith { a, b -> PuzzleCollectionStore.naturalCompare(a, b) }
        assertEquals(listOf("Clouages", "Mats 1", "mats 2", "Mats 10"), sorted)
    }
}
