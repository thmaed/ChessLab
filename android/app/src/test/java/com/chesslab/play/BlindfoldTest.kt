package com.chesslab.play

import chesskit.Piece
import chesskit.Square
import com.chesslab.ui.PieceDisplay
import com.chesslab.ui.PieceMask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Partie À L'AVEUGLE (17/11/2026). Pendant de `BlindfoldTests` (iOS). */
class BlindfoldTest {
    private fun pawn(c: Piece.Color) = Piece(Piece.Kind.pawn, c, Square("e4"))
    private val W = Piece.Color.white
    private val B = Piece.Color.black

    @Test fun `chaque niveau cache ce que disait le mail aux testeurs`() {
        assertEquals(PieceMask.None, BlindfoldLevel.off.mask(W))
        assertEquals(PieceDisplay.disc, BlindfoldLevel.occupiedSquares.mask(W).display(pawn(B)))
        assertEquals(PieceDisplay.greyDisc, BlindfoldLevel.occupiedSquaresGrey.mask(W).display(pawn(B)))
        assertEquals(PieceDisplay.greyDisc, BlindfoldLevel.occupiedSquaresGrey.mask(W).display(pawn(W)))
        assertEquals(PieceDisplay.hidden, BlindfoldLevel.opponentHidden.mask(W).display(pawn(B)))
        assertEquals(PieceDisplay.glyph, BlindfoldLevel.opponentHidden.mask(W).display(pawn(W)))
        assertEquals(PieceDisplay.hidden, BlindfoldLevel.ownHidden.mask(W).display(pawn(W)))
        assertEquals(PieceDisplay.glyph, BlindfoldLevel.ownHidden.mask(W).display(pawn(B)))
        assertEquals(PieceDisplay.hidden, BlindfoldLevel.allHidden.mask(B).display(pawn(W)))
        assertEquals(PieceDisplay.hidden, BlindfoldLevel.allHidden.mask(B).display(pawn(B)))
    }

    @Test fun `les disques gris viennent juste après les disques à la couleur, et se relisent`() {
        val levels = BlindfoldLevel.levels
        assertEquals(levels.indexOf(BlindfoldLevel.occupiedSquares) + 1, levels.indexOf(BlindfoldLevel.occupiedSquaresGrey))
        assertEquals(BlindfoldLevel.occupiedSquaresGrey, BlindfoldLevel.fromName(BlindfoldLevel.occupiedSquaresGrey.name))
    }

    @Test fun `on ne fait glisser que les pièces qu'on voit`() {
        assertTrue(BlindfoldLevel.opponentHidden.canDrag(W))
        assertFalse(BlindfoldLevel.ownHidden.canDrag(W))
        assertFalse(BlindfoldLevel.occupiedSquares.canDrag(W))
        assertFalse(BlindfoldLevel.occupiedSquaresGrey.canDrag(W))
        assertFalse(BlindfoldLevel.allHidden.canDrag(W))
    }

    @Test fun `un nom inconnu ou absent laisse le plateau visible`() {
        assertEquals(BlindfoldLevel.off, BlindfoldLevel.fromName(null))
        assertEquals(BlindfoldLevel.off, BlindfoldLevel.fromName(""))
        assertEquals(BlindfoldLevel.allHidden, BlindfoldLevel.fromName("allHidden"))
    }

    @Test fun `le masque disparaît pendant un coup d'oeil et une fois la partie finie`() {
        val blind = PlayUiState(settings = PlayGameSettings(blindfold = BlindfoldLevel.opponentHidden))
        assertEquals(PieceMask(hidden = setOf(B)), blind.boardMask)
        assertEquals(PieceMask.None, blind.copy(isPeeking = true).boardMask)
        assertEquals(PieceMask.None, blind.copy(gameOver = true).boardMask)
        assertEquals(PieceMask.None, PlayUiState().boardMask)
    }

    @Test fun `le dernier coup affiché en gros est celui de l'adversaire`() {
        val ui = PlayUiState(userMovesOnEvenPlies = true)
        assertNull(ui.lastOpponentSan)
        assertNull(ui.copy(sanMoves = listOf("e4")).lastOpponentSan)
        assertEquals("e5", ui.copy(sanMoves = listOf("e4", "e5")).lastOpponentSan)
        // Avec les Noirs : l'adversaire ouvre.
        assertEquals("e4", PlayUiState(userMovesOnEvenPlies = false, sanMoves = listOf("e4")).lastOpponentSan)
    }

    @Test fun `un coup d'oeil dure au moins sept dixièmes de seconde`() {
        assertEquals(500L, PeekTiming.remainingMs(pressedAt = 1_000, releasedAt = 1_200))
        assertEquals(0L, PeekTiming.remainingMs(pressedAt = 1_000, releasedAt = 2_500))
    }

    /** Le choix de la voix (19/11/2026) — pendant de `BlindfoldVoiceChoiceTests` (iOS). */
    @Test fun `les voix proposées sont celles de la langue, installées et hors réseau, numérotées par nom`() {
        val v = { name: String, lang: String, country: String, net: Boolean, inst: Boolean ->
            BlindfoldVoice.VoiceInfo(name, lang, country, net, inst)
        }
        val voices = listOf(
            v("fr-fr-x-frd-local", "fr", "FR", false, true),
            v("fr-fr-x-frc-local", "fr", "FR", false, true),
            v("fr-fr-x-frc-network", "fr", "FR", true, true),
            v("fr-fr-x-fre-local", "fr", "FR", false, false),
            v("en-us-x-sfg-local", "en", "US", false, true),
        )
        val options = BlindfoldVoice.optionsOf(voices, "fr")
        assertEquals(listOf("fr-fr-x-frc-local", "fr-fr-x-frd-local"), options.map { it.name })
        assertEquals(listOf(1, 2), options.map { it.number })
        assertTrue("une seule région : on ne la dit pas", options.all { it.region == null })
    }

    @Test fun `la région n'est dite que si la langue en a plusieurs`() {
        val options = BlindfoldVoice.optionsOf(
            listOf(
                BlindfoldVoice.VoiceInfo("fr-ca-x-caa-local", "fr", "CA", false, true),
                BlindfoldVoice.VoiceInfo("fr-fr-x-frc-local", "fr", "FR", false, true),
            ),
            "fr",
        )
        assertEquals(listOf("Canada", "France"), options.map { it.region })
    }
}
