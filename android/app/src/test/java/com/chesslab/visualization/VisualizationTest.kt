package com.chesslab.visualization

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/** Pendant de `VisualizationTests` (iOS) : la règle de Visualisation, sans écran. */
class VisualizationTest {
    private fun sq(n: String) = VSquare.parse(n)!!

    @Test fun `couleur des cases`() {
        assertFalse(sq("a1").isLight)
        assertTrue(sq("h1").isLight)
        assertFalse(sq("h8").isLight)
        assertTrue(sq("e4").isLight)
        assertEquals(VAnswer.Dark, VisualizationGenerator.squareColor(sq("e5")).answer)
    }

    @Test fun `la notation fait l'aller-retour`() {
        VSquare.all.forEach { assertEquals(it, VSquare.parse(it.notation)) }
        assertNull(VSquare.parse("i1"))
        assertNull(VSquare.parse("a9"))
    }

    @Test fun `trajets du cavalier`() {
        assertEquals(1, KnightDistance.between(sq("g1"), sq("f3")))
        assertEquals(2, KnightDistance.between(sq("g1"), sq("e5")))
        assertEquals(4, KnightDistance.between(sq("a1"), sq("b2")))
        assertEquals(6, KnightDistance.between(sq("a1"), sq("h8")))
        val longest = VSquare.all.maxOf { a -> VSquare.all.maxOf { KnightDistance.between(a, it) } }
        assertEquals(6, longest)
    }

    @Test fun `les diagonales, comme iOS`() {
        assertEquals(8, VDiagonal.named("a1–h8")?.squares?.size)
        assertEquals(8, VDiagonal.named("h1–a8")?.squares?.size)
        assertEquals(6, VDiagonal.named("f1–a6")?.squares?.size)
        assertEquals(22, VDiagonal.all.size)
        assertTrue(sq("c1").sharesDiagonal(sq("h6")))
        assertFalse(sq("c1").sharesDiagonal(sq("h5")))
    }

    @Test fun `chaque question est juste et propose sa reponse`() {
        val rng = Random(42)
        for (kind in VisualizationKind.entries) repeat(200) {
            val q = VisualizationGenerator.question(kind, rng)
            assertEquals(kind, q.kind)
            if (kind != VisualizationKind.findSquare) {
                assertTrue("$kind : réponse proposée", q.answer in q.choices)
                assertEquals("$kind : pas de doublon", q.choices.size, q.choices.toSet().size)
            }
            when (kind) {
                VisualizationKind.squareColor -> assertEquals(if (q.squares[0].isLight) VAnswer.Light else VAnswer.Dark, q.answer)
                VisualizationKind.sameDiagonal ->
                    assertEquals(if (q.squares[0].sharesDiagonal(q.squares[1])) VAnswer.Yes else VAnswer.No, q.answer)
                VisualizationKind.lineIntersection -> {
                    assertTrue(q.line!!.contains(q.squares[0]) && q.squares[0] in q.diagonal!!.squares)
                    assertEquals(4, q.choices.size)
                }
                VisualizationKind.knightDistance -> {
                    assertTrue(q.squares[0] != q.squares[1])
                    assertEquals(VAnswer.Number(KnightDistance.between(q.squares[0], q.squares[1])), q.answer)
                }
                VisualizationKind.nameSquare -> assertEquals(4, q.choices.size)
                VisualizationKind.findSquare -> assertEquals(VAnswer.Square(q.squares[0]), q.answer)
                VisualizationKind.pathCheck -> {
                    assertEquals(4, q.moves.size)
                    val legal = VisualizationGenerator.isLegalPath(q.moves[0].kind, q.moves.map { it.square })
                    assertEquals(if (legal) VAnswer.Yes else VAnswer.No, q.answer)
                }
                VisualizationKind.attackAfter -> {
                    assertEquals(3, q.moves.size)
                    assertTrue(VisualizationGenerator.isLegalPath(q.moves[0].kind, q.moves.map { it.square }))
                    val hit = q.squares[0] in VisualizationAttacks.from(q.moves[0].kind, q.moves.last().square)
                    assertEquals(if (hit) VAnswer.Yes else VAnswer.No, q.answer)
                }
                VisualizationKind.twoPieces -> {
                    assertTrue(q.pieces.size == 2 && q.moves.size == 3)
                    assertTrue(q.pieces[0].kind != q.pieces[1].kind)
                }
                VisualizationKind.isCheck, VisualizationKind.squareAttacked -> {
                    assertEquals(2, q.pieces.count { it.kind == VPieceKind.king })
                    assertEquals(q.pieces.size, q.pieces.map { it.square }.toSet().size)
                    assertTrue(q.pieces.filter { it.kind == VPieceKind.pawn }.all { it.square.rank in 1..6 })
                }
                VisualizationKind.hangingPiece -> {
                    val hung = VisualizationGenerator.hanging(q.pieces)
                    assertTrue(hung.size <= 1)
                    assertEquals(hung.firstOrNull()?.let { VAnswer.Square(it.square) } ?: VAnswer.Option("none"), q.answer)
                }
            }
        }
    }

    @Test fun `meme diagonale equilibree et jamais triviale`() {
        val rng = Random(7)
        var yes = 0
        repeat(400) {
            val q = VisualizationGenerator.question(VisualizationKind.sameDiagonal, rng)
            if (q.answer == VAnswer.Yes) {
                yes++
                assertTrue(kotlin.math.abs(q.squares[0].file - q.squares[1].file) >= 2)
            }
        }
        assertTrue("à peu près autant de oui que de non : $yes", yes in 140..260)
    }

    @Test fun `une question ratee se repose a l'identique`() {
        val rng = Random(3)
        for (kind in VisualizationKind.entries) {
            val q = VisualizationGenerator.question(kind, rng)
            val again = VisualizationGenerator.question(q.reviewKey, rng)
            assertEquals(q.reviewKey, again?.reviewKey)
            assertEquals(q.answer, again?.answer)
        }
        assertNull(VisualizationGenerator.question("n'importe quoi", rng))
    }

    @Test fun `une erreur revient jusqu'a deux reussites, et se relit`() {
        var stats = VisualizationStats()
        val q = VisualizationGenerator.squareColor(sq("c6"))
        stats = stats.record(q, false)
        assertEquals(listOf(q.reviewKey), stats.reviewKeys(listOf(VisualizationKind.squareColor)))
        assertTrue(stats.reviewKeys(listOf(VisualizationKind.knightDistance)).isEmpty())
        stats = stats.record(q, true)
        assertTrue(stats.reviewKeys(listOf(VisualizationKind.squareColor)).isNotEmpty())
        assertEquals(stats, VisualizationStats.decode(stats.encode()), "relu tel quel")
        stats = stats.record(q, true)
        assertTrue(stats.reviewKeys(listOf(VisualizationKind.squareColor)).isEmpty())
        assertEquals(3, stats.attempts(VisualizationStep.squares))
        assertEquals(67, stats.accuracy(VisualizationStep.squares))
        assertNull(stats.accuracy(VisualizationStep.lines))
        // Une clé de croisement contient « : » et « – » : elle survit au texte.
        val crossing = VisualizationGenerator.lineIntersection(VLine.File(3), VDiagonal.named("a1–h8")!!, Random(1))!!
        val withCrossing = VisualizationStats().record(crossing, false)
        assertEquals(withCrossing, VisualizationStats.decode(withCrossing.encode()))
    }

    @Test fun `le tirage ressert les erreurs et ne repete jamais deux fois de suite`() {
        val rng = Random(11)
        val missed = VisualizationGenerator.squareColor(sq("b7"))
        val stats = VisualizationStats().record(missed, false)
        var served = 0
        var previous: VQuestion? = null
        val kinds = listOf(VisualizationKind.squareColor, VisualizationKind.knightDistance)
        repeat(300) {
            val q = VisualizationDrawer.next(kinds, stats, previous, rng)
            assertTrue(q.reviewKey != previous?.reviewKey)
            assertTrue(q.kind in kinds)
            if (q.reviewKey == missed.reviewKey) served++
            previous = q
        }
        assertTrue("la question ratée revient souvent : $served", served > 30)
    }

    // Lot 2 — mêmes cas qu'iOS

    @Test fun `une ligne s'arrete sur la premiere case occupee`() {
        val rook = VisualizationAttacks.from(VPieceKind.rook, sq("a1"), occupied = setOf(sq("a4")))
        assertTrue(sq("a4") in rook && sq("a5") !in rook && sq("h1") in rook)
        assertEquals(setOf(sq("d5"), sq("f5")), VisualizationAttacks.from(VPieceKind.pawn, sq("e4"), white = true))
        assertEquals(setOf(sq("d4"), sq("f4")), VisualizationAttacks.from(VPieceKind.pawn, sq("e5"), white = false))
        assertEquals(setOf(sq("b3"), sq("c2")), VisualizationAttacks.from(VPieceKind.knight, sq("a1")))
    }

    @Test fun `deux pieces se masquent l'une l'autre`() {
        val starts = listOf(VPiece.white(VPieceKind.rook, sq("a1")), VPiece.white(VPieceKind.bishop, sq("c3")))
        val moves = listOf(VPiece.white(VPieceKind.rook, sq("a4")), VPiece.white(VPieceKind.bishop, sq("a5")), VPiece.white(VPieceKind.rook, sq("a3")))
        assertEquals(VAnswer.Option("none"), VisualizationGenerator.twoPieces(starts, moves, sq("a6")).answer)
        assertEquals(VAnswer.Option("first"), VisualizationGenerator.twoPieces(starts, moves, sq("a4")).answer)
        assertEquals(VAnswer.Option("second"), VisualizationGenerator.twoPieces(starts, moves, sq("b6")).answer)
        assertEquals(VAnswer.Option("both"), VisualizationGenerator.twoPieces(starts, moves, sq("c3")).answer)
    }

    @Test fun `les reponses du lot 2 sont equilibrees`() {
        val rng = Random(21)
        val counts = mutableMapOf<VisualizationKind, MutableMap<VAnswer, Int>>()
        for (kind in listOf(VisualizationKind.pathCheck, VisualizationKind.attackAfter, VisualizationKind.twoPieces,
            VisualizationKind.isCheck, VisualizationKind.squareAttacked)) repeat(120) {
            val answer = VisualizationGenerator.question(kind, rng).answer
            counts.getOrPut(kind) { mutableMapOf() }.merge(answer, 1, Int::plus)
        }
        for (kind in listOf(VisualizationKind.pathCheck, VisualizationKind.attackAfter, VisualizationKind.isCheck, VisualizationKind.squareAttacked)) {
            assertTrue("$kind : ${counts[kind]}", (counts[kind]?.get(VAnswer.Yes) ?: 0) in 30..90)
        }
        assertEquals(4, counts[VisualizationKind.twoPieces]?.size, "les quatre réponses sortent")
    }

    @Test fun `une position se relit de sa cle`() {
        val position = VPiece.parse("Kg1,Qd1,Rf1,kg8,rd8,bc5")!!
        assertEquals(VAnswer.No, VisualizationGenerator.isCheck(position).answer)
        assertEquals(VAnswer.Yes, VisualizationGenerator.isCheck(VPiece.parse("Kg1,Qh7,kg8")!!).answer)
        assertNull(VPiece.parse("Kg1,Xz9"))
        assertTrue(VPiece.white(VPieceKind.knight, sq("g1")).figurine.startsWith("♘"))
    }

    @Test fun `le chrono grandit avec la marche`() {
        assertEquals(5, VisualizationKind.squareColor.seconds(5))
        assertEquals(10, VisualizationKind.knightDistance.seconds(5))
        assertEquals(15, VisualizationKind.twoPieces.seconds(5))
        assertEquals(20, VisualizationKind.hangingPiece.seconds(5))
        assertEquals(40, VisualizationKind.isCheck.seconds(10))
    }

    @Test fun `les series chronometrees durent une ou deux minutes`() {
        assertEquals(60_000L, VisualizationLength.oneMinute.durationMs)
        assertEquals(120_000L, VisualizationLength.twoMinutes.durationMs)
        assertNull(VisualizationLength.ten.durationMs)
        assertNull(VisualizationLength.twoMinutes.questionCount)
    }

    private fun assertEquals(expected: Any?, actual: Any?, message: String) = assertEquals(message, expected, actual)
}
