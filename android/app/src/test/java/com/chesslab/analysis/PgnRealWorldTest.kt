package com.chesslab.analysis

import chesskit.MoveTree
import chesskit.PgnParser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les PGN du VRAI monde : ceux qu'on colle depuis Lichess ou chess.com.
 *
 * C'est le premier geste d'un utilisateur du mode Analyser, et c'est là que
 * ChessKit casse — au point qu'une classe entière existe de chaque côté pour
 * le contourner ([PgnSanitizer] ici, `PGNSanitizer.swift` là-bas).
 *
 * Écrit APRÈS coup, en vérifiant si le port en avait vraiment besoin. Réponse :
 * oui pour deux cas sur six. Les pendules `[%clk …]`, les annotations NAG, les
 * variantes et les lignes vides surnuméraires passaient déjà ; **le BOM avec
 * les fins de ligne Windows, et le commentaire d'introduction, non** — les deux
 * plus courants quand on colle depuis un site.
 */
class PgnRealWorldTest {

    /**
     * Les demi-coups de la ligne principale, APRÈS le nettoyage — c'est-à-dire
     * par le chemin que prend un PGN collé dans l'app.
     */
    private fun plies(pgn: String): Int {
        val cleaned = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(pgn)).firstOrNull() ?: pgn
        val g = PgnParser.parse(cleaned)
        return g.moves.indices.count { it.variation == MoveTree.Index.MAIN_VARIATION }
    }

    @Test fun `un export lichess avec pendules et evaluations`() {
        val pgn = """
            [Event "Rated Blitz game"]
            [Site "https://lichess.org/abcd1234"]
            [Date "2026.09.12"]
            [White "alice"]
            [Black "bob"]
            [Result "1-0"]
            [UTCDate "2026.09.12"]
            [TimeControl "300+0"]
            [Termination "Normal"]

            1. e4 { [%clk 0:05:00] } 1... e5 { [%clk 0:05:00] } 2. Nf3 { [%clk 0:04:58] } 2... Nc6 { [%clk 0:04:57] } 3. Bb5 { [%clk 0:04:55] } 1-0
        """.trimIndent()
        assertEquals(5, plies(pgn))
    }

    @Test fun `des fins de ligne Windows et un BOM`() {
        val pgn = "﻿[Event \"X\"]\r\n[Result \"*\"]\r\n\r\n1. e4 e5 2. Nf3 *\r\n"
        assertEquals(3, plies(pgn))
    }

    @Test fun `un commentaire AVANT le premier coup`() {
        val pgn = """
            [Event "X"]
            [Result "*"]

            { Partie commentée par l'entraîneur. } 1. d4 d5 2. c4 *
        """.trimIndent()
        assertEquals(3, plies(pgn))
    }

    @Test fun `des lignes vides en trop`() {
        val pgn = "[Event \"X\"]\n[Result \"*\"]\n\n\n\n1. e4 e5 *\n"
        assertEquals(2, plies(pgn))
    }

    @Test fun `des annotations NAG et des variantes`() {
        val pgn = """
            [Event "X"]
            [Result "*"]

            1. e4 e5 2. Nf3?! (2. Bc4 Nf6) 2... Nc6 ${'$'}1 3. Bb5 ${'$'}14 *
        """.trimIndent()
        assertTrue("ligne principale attendue, obtenu ${plies(pgn)}", plies(pgn) >= 5)
    }

    @Test fun `un roque avec échec`() {
        // « O-O+ » : refusé par le motif de validation de ChessKit en amont.
        val pgn = """
            [Event "X"]
            [Result "*"]

            1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nf3 Nxe4 5. d4 d5 6. Bd3 Bd6 7. O-O O-O *
        """.trimIndent()
        assertEquals(14, plies(pgn))
    }
}

/** Le nettoyeur lui-même, cas par cas. */
class PgnSanitizerTest {

    @Test fun `le BOM et les fins de ligne Windows disparaissent`() {
        val cleaned = PgnSanitizer.normalizeWhitespace("﻿[Event \"X\"]\r\n\r\n1. e4 *\r\n")
        assertTrue("BOM restant", !cleaned.startsWith("﻿"))
        assertTrue("retour chariot restant", !cleaned.contains("\r"))
    }

    @Test fun `un commentaire d'introduction est retiré, pas les autres`() {
        val cleaned = PgnSanitizer.stripLeadingComment(
            "[Event \"X\"]\n\n{ Présentation. } 1. e4 { bon coup } e5 *"
        )
        assertTrue("présentation restante", !cleaned.contains("Présentation"))
        // Le commentaire d'un COUP, lui, fait partie de la partie.
        assertTrue("commentaire de coup perdu", cleaned.contains("bon coup"))
    }

    @Test fun `une seule ligne vide survit`() {
        val cleaned = PgnSanitizer.collapseExtraBlankLines("\n\n[Event \"X\"]\n\n\n\n1. e4 *")
        assertTrue("lignes vides en trop", !cleaned.contains("\n\n\n"))
        assertTrue("séparateur perdu", cleaned.contains("\n\n"))
    }

    @Test fun `le marqueur d'échec après un roque est retiré`() {
        assertEquals("1. O-O O-O-O 2. Qh5", PgnSanitizer.stripCastlingCheckMarkers("1. O-O+ O-O-O# 2. Qh5"))
    }

    @Test fun `un fichier de plusieurs parties se découpe`() {
        val two = "[Event \"A\"]\n[Result \"*\"]\n\n1. e4 *\n\n[Event \"B\"]\n[Result \"*\"]\n\n1. d4 *"
        val games = PgnSanitizer.splitIntoGames(two)
        assertEquals(2, games.size)
        assertTrue("la première partie n'est pas la bonne", games[0].contains("e4"))
        assertTrue("la seconde partie n'est pas la bonne", games[1].contains("d4"))
    }

    @Test fun `un commentaire de tête part même SANS bloc de tags`() {
        // Le cas du champ « coller » : les coups seuls, précédés d'un
        // commentaire. iOS ne le traite pas — ici si.
        assertEquals("1. e4 e5", PgnSanitizer.sanitize("{ Partie commentée } 1. e4 e5"))
    }

    @Test fun `un texte sans tag reste entier`() {
        // Certains exports n'ont pas d'en-tête : la séquence de coups seule.
        assertEquals("1. e4 e5", PgnSanitizer.sanitize("1. e4 e5"))
    }
}

/** Le champ « coller » reçoit souvent les COUPS SEULS, sans en-tête. */
class PgnMovetextOnlyTest {

    private fun plies(pgn: String): Int {
        val cleaned = PgnSanitizer.splitIntoGames(PgnSanitizer.sanitize(pgn)).firstOrNull() ?: pgn
        return PgnParser.parse(cleaned).moves.indices
            .count { it.variation == MoveTree.Index.MAIN_VARIATION }
    }

    @Test fun `des coups seuls, précédés d'un commentaire`() {
        assertEquals(6, plies("{Partie commentee} 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6"))
    }

    @Test fun `des coups seuls, tout court`() {
        assertEquals(6, plies("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6"))
    }
}
