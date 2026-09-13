package com.chesslab.variants

import chesskit.FenParser
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/**
 * Les Barricades : un mur est une PIÈCE pour le moteur, et rien du tout pour
 * `chesskit`. Tout ce fichier tient à cette phrase — la FEN qui va au moteur
 * n'est pas celle qui va au plateau.
 */
class BarricadesTest {

    @Test fun `la FEN de depart dit les memes murs que la liste`() {
        assertEquals(
            BarricadesConfiguration.wallSquares.map { it.notation }.sorted(),
            BarricadesFen.wallSquares(BarricadesConfiguration.startFen).map { it.notation }.sorted(),
        )
    }

    @Test fun `chesskit recoit une position sans mur, et sait la lire`() {
        val cleared = BarricadesFen.forChessKit(BarricadesConfiguration.startFen)
        assertTrue("plus aucun mur : $cleared", !cleared.contains('W'))
        val position = FenParser.parse(cleared)
        assertNotNull("chesskit doit savoir lire ce qu'on lui rend", position)
        assertEquals(32, position!!.pieces.size)
        // Une FEN sans mur traverse sans être touchée — les autres variantes
        // passent par ici aussi.
        val ordinary = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        assertEquals(ordinary, BarricadesFen.forChessKit(ordinary))
    }

    @Test fun `poser puis retirer les murs rend la position de depart`() {
        val walls = BarricadesConfiguration.wallSquares.toSet()
        val cleared = BarricadesFen.forChessKit(BarricadesConfiguration.startFen)
        assertEquals(BarricadesConfiguration.startFen, BarricadesFen.inserting(walls, cleared))
    }

    @Test fun `la region ouverte est tout sauf les murs`() {
        val tokens = BarricadesConfiguration.openSquaresBitboard.split(" ")
        // Les rangées sans mur sont écrites d'un seul jeton.
        assertTrue("*1" in tokens && "*8" in tokens && "*3" in tokens)
        // Celles qui en portent sont écrites case par case, mur exclu.
        assertTrue("d4" !in tokens && "e5" !in tokens)
        assertTrue("e4" in tokens && "d5" in tokens && "a4" in tokens)
    }

    @Test fun `la definition enseigne les deux variantes au moteur`() {
        val ini = BarricadesConfiguration.configurationText
        assertTrue(ini.contains("[barricades:chess]"))
        assertTrue(ini.contains("[randombarricades:chess]"))
        assertTrue("le mur ne joue aucun coup", ini.contains("immobile = w"))
        assertTrue("et ne vaut rien", ini.contains("pieceValueMg = w:0"))
        assertEquals("six types de pièces noires bridés", 6, Regex("mobilityRegionBlack").findAll(ini).count())
        // La variante aléatoire n'a PAS de région : ses murs bougent.
        val random = ini.substringAfter("[randombarricades:chess]")
        assertTrue("aucune région figée sur des murs mobiles", !random.contains("mobilityRegion"))
    }

    @Test fun `les murs mobiles sont trois, sur les rangees 2 a 7, jamais sur une piece`() {
        val random = Random(1234)
        var fen = BarricadesConfiguration.openingPosition(random)
        repeat(20) {
            val walls = BarricadesFen.wallSquares(fen)
            assertEquals("toujours trois murs : $fen", 3, walls.size)
            walls.forEach { assertTrue("rangée ${it.rank.value} interdite", it.rank.value in 2..7) }
            val position = FenParser.parse(BarricadesFen.forChessKit(fen))!!
            val occupied = position.pieces.mapTo(HashSet()) { it.square.notation }
            walls.forEach { assertTrue("mur sur une pièce : ${it.notation}", it.notation !in occupied) }
            fen = BarricadesConfiguration.relocatingWalls(fen, random)!!
        }
    }

    @Test fun `deux murs sur trois changent de case a chaque demi-coup`() {
        val random = Random(7)
        val before = BarricadesConfiguration.openingPosition(random)
        val after = BarricadesConfiguration.relocatingWalls(before, random)!!
        val old = BarricadesFen.wallSquares(before).map { it.notation }.toSet()
        val new = BarricadesFen.wallSquares(after).map { it.notation }.toSet()
        assertEquals("un seul mur épargné", 1, old.intersect(new).size)
        // Et les pièces, elles, n'ont pas bougé.
        assertEquals(BarricadesFen.forChessKit(before), BarricadesFen.forChessKit(after))
    }

    @Test fun `les prises de mur sont retirees de la liste du moteur`() {
        val fen = "rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        val moves = listOf("e2e4", "b1d4", "g1e5", "d2d3")
        assertEquals(listOf("e2e4", "d2d3"), BarricadesConfiguration.removingWallCaptures(moves, fen))
        // Sans mur, rien n'est retiré.
        val open = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        assertEquals(moves, BarricadesConfiguration.removingWallCaptures(moves, open))
    }

    @Test fun `une position illisible ne fait pas tomber la partie`() {
        assertNull(BarricadesConfiguration.relocatingWalls("pas une fen"))
    }
}
