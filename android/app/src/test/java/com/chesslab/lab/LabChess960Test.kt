package com.chesslab.lab

import chesskit.Position
import chesskit.Square
import com.chesslab.variants.Chess960Castling
import com.chesslab.variants.VariantSan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le Laboratoire en Chess960 : le tirage des positions (pur), le roque, l'export.
 * Pendant de `LabChess960SettingsTests` (iOS), test pour test.
 */
class LabChess960Test {

    private fun settings(alternate: Boolean = true, number: Int? = null, seed: Long = 42L) =
        LabSeriesSettings(chess960 = true, chess960Number = number, chess960Seed = seed, alternateColors = alternate)

    @Test fun `une paire de parties partage sa position quand les couleurs alternent`() {
        val s = settings()
        assertEquals(s.chess960NumberFor(0), s.chess960NumberFor(1))
        assertEquals(s.chess960NumberFor(2), s.chess960NumberFor(3))
    }

    @Test fun `chaque partie a sa position sans alternance`() {
        val s = settings(alternate = false)
        assertTrue((0 until 20).map(s::chess960NumberFor).toSet().size > 10)
    }

    @Test fun `un numero impose vaut pour toutes les parties et se borne`() {
        assertTrue((0 until 6).all { settings(number = 518).chess960NumberFor(it) == 518 })
        assertEquals(959, settings(number = 5000).chess960NumberFor(0))
        assertEquals(0, settings(number = -3).chess960NumberFor(0))
    }

    @Test fun `la meme graine donne la meme serie`() {
        val first = (0 until 30).map(settings(seed = 7L)::chess960NumberFor)
        assertEquals(first, (0 until 30).map(settings(seed = 7L)::chess960NumberFor))
        assertFalse(first == (0 until 30).map(settings(seed = 8L)::chess960NumberFor))
        assertTrue(first.all { it in 0..959 })
    }

    /** Les MÊMES valeurs que la suite iOS, calculées à part en Python avant d'être écrites. */
    @Test fun `le tirage reprend les valeurs de reference d'iOS`() {
        assertEquals(listOf(482, 853, 451, 18, 84, 370), (0 until 6).map { LabSeriesSettings.scharnagl(42L, it) })
    }

    @Test fun `la graine, grande, survit a l'ecriture sur le disque`() {
        val back = LabSeriesSettings.fromJson(settings(seed = Long.MIN_VALUE + 12345L).toJson())
        assertEquals(Long.MIN_VALUE + 12345L, back.chess960Seed)
        assertTrue(back.chess960)
    }

    @Test fun `une serie sauvegardee sans les nouvelles cles se lit comme classique`() {
        val json = org.json.JSONObject().put("gameCount", 10)
        val back = LabSeriesSettings.fromJson(json)
        assertFalse(back.chess960)
        assertNull(back.chess960Number)
    }

    @Test fun `l'export garde la variante`() {
        val game = LabCompletedGame(
            index = 0, aWasWhite = true, pgnResult = "1/2-1/2", reasonLabel = "x", plyCount = 2,
            pgn = "[Variant \"Chess960\"]\n[SetUp \"1\"]\n[FEN \"bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w KQkq - 0 1\"]\n\n1. e4 e5 1/2-1/2",
        )
        val pgn = LabExport.pgn(listOf(game), "A", "B")
        assertTrue(pgn.contains("[Variant \"Chess960\"]"))
        assertTrue(pgn.contains("[FEN \"bbqnnrkr"))
    }

    // MARK: Le roque

    @Test fun `le roque se reconnait au roi qui prend sa tour`() {
        val position = Position.fromFen("4k3/8/8/8/8/8/8/4K2R w K - 0 1")!!
        assertTrue(Chess960Castling.isCastle("e1h1", position))
        assertFalse(Chess960Castling.isCastle("e1f1", position))
        assertFalse(Chess960Castling.isCastle("h1h2", position))
    }

    @Test fun `la case surlignee est celle du roi, pas celle de la tour`() {
        val kingSide = Position.fromFen("4k3/8/8/8/8/8/8/4K2R w K - 0 1")!!
        assertEquals(Square("e1") to Square("g1"), Chess960Castling.displaySquares("e1h1", kingSide))
        val queenSide = Position.fromFen("r3k3/8/8/8/8/8/8/4K3 b q - 0 1")!!
        assertEquals(Square("e8") to Square("c8"), Chess960Castling.displaySquares("e8a8", queenSide))
        // Un coup ordinaire reste tel quel.
        assertEquals(Square("e1") to Square("f1"), Chess960Castling.displaySquares("e1f1", kingSide))
    }

    @Test fun `le roque s'ecrit O-O et O-O-O`() {
        val short = VariantSan.build("e1h1", "4k3/8/8/8/8/8/8/4K2R w K - 0 1", listOf("e1h1", "e1f1"), isCheck = false, isMate = false)
        assertEquals("O-O", short)
        val long = VariantSan.build("e8a8", "r3k3/8/8/8/8/8/8/4K3 b q - 0 1", listOf("e8a8"), isCheck = false, isMate = false)
        assertEquals("O-O-O", long)
        val withCheck = VariantSan.build("e1h1", "4k3/8/8/8/8/8/8/4K2R w K - 0 1", listOf("e1h1"), isCheck = true, isMate = false)
        assertEquals("O-O+", withCheck)
    }
}
