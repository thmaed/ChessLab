package com.chesslab.play

import kotlin.math.ceil
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Découpe le flux du micro en PHRASES : un début quand le son monte nettement au-dessus du bruit de fond, une fin
 * après 0,7 s de silence. Pendant de `UtteranceDetector` (`VoiceMoveListener.swift`), mêmes seuils ; ici sur des
 * tampons 16 bits (ce que rend `AudioRecord`). Tourne sur le fil de lecture du micro : tout est sous verrou.
 *
 * Pur (aucun micro) : les tests le nourrissent de sons fabriqués.
 */
class UtteranceDetector(private val sampleRate: Int) {
    private val lock = Any()
    private var buffers = mutableListOf<ShortArray>()
    private var preRoll = ArrayDeque<ShortArray>()
    private var noiseFloor = -55f
    private var loudRun = 0
    private var inSpeech = false
    private var speechSeconds = 0.0
    private var silenceSeconds = 0.0
    private var totalSeconds = 0.0
    private var enabled = false

    /** Une phrase complète (échantillons 16 bits mis bout à bout), rendue sur le fil du micro. */
    var onUtterance: ((ShortArray) -> Unit)? = null

    fun setEnabled(on: Boolean) = synchronized(lock) {
        enabled = on
        reset()
    }

    private fun reset() {
        buffers = mutableListOf()
        preRoll = ArrayDeque()
        inSpeech = false
        loudRun = 0
        speechSeconds = 0.0
        silenceSeconds = 0.0
        totalSeconds = 0.0
    }

    /** [samples] : les [count] premiers échantillons comptent (le tampon d'`AudioRecord` est réutilisé). */
    fun ingest(samples: ShortArray, count: Int = samples.size) {
        if (count <= 0) return
        val seconds = count.toDouble() / sampleRate
        val level = level(samples, count)
        var finished: ShortArray? = null
        synchronized(lock) {
            if (!enabled) return
            val copy = samples.copyOf(count)
            if (!inSpeech) {
                // Le bruit de fond suit lentement ce qu'on entend hors parole.
                noiseFloor = noiseFloor * 0.95f + min(level, noiseFloor + 6) * 0.05f
                preRoll.addLast(copy)
                val maxPreRoll = ceil(PRE_ROLL_SECONDS / seconds).toInt()
                while (preRoll.size > maxPreRoll) preRoll.removeFirst()
                loudRun = if (level > max(noiseFloor + 12, -50f)) loudRun + 1 else 0
                if (loudRun >= 2) {
                    inSpeech = true
                    buffers = preRoll.toMutableList()
                    preRoll = ArrayDeque()
                    speechSeconds = 0.0
                    silenceSeconds = 0.0
                    totalSeconds = 0.0
                }
                return
            }
            buffers += copy
            totalSeconds += seconds
            if (level > noiseFloor + 6) {
                speechSeconds += seconds
                silenceSeconds = 0.0
            } else {
                silenceSeconds += seconds
            }
            if (silenceSeconds >= END_SILENCE || totalSeconds >= MAXIMUM_LENGTH) {
                // Un bruit bref (le son d'un coup, une porte) n'est pas une phrase.
                if (speechSeconds >= MINIMUM_SPEECH) {
                    val all = ShortArray(buffers.sumOf { it.size })
                    var at = 0
                    for (b in buffers) { b.copyInto(all, at); at += b.size }
                    finished = all
                }
                reset()
            }
        }
        finished?.let { onUtterance?.invoke(it) }
    }

    companion object {
        const val END_SILENCE = 0.7
        const val MINIMUM_SPEECH = 0.35
        const val MAXIMUM_LENGTH = 6.0
        const val PRE_ROLL_SECONDS = 0.3

        /** Le niveau en dB pleine échelle (0 = le plus fort possible), comme sur iOS. */
        fun level(samples: ShortArray, count: Int = samples.size): Float {
            if (count <= 0) return -120f
            var sum = 0.0
            for (i in 0 until count) {
                val v = samples[i] / 32768.0
                sum += v * v
            }
            val rms = sqrt(sum / count)
            return (20 * log10(max(rms, 1e-7))).toFloat()
        }
    }
}
