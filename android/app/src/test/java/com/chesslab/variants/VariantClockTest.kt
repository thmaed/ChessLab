package com.chesslab.variants

import chesskit.Piece
import com.chesslab.play.TimeControl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * La pendule des variantes : ce qu'elle rend SANS tourner.
 *
 * Le décompte lui-même dépend d'une horloge réelle et se vérifie sur
 * l'appareil ; ce qui se vérifie ici est ce qui se trompait en silence — un
 * budget de réflexion calculé sur un temps qui n'existe pas, ou un incrément
 * crédité à un camp qui n'a rien joué.
 */
class VariantClockTest {

    private fun clock(control: TimeControl) =
        VariantClock(CoroutineScope(Job())).apply { reset(control) }

    @Test fun `sans cadence il n'y a rien a afficher`() {
        val c = clock(TimeControl.byId("none"))
        assertTrue(!c.hasClock)
        assertNull(c.remaining(Piece.Color.white))
    }

    @Test fun `une cadence donne le meme temps aux deux camps`() {
        val c = clock(TimeControl.custom(5, 3))
        assertEquals(300_000L, c.remaining(Piece.Color.white))
        assertEquals(300_000L, c.remaining(Piece.Color.black))
    }

    /**
     * Sans pendule, le moteur prend un temps FIXE — le même que sur iPhone.
     *
     * Android en avait fait un réglage à quatre vitesses ; iOS n'en offre
     * aucun (`PlayViewModel.baseMovetime`, 900 ms), et deux apps qui ne
     * réfléchissent pas aussi longtemps ne jouent pas au même niveau. Le
     * chiffre ne doit en tout cas pas dépendre d'un temps restant qui
     * n'existe pas.
     */
    @Test fun `sans pendule le moteur prend le temps d'iOS`() {
        assertEquals(900, com.chesslab.play.ENGINE_MOVETIME_MS)
        assertEquals(900, clock(TimeControl.byId("none")).movetimeFor(Piece.Color.white))
    }

    /**
     * Avec pendule, il se rationne : un trentième du temps qui reste, plus le
     * gros de l'incrément. Sur 5 minutes + 3 s : 300/30 + 2,4 = 12,4 s, borné
     * par le quart des 300 s — donc 12,4 s.
     */
    @Test fun `avec pendule le moteur se rationne`() {
        val c = clock(TimeControl.custom(5, 3))
        assertEquals(12_400, c.movetimeFor(Piece.Color.white))
    }

    /**
     * Le plafond mord quand il reste très peu : à une minute sans incrément,
     * un trentième fait 2 s, et le quart du temps restant en autorise 15 — le
     * moteur prend donc bien 2 s, pas 15.
     */
    @Test fun `le moteur ne depense jamais plus du quart de ce qui reste`() {
        val c = clock(TimeControl.custom(1, 0))
        assertEquals(2_000, c.movetimeFor(Piece.Color.white))
    }

    /** Trente secondes est le plafond absolu : une cadence longue ne fait pas patienter. */
    @Test fun `le moteur ne reflechit jamais plus de trente secondes`() {
        val c = clock(TimeControl.custom(180, 0))
        assertTrue(c.movetimeFor(Piece.Color.white) <= 30_000)
    }

    /**
     * L'incrément s'ajoute au camp qui vient de jouer, et à lui seul. Sans
     * décompte en cours, personne n'a joué : rien ne doit être crédité — sinon
     * une partie sans coup offrirait des secondes à chaque passage d'écran.
     */
    @Test fun `sans camp en cours personne ne touche l'increment`() {
        val c = clock(TimeControl.custom(5, 3))
        c.stopAndIncrement()
        assertEquals(300_000L, c.remaining(Piece.Color.white))
        assertEquals(300_000L, c.remaining(Piece.Color.black))
    }
}
