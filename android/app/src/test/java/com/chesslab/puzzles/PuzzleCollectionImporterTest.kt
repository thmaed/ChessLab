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
    /**
     * Le mat en deux du couloir (Te8+ Txe8 Txe8#), précédé de sa PRÉPARATION : le
     * coup adverse a6, joué d'avance. Le FEN du fichier est la position AVANT ce
     * coup ; celle du puzzle est [corridorFen], APRÈS lui.
     */
    private val corridorBefore = "r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22"
    private val corridorFen = "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 23"
    /** Même énoncé, plus court : un mat en un, sa préparation (a6) puis Te8#. */
    private val shortBefore = "6k1/p4ppp/8/8/8/8/5PPP/4R1K1 b - - 0 1"

    private fun game(moves: String, fen: String? = corridorBefore, extra: String = "", setup: String = "22...a6"): String {
        var text = ""
        if (fen != null) text += "[SetUp \"1\"]\n[FEN \"$fen\"]\n"
        return text + extra + "\n$setup $moves\n"
    }

    @Test fun `lit la solution sur la ligne principale`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Rxe8# 1-0"))
        assertEquals(1, result.puzzles.size)
        // Le puzzle commence APRÈS la préparation, qui est gardée à part pour être montrée.
        assertEquals(corridorFen, result.puzzles[0].fen)
        assertEquals("a7a6", result.puzzles[0].setup)
        assertEquals(listOf("e3e8", "a8e8", "e1e8"), result.puzzles[0].solution)
        assertEquals("checkmate", result.puzzles[0].theme)
        assertTrue(result.skipped.isEmpty())
    }

    @Test fun `une riposte adverse en queue de ligne est retiree`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8"))
        assertEquals(listOf("e3e8"), result.puzzles[0].solution)
    }

    @Test fun `un seul coup est un puzzle valide`() {
        val result = PuzzleCollectionImporter.parse(game("1. Re8#", fen = shortBefore))
        assertEquals(listOf(listOf("e1e8")), result.puzzles.map { it.solution })
    }

    @Test fun `ignore variantes, commentaires, annotations et NAG`() {
        val moves = "1. Re8+! {the only move} (1. Rd3 Rxa2) 1... Rxe8 \$1 2. Rxe8#!! 1-0"
        val result = PuzzleCollectionImporter.parse(game(moves))
        assertEquals(listOf(listOf("e3e8", "a8e8", "e1e8")), result.puzzles.map { it.solution })
    }

    @Test fun `une promotion garde sa piece`() {
        val result = PuzzleCollectionImporter.parse(game("1. e8=N", fen = "8/4P3/7k/8/8/8/8/K7 b - - 0 1", setup = "1...Kh7"))
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
        val result = PuzzleCollectionImporter.parse(game("*", setup = ""))
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
            game("1. Re8#", fen = shortBefore)
        val result = PuzzleCollectionImporter.parse(text)
        assertEquals(3, result.gameCount)
        assertEquals(2, result.puzzles.size)
        assertEquals(listOf(Skip(2, SkipReason.IllegalMove("Kd4"))), result.skipped)
    }

    @Test fun `decoupe les parties sans en-tete Event`() {
        // Un fichier de puzzles n'a souvent que [FEN] : pas de [Event] pour couper.
        val text = game("1. Re8+ Rxe8 2. Rxe8#") + game("1. Re8#", fen = shortBefore)
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
            game("1. Re8+ Rxe8 2. Rxe8#", fen = "r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 ${index + 1}")
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

    @Test fun `une partie qui n'a que sa preparation n'a pas de solution`() {
        val result = PuzzleCollectionImporter.parse(game("", setup = "22...a6"))
        assertTrue(result.puzzles.isEmpty())
        assertEquals(listOf<SkipReason>(SkipReason.NoSolution), result.skipped.map { it.reason })
    }

    /**
     * Le fichier REEL de Ron (sept puzzles), tel quel. Son « premier coup » est la
     * préparation : le coup de l'adversaire, joué d'avance — le puzzle commence après.
     * Le sixième n'a que sa préparation (PlyCount 1) : il est écarté, et le dit.
     */
    @Test fun `lit le fichier de Ron`() {
        fun entry(n: Int, fen: String, moves: String) =
            "[Event \"?\"]\n[Site \"ThePuzzle\"]\n[Round \"?\"]\n[White \"$n\"]\n[Result \"*\"]\n" +
                "[FEN \"$fen\"]\n[SetUp \"1\"]\n\n$moves *\n\n"
        val text = entry(1, "rr4k1/p1R2p1p/4pnpn/R2pN3/3P1P2/1q3N2/1P2QPP1/6K1 b - - 0 1", "1...Qxb2 2.Rc8+ Rxc8 3.Qxb2") +
            entry(2, "8/5R2/1p2B1pk/1p1P4/4nP1p/1P2q2P/P5P1/2R4K w - - 0 1", "1.Rg1 Nf2+ 2.Kh2 Qg3#") +
            entry(3, "4Bk2/2r2pp1/1nRqp2p/p6P/P2P4/2P2Q2/5PP1/6K1 b - - 0 1", "1...Rxc6 2.Qxf7#") +
            entry(4, "r4k1Q/p3p3/2p1bbB1/3pp3/1PP5/4q3/P5PP/5R1K b - - 0 1", "1...Bg8 2.Rxf6+ exf6 3.Qxf6+ Bf7 4.Qxf7#") +
            entry(5, "Q7/5pkp/3rn1p1/2qR4/2P4P/6P1/p4P2/6K1 w - - 0 1", "1.Rxc5 Rd1+ 2.Kh2 a1=Q") +
            entry(6, "r1bqk1nr/1ppp1ppp/p1n5/2b1p1N1/2B1P3/3P4/PPP2PPP/RNBQK2R b KQkq - 0 1", "1...Bb4+") +
            entry(7, "r4rk1/1p4b1/3q2B1/p5Bn/P2P2nN/8/1P1Q4/R3R1K1 w - - 0 1", "1.Re4 Rf2 2.Qxf2 Nxf2")
        val result = PuzzleCollectionImporter.parse(text)
        assertEquals(7, result.gameCount)
        assertEquals(listOf(Skip(6, SkipReason.NoSolution)), result.skipped)
        // Les préparations : le coup adverse de chaque énoncé.
        assertEquals(listOf("b3b2", "c1g1", "c7c6", "e6g8", "d5c5", "e1e4"), result.puzzles.map { it.setup })
        // Chaque solution se termine sur un coup de CELUI QUI TROUVE, la riposte comprise au milieu.
        assertEquals(listOf("c7c8", "b8c8", "e2b2"), result.puzzles[0].solution)
        assertEquals(listOf("f3f7"), result.puzzles[2].solution)
        assertEquals(listOf("f1f6", "e7f6", "h8f6", "g8f7", "f6f7"), result.puzzles[3].solution)
        assertEquals(listOf("d6d1", "g1h2", "a2a1q"), result.puzzles[4].solution)
        // Le trait, à l'ouverture du puzzle, est à CELUI QUI TROUVE : l'inverse du FEN du fichier.
        assertTrue(result.puzzles[0].fen.contains(" w "))
        assertTrue(result.puzzles[1].fen.contains(" b "))
    }

    @Test fun `les collections se trient en ordre naturel`() {
        val sorted = listOf("Mats 10", "mats 2", "Clouages", "Mats 1").sortedWith { a, b -> PuzzleCollectionStore.naturalCompare(a, b) }
        assertEquals(listOf("Clouages", "Mats 1", "mats 2", "Mats 10"), sorted)
    }

    /**
     * Retour de Ron (08/11/2026) : sept parties de son fichier de 1100 puzzles étaient
     * écartées côté iOS, toutes avec une CAPTURE désambiguïsée par la colonne
     * (`Rfxd7+`, `Rcxc7`…). ChessKit Swift lisait le départ de travers ; le portage Kotlin
     * l'avait déjà corrigé (`x?` dans `SanParser`). Pendant de
     * `SANDisambiguatedCaptureTests` (iOS).
     */
    @Test fun `les sept parties de Ron, a capture desambiguisee, s'importent`() {
        val games = listOf(
            "1kr5/1pBrp3/8/1N1p2p1/3n1q1p/Q4P2/PPP2P1P/1K4R1 b - - 1 24" to "24...Rcxc7 25.Qa7+ Kc8 26.Qa8#",
            "q1r3k1/2r2pp1/2n1p2p/pR1pPn2/Pp1P4/1P2B3/3Q1PPP/2R1N1K1 b - - 11 29" to "29...Ncxd4 30.Rxc7 Rxc7 31.Bxd4 Nxd4 32.Qxd4",
            "2bkr3/p2n1RQ1/1r5p/1p6/4q3/P7/1PP4P/1K1R4 b - - 1 24" to "24...Rg6 25.Rfxd7+ Bxd7 26.Qxd7#",
            "8/p7/8/2p3r1/3p2bR/1P1P1k2/P1P4K/6R1 w - - 9 38" to "38.Rhxg4 Rh5+ 39.Rh4 Rxh4#",
            "r2q1rk1/5ppp/4pb2/pNn5/Pp1Bn3/1P2P3/4NPPP/2RQ1RK1 b - - 10 18" to "18...e5 19.Bxc5 Qxd1 20.Rfxd1 Nxc5 21.Rxc5",
            "2k2r1r/ppqb2p1/3b3p/2pp4/5NQ1/2NP3P/PPP3P1/R1B2RK1 w - - 1 20" to "20.Nfxd5 Bh2+ 21.Kh1 Rxf1#",
            "3r3k/ppp2pp1/7p/8/1P3bP1/P1BB1r2/2K4P/3R3R w - - 4 28" to "28.Rhf1 Rdxd3 29.Rxd3 Rxf1",
        )
        for ((fen, moves) in games) {
            val result = PuzzleCollectionImporter.parse("[SetUp \"1\"]\n[FEN \"$fen\"]\n\n$moves *\n")
            assertTrue("écartée : $moves — ${result.skipped}", result.skipped.isEmpty())
            assertEquals(moves, 1, result.puzzles.size)
        }
    }
}
