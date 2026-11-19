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
        d.onUtterance = { heard += it }
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
