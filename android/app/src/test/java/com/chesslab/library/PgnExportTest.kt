package com.chesslab.library

import chesskit.Game
import chesskit.PgnParser
import chesskit.Position
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.GregorianCalendar

/**
 * Ce qu'un PGN exporté contient VRAIMENT. Pendant de `PGNExportHeaderTests.swift`.
 *
 * Un testeur a partagé des parties côté iOS le 27/09/2026 et n'a reçu que des
 * suites de coups. Android avait le même défaut dès qu'on exportait PENDANT la
 * partie : aucune balise.
 */
class PgnExportTest {

    private fun gameAfterE4(): Game = Game().also { it.make(listOf("e4"), it.startingIndex) }

    private fun date(y: Int, m: Int, d: Int) = GregorianCalendar(y, m - 1, d, 12, 0).time

    private fun meta(
        white: String = "Alice", black: String = "Bob", result: String? = "1-0",
        date: java.util.Date? = date(2026, 9, 27),
    ) = PgnExport.Metadata(event = "Contre l'ordinateur", date = date, white = white, black = black, result = result)

    @Test fun lesSeptBalisesSontPresentes() {
        val pgn = PgnExport.pgn(gameAfterE4(), meta())
        for (tag in listOf(
            "[Event \"Contre l'ordinateur\"]", "[Site \"ChessLab\"]", "[Date \"2026.09.27\"]",
            "[Round \"-\"]", "[White \"Alice\"]", "[Black \"Bob\"]", "[Result \"1-0\"]",
        )) assertTrue("$tag manque :\n$pgn", pgn.contains(tag))
    }

    /** La forme COMPLÈTE : une section de balises, une ligne vide, les coups clos par le résultat. */
    @Test fun leFichierALaFormeQueLeStandardAttend() {
        val expected = """
            [Event "Contre l'ordinateur"]
            [Site "ChessLab"]
            [Date "2026.09.27"]
            [Round "-"]
            [White "Alice"]
            [Black "Bob"]
            [Result "1-0"]

            1. e4 1-0
        """.trimIndent()
        assertEquals(expected, PgnExport.pgn(gameAfterE4(), meta()))
    }

    @Test fun unePartieEnCoursSeNoteParUneEtoile() {
        val pgn = PgnExport.pgn(gameAfterE4(), meta(result = null))
        assertTrue(pgn.contains("[Result \"*\"]"))
        assertTrue(pgn.trim().endsWith("*"))
    }

    /** Un PGN importé garde SES en-têtes : on ne comble que les manques. */
    @Test fun lesBalisesExistantesNeSontJamaisEcrasees() {
        val game = gameAfterE4().apply {
            tags.event = "Championnat du monde"
            tags.white = "Fischer, Robert J."
            tags.date = "1972.07.11"
        }
        val pgn = PgnExport.pgn(game, meta())
        assertTrue(pgn.contains("[Event \"Championnat du monde\"]"))
        assertTrue(pgn.contains("[White \"Fischer, Robert J.\"]"))
        assertTrue(pgn.contains("[Date \"1972.07.11\"]"))
        assertTrue("ce qui manquait est comblé", pgn.contains("[Black \"Bob\"]"))
    }

    /** L'export ne doit RIEN laisser derrière lui sur la partie de l'appelant. */
    @Test fun lesBalisesDeLAppelantNeBougentPas() {
        val game = gameAfterE4()
        PgnExport.pgn(game, meta())
        assertEquals("", game.tags.white)
        assertEquals("", game.tags.event)
        assertFalse(game.pgn.contains("["))
    }

    @Test fun unGuillemetNePeutPasCasserLeFichier() {
        val pgn = PgnExport.pgn(gameAfterE4(), meta(white = "Ron \"Rocket\" Lasser", black = "[Bob]"))
        assertTrue(pgn.contains("[White \"Ron Rocket Lasser\"]"))
        assertTrue(pgn.contains("[Black \"Bob\"]"))
        assertEquals("Ron Rocket Lasser", PgnParser.parse(pgn).tags.white)
    }

    @Test fun lExportSeRechargeAvecSesCoupsEtSesEnTetes() {
        val reloaded = PgnParser.parse(PgnExport.pgn(gameAfterE4(), meta(result = "0-1")))
        assertEquals("Alice", reloaded.tags.white)
        assertEquals("0-1", reloaded.tags.result)
        assertTrue(reloaded.moves.indices.isNotEmpty())
    }

    @Test fun uneDateInconnueSuitLeStandard() {
        assertTrue(PgnExport.pgn(gameAfterE4(), meta(date = null)).contains("[Date \"????.??.??\"]"))
    }

    @Test fun laDateNeDependPasDeLaLocale() {
        assertEquals("2026.01.05", PgnExport.pgnDate(date(2026, 1, 5)))
    }

    /** Une position de départ personnalisée se déclare, sans quoi le PGN rejouerait une autre partie. */
    @Test fun unDepartPersonnaliseSeDeclare() {
        val fen = "8/P6k/8/8/8/8/7K/8 w - - 0 1"
        val game = Game(Position.fromFen(fen)!!).also { it.make(listOf("Kh3"), it.startingIndex) }
        val pgn = PgnExport.pgn(game, meta())
        assertTrue(pgn.contains("[SetUp \"1\"]"))
        assertTrue(pgn.contains("[FEN \"$fen\"]"))
    }

    /** Le contrat d'origine : sans en-têtes demandées, une partie standard sort nue. */
    @Test fun sansMetadonneesUnePartieStandardSortNue() {
        assertFalse(PgnExport.pgn(gameAfterE4()).contains("["))
    }

    // ------------------------------------------------------- variantes

    @Test fun lesVariantesOntLesSeptBalisesPuisLaVariante() {
        val lines = PgnExport.tagLines(
            event = "ChessLab Horde", white = "Vous", black = "Ordinateur", result = null,
            variant = "horde", startFen = "rnbqkbnr/pppppppp/8/1PP2PP1/PPPPPPPP/PPPPPPPP/PPPPPPPP/PPPPPPPP w kq - 0 1",
            date = date(2026, 9, 29),
        )
        assertEquals(
            listOf("Event", "Site", "Date", "Round", "White", "Black", "Result", "Variant", "SetUp", "FEN"),
            lines.map { it.substringAfter("[").substringBefore(" ") },
        )
        assertTrue(lines.contains("[Result \"*\"]"))
    }
}
