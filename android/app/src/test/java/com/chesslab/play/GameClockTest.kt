package com.chesslab.play

import chesskit.Piece
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La pendule. Elle ne s'appuie sur aucun minuteur interne — on lui donne
 * l'heure — et c'est précisément ce qui la rend vérifiable sans attendre.
 */
class GameClockTest {

    private val blitz = TimeControl("blitz_3_2", "blitz", "3+2", 180, 2)
    private val t0 = 1_700_000_000_000L

    @Test fun `les deux camps partent avec le meme temps`() {
        val c = GameClock(blitz)
        assertEquals(180_000, c.remaining(Piece.Color.white))
        assertEquals(180_000, c.remaining(Piece.Color.black))
    }

    @Test fun `seul le camp au trait perd du temps`() {
        val c = GameClock(blitz)
        c.start(Piece.Color.white, t0)
        c.tick(t0 + 5_000)
        assertEquals(175_000, c.remaining(Piece.Color.white))
        assertEquals(180_000, c.remaining(Piece.Color.black), )
    }

    @Test fun `l'incrément s'ajoute APRÈS le décompte`() {
        val c = GameClock(blitz)
        c.start(Piece.Color.white, t0)
        c.stopAndIncrement(t0 + 5_000)
        // 180 − 5 + 2 : l'ajouter avant offrirait un temps qu'un joueur au
        // drapeau n'a plus.
        assertEquals(177_000, c.remaining(Piece.Color.white))
    }

    @Test fun `le temps ne descend pas sous zéro et lève le drapeau`() {
        val c = GameClock(TimeControl("t", "blitz", "2s", 2, 0))
        c.start(Piece.Color.white, t0)
        c.tick(t0 + 10_000)
        assertEquals(0, c.remaining(Piece.Color.white))
        assertTrue(c.flagged(Piece.Color.white))
        assertFalse(c.flagged(Piece.Color.black))
    }

    @Test fun `un joueur au drapeau ne touche pas son incrément`() {
        val c = GameClock(blitz)
        c.start(Piece.Color.white, t0)
        c.stopAndIncrement(t0 + 200_000)
        assertEquals(0, c.remaining(Piece.Color.white))
    }

    @Test fun `sans pendule, rien ne bouge`() {
        val c = GameClock(TimeControl.none)
        assertFalse(c.hasClock)
        c.start(Piece.Color.white, t0)
        c.tick(t0 + 60_000)
        assertEquals(0, c.remaining(Piece.Color.white))
        assertFalse(c.flagged(Piece.Color.white))
    }

    @Test fun `une alternance complète décompte chaque camp séparément`() {
        val c = GameClock(blitz)
        c.start(Piece.Color.white, t0)                    // les blancs réfléchissent 4 s
        c.stopAndIncrement(t0 + 4_000)
        c.start(Piece.Color.black, t0 + 4_000)            // les noirs, 9 s
        c.stopAndIncrement(t0 + 13_000)
        c.start(Piece.Color.white, t0 + 13_000)
        c.tick(t0 + 14_000)                               // 1 s de plus aux blancs
        assertEquals(180_000 - 4_000 + 2_000 - 1_000, c.remaining(Piece.Color.white))
        assertEquals(180_000 - 9_000 + 2_000, c.remaining(Piece.Color.black))
    }

    @Test fun `l'affichage passe aux dixièmes sous dix secondes`() {
        val en = java.util.Locale.ENGLISH
        assertEquals("03:00", GameClock.format(180_000, en))
        assertEquals("00:10", GameClock.format(10_000, en))
        assertEquals("9.4", GameClock.format(9_400, en))
        assertEquals("0.0", GameClock.format(0, en))
    }

    @Test fun `le séparateur décimal suit la langue, et il est choisi`() {
        // Sans Locale explicite, `String.format` prenait celle de la machine :
        // le même APK affichait « 9.4 » ou « 9,4 » selon l'appareil, sans que
        // personne l'ait décidé.
        assertEquals("9,4", GameClock.format(9_400, java.util.Locale.FRENCH))
        assertEquals("9.4", GameClock.format(9_400, java.util.Locale.ENGLISH))
    }
}
