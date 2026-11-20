package com.chesslab.play

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random

/** La découpe des phrases au niveau sonore (19/11/2026), sur des sons fabriqués : un murmure de fond, une voix. */
class UtteranceDetectorTest {
    private val rate = 16_000
    /** Des tampons de 100 ms, comme un `AudioRecord` ordinaire. */
    private val chunk = rate / 10
    private val random = Random(7)

    private fun noise() = ShortArray(chunk) { (random.nextInt(-60, 60)).toShort() }          // ≈ -60 dB
    private fun voice() = ShortArray(chunk) { (8000 * sin(2 * PI * 220 * it / rate)).toInt().toShort() } // ≈ -15 dB

    private fun detector(): Pair<UtteranceDetector, MutableList<ShortArray>> {
        val heard = mutableListOf<ShortArray>()
        val d = UtteranceDetector(rate)
        d.onUtterance = { samples, _ -> heard += samples }
        d.setEnabled(true)
        return d to heard
    }

    @Test fun `une phrase entre deux silences est rendue entière, avec ce qui la précède`() {
        val (d, heard) = detector()
        repeat(20) { d.ingest(noise()) }
        repeat(8) { d.ingest(voice()) }      // 0,8 s de parole
        repeat(10) { d.ingest(noise()) }     // 1 s de silence : la phrase est finie après 0,7 s
        assertEquals(1, heard.size)
        // La parole (0,8 s), le pré-enregistrement (0,3 s) et le silence de fin (0,7 s), à un tampon près.
        val seconds = heard[0].size.toDouble() / rate
        assertTrue("durée $seconds", seconds in 1.5..2.0)
    }

    /** Pendant de `UtteranceDetectorTests` (iOS) pour l'essai ANTICIPÉ (20/11/2026). */
    private fun detectorWithPauses(): Triple<UtteranceDetector, MutableList<ShortArray>, MutableList<Pair<ShortArray, Int>>> {
        val (d, heard) = detector()
        val pauses = mutableListOf<Pair<ShortArray, Int>>()
        d.onPause = { samples, token -> pauses += samples to token }
        return Triple(d, heard, pauses)
    }

    /**
     * iPhone3, 20/11/2026 : des tampons de 20 ms et un bruit de fond qui a des pics. Jugée tampon par tampon, la
     * phrase ne finissait jamais (6 s à chaque fois) ; lissée, elle finit au silence.
     */
    @Test fun `un fond bruité à pics ne garde pas la phrase ouverte`() {
        val (d, heard, pauses) = detectorWithPauses()
        val short = rate / 50
        var tick = 0
        fun background(): ShortArray {
            tick += 1
            val spike = if (tick % 4 == 0) 650 else 65                // un tampon sur quatre à ≈ -40 dB
            return ShortArray(short) { random.nextInt(-spike, spike).toShort() }
        }
        val voice = ShortArray(short) { (8000 * sin(2 * PI * 220 * it / rate)).toInt().toShort() }
        repeat(100) { d.ingest(background()) }      // 2 s de fond
        repeat(40) { d.ingest(voice) }              // 0,8 s de parole
        repeat(50) { d.ingest(background()) }       // 1 s de fond
        assertEquals(1, heard.size)
        assertTrue("finie au silence, pas à la durée maximale", heard[0].size.toDouble() / rate < 2.2)
        assertEquals("l'essai anticipé a sa chance", 1, pauses.size)
    }

    @Test fun `une courte pause offre la phrase tôt et la prendre la close`() {
        val (d, heard, pauses) = detectorWithPauses()
        repeat(20) { d.ingest(noise()) }
        repeat(8) { d.ingest(voice()) }
        repeat(3) { d.ingest(noise()) }
        assertEquals("après 0,3 s de silence, la phrase est offerte", 1, pauses.size)
        assertTrue(heard.isEmpty())
        assertTrue(d.claim(pauses[0].second))
        repeat(10) { d.ingest(noise()) }
        assertTrue("prise à la pause, elle ne revient pas en fin de phrase", heard.isEmpty())
        assertEquals("on ne la prend qu'une fois", false, d.claim(pauses[0].second))
    }

    @Test fun `reprendre la parole après la pause périme l'essai anticipé`() {
        val (d, heard, pauses) = detectorWithPauses()
        repeat(20) { d.ingest(noise()) }
        repeat(6) { d.ingest(voice()) }     // « cavalier »
        repeat(4) { d.ingest(noise()) }     // on cherche la case
        repeat(4) { d.ingest(voice()) }     // « f3 »
        assertEquals(1, pauses.size)
        assertEquals("la parole a repris : l'essai est périmé", false, d.claim(pauses[0].second))
        repeat(10) { d.ingest(noise()) }
        assertEquals("une nouvelle pause offre la phrase entière", 2, pauses.size)
        assertEquals("non prise, la phrase entière arrive à la fin", 1, heard.size)
        assertTrue(heard[0].size.toDouble() / rate > 2)
    }

    /** iPhone XS, 20/11/2026 : la phrase finie sans reprise de la parole porte le jeton de sa (dernière) pause. */
    @Test fun `une phrase finie juste après sa pause en porte le jeton`() {
        val tokens = mutableListOf<Int?>()
        val pauses = mutableListOf<Int>()
        val d = UtteranceDetector(rate)
        d.onUtterance = { _, token -> tokens += token }
        d.onPause = { _, token -> pauses += token }
        d.setEnabled(true)
        repeat(20) { d.ingest(noise()) }
        repeat(8) { d.ingest(voice()) }
        repeat(10) { d.ingest(noise()) }
        assertEquals(pauses.first(), tokens.first())
        repeat(6) { d.ingest(voice()) }
        repeat(4) { d.ingest(noise()) }
        repeat(4) { d.ingest(voice()) }     // la parole reprend après la pause
        repeat(10) { d.ingest(noise()) }
        assertEquals(2, tokens.size)
        assertEquals("le jeton de la DERNIÈRE pause", pauses.last(), tokens[1])
        assertTrue(tokens[1] != pauses[1])
    }

    @Test fun `une phrase finie sans être prise ne se prend plus`() {
        val (d, heard, pauses) = detectorWithPauses()
        repeat(20) { d.ingest(noise()) }
        repeat(8) { d.ingest(voice()) }
        repeat(10) { d.ingest(noise()) }
        assertEquals(1, pauses.size)
        assertEquals(1, heard.size)
        assertEquals("rien ne se joue deux fois", false, d.claim(pauses[0].second))
    }

    @Test fun `un bruit bref n'est pas une phrase`() {
        val (d, heard) = detector()
        repeat(20) { d.ingest(noise()) }
        repeat(2) { d.ingest(voice()) }      // 0,2 s : le son d'une pièce posée
        repeat(10) { d.ingest(noise()) }
        assertTrue(heard.isEmpty())
    }

    @Test fun `une phrase interminable est coupée à six secondes`() {
        val (d, heard) = detector()
        repeat(20) { d.ingest(noise()) }
        repeat(80) { d.ingest(voice()) }
        assertEquals(1, heard.size)
    }

    @Test fun `éteint, il n'entend rien`() {
        val (d, heard) = detector()
        d.setEnabled(false)
        repeat(20) { d.ingest(noise()) }
        repeat(8) { d.ingest(voice()) }
        repeat(10) { d.ingest(noise()) }
        assertTrue(heard.isEmpty())
    }

    @Test fun `le niveau d'un silence parfait est le plancher`() {
        assertEquals(-140f, UtteranceDetector.level(ShortArray(100)), 0.5f)
    }
}
