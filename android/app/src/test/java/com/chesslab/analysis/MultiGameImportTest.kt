package com.chesslab.analysis

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Un fichier PGN de plusieurs parties : chacune doit rester lisible APRÈS le découpage. Relevé sur Galaxy le
 * 14/11/2026 : un fichier de trois parties n'en rangeait qu'une, parce que le nettoyage du fichier ENTIER ne
 * gardait qu'une ligne vide au total.
 */
class MultiGameImportTest {
    private val trois = """
        [Event "Base 1"]
        [White "Alice"]
        [Black "Bob"]
        [Result "0-1"]

        1. f3 e5 2. g4 Qh4# 0-1

        [Event "Base 2"]
        [White "Carole"]
        [Black "David"]
        [Result "1/2-1/2"]

        1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 1/2-1/2

        [Event "Base 3"]
        [White "Eve"]
        [Black "Frank"]
        [Result "0-1"]

        1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 0-1
    """.trimIndent()

    @Test fun sanitizingTheWholeFileFirstBreaksTheLaterGames() {
        // L'ANCIEN ordre : il perd la ligne vide des parties 2 et 3 — c'est ce que ce test garde de vue.
        val games = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(trois))
        val unreadable = games.count { runCatching { chesskit.PgnParser.parse(it) }.isFailure }
        assertTrue("l'ancien ordre devait casser au moins une partie", unreadable > 0)
    }

    @Test fun everyGameOfAFileParsesAfterSplittingThenSanitizing() {
        val games = PgnSanitizer.cleanGames(trois)
        assertEquals(3, games.size)
        for (g in games) {
            val parsed = chesskit.PgnParser.parse(g)
            assertTrue(parsed.moves.indices.count { it.variation == chesskit.MoveTree.Index.MAIN_VARIATION } > 0)
        }
    }
}
