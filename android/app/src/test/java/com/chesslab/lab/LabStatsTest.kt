package com.chesslab.lab

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les chiffres du Laboratoire, repris CAS PAR CAS de `LabStatsTests.swift`.
 *
 * Ce sont eux qu'on lit pour décider si une série a tranché : ils méritent
 * d'être prouvés, et de l'être avec les mêmes cas que l'app iOS — deux
 * formules qui divergeraient donneraient deux verdicts sur la même série.
 */
class LabStatsTest {

    private fun stats(results: List<LabGameResult>, plies: List<Int> = results.map { 40 }) =
        LabStats.of(results, plies)

    private val winA = LabGameResult.winA
    private val draw = LabGameResult.draw
    private val winB = LabGameResult.winB

    @Test fun `le score compte les gains et les demi-nulles`() {
        val s = stats(listOf(winA, winA, draw, winB), listOf(40, 50, 60, 30))
        assertEquals(4, s.games)
        assertEquals(2, s.winsA); assertEquals(1, s.draws); assertEquals(1, s.winsB)
        assertEquals(0.625, s.score, 1e-9)      // (2 + 0.5) / 4
    }

    @Test fun `un score egal donne un ecart Elo nul`() {
        val s = stats(listOf(winA, winA, winB, winB))
        assertEquals(0.5, s.score, 1e-9)
        assertEquals(0.0, s.eloDifference!!, 1e-6)
    }

    @Test fun `gagner davantage donne un Elo positif`() {
        assertTrue(stats(listOf(winA, winA, winA, winB)).eloDifference!! > 0)
    }

    @Test fun `un score parfait n'a pas d'ecart Elo fini`() {
        assertNull(stats(listOf(winA, winA, winA)).eloDifference)
    }

    @Test fun `l'intervalle encadre l'estimation`() {
        val results = List(12) { winA } + List(4) { draw } + List(4) { winB }
        val s = stats(results)
        val elo = s.eloDifference!!
        val (low, high) = s.elo95ConfidenceInterval!!
        assertTrue(low < elo); assertTrue(elo < high)
    }

    @Test fun `l'intervalle ne s'effondre jamais sur un echantillon unanime`() {
        // Deux nulles d'affilée : variance observée EXACTEMENT nulle sans le
        // terme de continuité, donc une fausse certitude à 95 % après deux
        // parties.
        val (low, high) = stats(listOf(draw, draw)).elo95ConfidenceInterval!!
        assertTrue("l'intervalle ne doit jamais être de largeur nulle", low < high)
    }

    @Test fun `l'intervalle se resserre quand les parties unanimes s'accumulent`() {
        val few = stats(List(2) { draw }).elo95ConfidenceInterval!!
        val many = stats(List(50) { draw }).elo95ConfidenceInterval!!
        assertTrue((many.second - many.first) < (few.second - few.first))
    }

    @Test fun `le LOS depasse la moitie quand A gagne davantage`() {
        assertTrue(stats(listOf(winA, winA, winA, winA, winB, draw)).likelihoodOfSuperiority > 0.5)
    }

    @Test fun `le LOS vaut la moitie sans partie decisive`() {
        assertEquals(0.5, stats(listOf(draw, draw, draw)).likelihoodOfSuperiority, 1e-9)
    }

    @Test fun `la moyenne en coups vaut la moitie des demi-coups`() {
        val s = stats(listOf(winA, winB), listOf(40, 60))
        assertEquals(50.0, s.averagePlies, 1e-9)
        assertEquals(25.0, s.averageMoves, 1e-9)
    }

    @Test fun `une serie vide est bien definie`() {
        val s = stats(emptyList(), emptyList())
        assertEquals(0, s.games)
        assertEquals(0.0, s.score, 0.0)
        assertEquals(0.0, s.averageMoves, 0.0)
        assertNull(s.eloDifference)
    }

    @Test fun `la fonction d'erreur est exacte a dix-millionieme pres`() {
        // Le pendant Swift appelle `erf` du C ; Kotlin n'en a pas, d'où une
        // approximation qu'il faut vérifier contre des valeurs connues.
        assertEquals(0.0, LabStats.erf(0.0), 1e-7)
        assertEquals(0.8427007929, LabStats.erf(1.0), 1.5e-7)
        assertEquals(-0.8427007929, LabStats.erf(-1.0), 1.5e-7)
        assertEquals(0.9953222650, LabStats.erf(2.0), 1.5e-7)
        assertEquals(0.5204998778, LabStats.erf(0.5), 1.5e-7)
    }

    @Test fun `la progression a un point par partie et encadre le score`() {
        val games = listOf(
            game(0, aWasWhite = true, result = "1-0", plies = 40),        // winA
            game(1, aWasWhite = true, result = "1/2-1/2", plies = 60),    // draw
            game(2, aWasWhite = false, result = "1-0", plies = 50),       // winB
        )
        val points = LabStats.progression(games)
        assertEquals(3, points.size)
        assertEquals(1, points[0].game)
        assertEquals(100.0, points[0].scorePercent, 1e-9)   // une partie, gagnée par A

        val final = LabStats.of(games.map { it.labResult }, games.map { it.plyCount })
        assertEquals(final.scorePercent, points.last().scorePercent, 1e-9)

        for (point in points) {
            assertTrue(point.ciLow <= point.scorePercent)
            assertTrue(point.scorePercent <= point.ciHigh)
            assertTrue(point.ciLow >= 0.0 && point.ciHigh <= 100.0)
        }
    }

    @Test fun `le resultat se rapporte a A selon la couleur qu'il avait`() {
        assertEquals(winA, game(0, aWasWhite = true, result = "1-0").labResult)
        assertEquals(winB, game(1, aWasWhite = false, result = "1-0").labResult)
        assertEquals(winA, game(2, aWasWhite = false, result = "0-1").labResult)
        assertEquals(draw, game(3, aWasWhite = true, result = "1/2-1/2").labResult)
    }

    private fun game(index: Int, aWasWhite: Boolean, result: String, plies: Int = 40) =
        LabCompletedGame(index, aWasWhite, result, "Mat", plies, "")
}

/** L'export d'une série : mêmes cas que `LabExportTests` côté iOS. */
class LabExportTest {

    private val sample = listOf(
        LabCompletedGame(0, aWasWhite = true, pgnResult = "1-0", reasonLabel = "Mat", plyCount = 41, pgn = "1. e4 e5"),
        LabCompletedGame(1, aWasWhite = false, pgnResult = "1/2-1/2", reasonLabel = "Répétition", plyCount = 80, pgn = "1. d4 d5"),
    )

    @Test fun `le CSV a un en-tete et une ligne par partie`() {
        val lines = LabExport.csv(sample).split("\n")
        assertEquals(3, lines.size)
        assertEquals("partie,camp_A,resultat,score_A,demi_coups,fin", lines[0])
        assertTrue(lines[1].startsWith("1,Blanc,1-0,1,41"))
    }

    @Test fun `le PGN concatene les parties avec leurs en-tetes et leur resultat`() {
        val pgn = LabExport.pgn(sample, nameA = "A (2200)", nameB = "B (2000)")
        assertTrue(pgn.contains("[Event \"ChessLab Lab\"]"))
        assertTrue(pgn.contains("[White \"A (2200)\"]"))
        assertTrue(pgn.contains("[Result \"1-0\"]"))
        assertTrue(pgn.contains("1. e4 e5 1-0"))
        // Partie 2 : A jouait les Noirs, et la partie est nulle.
        assertTrue(pgn.contains("[Black \"A (2200)\"]"))
        assertTrue(pgn.contains("1. d4 d5 1/2-1/2"))
    }

    @Test fun `les tags de position de depart survivent a l'export`() {
        // Sans eux, l'autre outil rejouerait les coups depuis la position
        // standard : une série partie d'une finale sortirait illisible.
        val custom = listOf(
            LabCompletedGame(
                0, aWasWhite = true, pgnResult = "1-0", reasonLabel = "Mat", plyCount = 6,
                pgn = "[SetUp \"1\"]\n[FEN \"8/8/8/8/B6n/7p/6k1/4K3 w - - 0 1\"]\n\n1. Bd7 h2",
            )
        )
        val pgn = LabExport.pgn(custom, nameA = "A", nameB = "B")
        assertTrue(pgn.contains("[SetUp \"1\"]"))
        assertTrue(pgn.contains("[FEN \"8/8/8/8/B6n/7p/6k1/4K3 w - - 0 1\"]"))
        assertTrue(pgn.contains("1. Bd7 h2 1-0"))
    }
}

/** La position imposée à une série : mêmes cas que `LabStartPositionTests`. */
class LabStartPositionTest {

    @Test fun `un FEN legal est pris tel quel`() {
        val fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        val resolved = LabStartPosition.resolve(fen)!!
        assertEquals(fen, resolved.fen)
        assertEquals(0, resolved.plies)
        assertEquals(false, resolved.fromPgn)
    }

    @Test fun `un PGN donne sa position finale`() {
        // 1. e4 e5 2. Cf3 → trois demi-coups, position finale connue.
        val resolved = LabStartPosition.resolve("1. e4 e5 2. Nf3")!!
        assertTrue(resolved.fromPgn)
        assertEquals(3, resolved.plies)
        assertTrue(
            resolved.fen.startsWith("rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b")
        )
    }

    @Test fun `un PGN avec en-tetes et resultat se resout aussi`() {
        val pgn = """
            [Event "Test"]
            [White "A"]
            [Black "B"]
            [Result "*"]

            1. d4 d5 2. c4 e6 *
        """.trimIndent()
        val resolved = LabStartPosition.resolve(pgn)!!
        assertTrue(resolved.fromPgn)
        assertEquals(4, resolved.plies)
    }

    @Test fun `ce qui n'est ni FEN ni PGN ne donne rien`() {
        assertNull(LabStartPosition.resolve("ceci n'est ni un fen ni un pgn"))
        assertNull(LabStartPosition.resolve("   "))
    }

    @Test fun `un FEN a quatre champs est accepte`() {
        // Les positions de cours en portent : c'est exactement ce qu'on colle
        // pour lancer une série depuis une finale du catalogue.
        val resolved = LabStartPosition.resolve("8/8/8/8/B6n/7p/6k1/4K3 w - -")!!
        assertEquals(false, resolved.fromPgn)
        assertTrue(resolved.fen.startsWith("8/8/8/8/B6n/7p/6k1/4K3 w - - 0 1"))
    }
}
