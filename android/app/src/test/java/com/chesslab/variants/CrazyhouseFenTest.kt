package com.chesslab.variants

import chesskit.FenParser
import chesskit.Piece
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * La réserve se lit dans la FEN du moteur, et le plateau doit rester lisible
 * par `chesskit` — qui ne connaît ni les crochets ni le `~` des pièces
 * promues, et refuserait la position entière à cause d'eux.
 */
class CrazyhouseFenTest {

    private val start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[] w KQkq - 0 1"

    @Test fun `une main vide est une main vide`() {
        assertEquals(emptyMap<Piece.Color, Map<Piece.Kind, Int>>(), CrazyhouseFen.pocket(start))
        // Pas de crochets du tout : les autres variantes passent par ici aussi.
        assertEquals(emptyMap<Piece.Color, Map<Piece.Kind, Int>>(), CrazyhouseFen.pocket("8/8/8/8/8/8/8/8 w - - 0 1"))
    }

    @Test fun `les majuscules sont aux Blancs, les minuscules aux Noirs`() {
        val pocket = CrazyhouseFen.pocket("rnb1kbnr/8/8/8/8/8/8/RNBQKBNR[PPnq] b KQkq - 0 3")
        assertEquals(mapOf(Piece.Kind.pawn to 2), pocket[Piece.Color.white])
        assertEquals(mapOf(Piece.Kind.knight to 1, Piece.Kind.queen to 1), pocket[Piece.Color.black])
    }

    @Test fun `le plateau se relit sans la reserve ni les pieces promues`() {
        val fen = "rnb1kbnr/8/8/8/8/8/8/RNBQ~KBNR[PPnq] b KQkq - 0 3"
        val board = CrazyhouseFen.boardFen(fen)
        assertEquals("rnb1kbnr/8/8/8/8/8/8/RNBQKBNR b KQkq - 0 3", board)
        assertNotNull("chesskit doit savoir lire ce qu'on lui rend", FenParser.parse(board))
        // Et la FEN de départ passe aussi.
        assertNotNull(FenParser.parse(CrazyhouseFen.boardFen(start)))
    }

    /**
     * La lettre du PION est « P », pas la lettre SAN (vide) : c'est elle qui
     * bâtit le coup de pose « P@e4 ».
     */
    @Test fun `la lettre d'une pose est la lettre FEN`() {
        assertEquals("P", CrazyhouseFen.letter(Piece.Kind.pawn))
        assertEquals("N", CrazyhouseFen.letter(Piece.Kind.knight))
        assertEquals("Q", CrazyhouseFen.letter(Piece.Kind.queen))
    }

    @Test fun `l'ordre d'affichage va de la plus forte a la plus faible`() {
        assertEquals(
            listOf(Piece.Kind.queen, Piece.Kind.rook, Piece.Kind.bishop, Piece.Kind.knight, Piece.Kind.pawn),
            CrazyhouseFen.order,
        )
    }
}
