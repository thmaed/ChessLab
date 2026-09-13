package com.chesslab.variants

import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les règles du Duck Chess, seule variante du hub dont la légalité est
 * calculée en Kotlin — aucun moteur ne la connaît, donc aucun arbitre
 * extérieur ne rattrapera une erreur ici. D'où des tests serrés. Portés de
 * `DuckChessRulesTests.swift`, cas pour cas.
 */
class DuckChessRulesTest {

    private fun position(fen: String): Position = FenParser.parse(fen)!!

    private val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: Sans canard, on retrouve les échecs ordinaires

    @Test fun `position de depart sans canard - vingt coups, comme aux echecs`() {
        assertEquals(20, DuckChessRules.moves(position(start), duck = null).size)
    }

    // MARK: Le canard bloque

    @Test fun `le canard occupe une case - rien ne s'y pose`() {
        val moves = DuckChessRules.moves(position(start), duck = Square("e4"))
        assertFalse("e4 est sous le canard", moves.any { it.to == Square("e4") })
        assertTrue(moves.any { it.from == Square("e2") && it.to == Square("e3") })
    }

    @Test fun `le canard barre la poussee double d'un pion`() {
        val moves = DuckChessRules.moves(position(start), duck = Square("e3"))
        assertFalse("e3 bloqué : le pion e2 ne bouge plus du tout", moves.any { it.from == Square("e2") })
    }

    @Test fun `le canard arrete une piece a distance, sans se faire capturer`() {
        val fen = "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
        val targets = DuckChessRules.moves(position(fen), duck = Square("a5"))
            .filter { it.from == Square("a1") }.map { it.to }.toSet()
        assertTrue("la tour monte jusqu'au canard", Square("a4") in targets)
        assertFalse("elle ne prend PAS le canard", Square("a5") in targets)
        assertFalse("et ne le traverse pas", Square("a6") in targets)
    }

    // MARK: Ni échec, ni mat — on capture le roi

    @Test fun `un roi a le droit de se mettre en prise`() {
        // Roi blanc e1, tour noire e8 : aux échecs, Re2 serait illégal.
        val fen = "4r2k/8/8/8/8/8/8/4K3 w - - 0 1"
        val moves = DuckChessRules.moves(position(fen), duck = null)
        assertTrue(
            "en Duck Chess, la notion d'échec n'existe pas",
            moves.any { it.from == Square("e1") && it.to == Square("e2") },
        )
    }

    @Test fun `la capture du roi est un coup comme un autre, et designe le vainqueur`() {
        val fen = "4k3/4R3/8/8/8/8/8/4K3 w - - 0 1"
        val pos = position(fen)
        val capture = DuckChessRules.Move(Square("e7"), Square("e8"))
        assertTrue(capture in DuckChessRules.moves(pos, duck = null))
        assertEquals(Piece.Color.black, DuckChessRules.capturesKing(capture, pos))
        // Un coup ordinaire ne termine rien.
        assertNull(DuckChessRules.capturesKing(DuckChessRules.Move(Square("e7"), Square("e6")), pos))
    }

    /**
     * Une position où un roi est prenable est ILLÉGALE pour Stockfish : c'est
     * ce test qui garde l'app de la lui envoyer.
     */
    @Test fun `une position ou un roi est prenable n'est pas legale pour Stockfish`() {
        assertTrue(DuckChessRules.isStandardLegal(position(start)))
        assertFalse(DuckChessRules.isStandardLegal(position("4k3/4R3/8/8/8/8/8/4K3 w - - 0 1")))
        // Un plateau sans roi non plus.
        assertFalse(DuckChessRules.isStandardLegal(position("8/8/8/8/8/8/8/4K3 w - - 0 1")))
    }

    // MARK: Roque

    @Test fun `le roque reste possible, et le canard peut l'empecher`() {
        val fen = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1"
        val free = DuckChessRules.moves(position(fen), duck = null).filter { it.from == Square("e1") }
        assertTrue("petit roque", free.any { it.to == Square("g1") })
        assertTrue("grand roque", free.any { it.to == Square("c1") })

        val blocked = DuckChessRules.moves(position(fen), duck = Square("f1")).filter { it.from == Square("e1") }
        assertFalse("f1 occupé par le canard", blocked.any { it.to == Square("g1") })
        assertTrue(blocked.any { it.to == Square("c1") })
    }

    @Test fun `sans droit de roque, pas de roque`() {
        val fen = "4k3/8/8/8/8/8/8/R3K2R w - - 0 1"
        val moves = DuckChessRules.moves(position(fen), duck = null).filter { it.from == Square("e1") }
        assertFalse(moves.any { it.to == Square("g1") })
        assertFalse(moves.any { it.to == Square("c1") })
    }

    // MARK: Pions

    @Test fun `la promotion propose les quatre pieces`() {
        val fen = "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"
        val moves = DuckChessRules.moves(position(fen), duck = null).filter { it.from == Square("a7") }
        assertEquals(4, moves.size)
        assertEquals(
            setOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight),
            moves.mapNotNull { it.promotion }.toSet(),
        )
        // Et le coup s'écrit avec sa lettre, en minuscule, comme l'attend UCI.
        assertEquals(setOf("a7a8q", "a7a8r", "a7a8b", "a7a8n"), moves.map { it.uci }.toSet())
    }

    @Test fun `un pion ne capture pas le canard en diagonale`() {
        val fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"
        val moves = DuckChessRules.moves(position(fen), duck = Square("d3")).filter { it.from == Square("e2") }
        assertFalse("le canard ne se capture pas", moves.any { it.to == Square("d3") })
    }

    @Test fun `la prise en passant reste jouable`() {
        val fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"
        val moves = DuckChessRules.moves(position(fen), duck = null, enPassant = Square("d6"))
            .filter { it.from == Square("e5") }
        assertTrue(moves.any { it.to == Square("d6") })
    }

    // MARK: Le canard lui-même

    @Test fun `le canard se pose sur une case vide, et doit bouger`() {
        val targets = DuckChessRules.duckTargets(position(start), currentDuck = Square("e4"))
        assertFalse("il doit changer de case", Square("e4") in targets)
        assertFalse("pas sur une pièce", Square("e2") in targets)
        assertTrue(Square("e3") in targets)
        // 64 cases − 32 pièces − la case du canard.
        assertEquals(31, targets.size)
    }

    @Test fun `le chemin entre deux cases alignees exclut les bornes`() {
        assertEquals(
            listOf(Square("a2"), Square("a3")),
            DuckChessRules.pathBetween(Square("a1"), Square("a4")),
        )
        assertEquals(
            listOf(Square("b2"), Square("c3")),
            DuckChessRules.pathBetween(Square("a1"), Square("d4")),
        )
        // Un saut de cavalier ne traverse rien.
        assertEquals(emptyList<Square>(), DuckChessRules.pathBetween(Square("b1"), Square("c3")))
        // Deux cases voisines non plus.
        assertEquals(emptyList<Square>(), DuckChessRules.pathBetween(Square("a1"), Square("a2")))
    }

    /**
     * `Square(File, Rank)` RAMÈNE toute valeur hors bornes dans le plateau :
     * sans garde, un cavalier en h1 sauterait en colonne a.
     */
    @Test fun `une case hors du plateau n'existe pas`() {
        assertNull(DuckChessRules.square(0, 1))
        assertNull(DuckChessRules.square(9, 1))
        assertNull(DuckChessRules.square(1, 0))
        assertNull(DuckChessRules.square(1, 9))
        assertEquals(Square("h1"), DuckChessRules.square(8, 1))
        // Le cavalier en h1 n'a que deux coups, pas quatre.
        val moves = DuckChessRules.moves(position("4k3/8/8/8/8/8/8/4K2N w - - 0 1"), duck = null)
            .filter { it.from == Square("h1") }
        assertEquals(setOf(Square("f2"), Square("g3")), moves.map { it.to }.toSet())
    }
}
