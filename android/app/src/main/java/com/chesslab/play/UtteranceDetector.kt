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
 * Le SILENCE se juge sur le niveau LISSÉ (la médiane du dernier dixième de seconde) et par rapport à la voix de la
 * phrase (20 dB sous elle, c'est qu'on ne parle plus) : iPhone3, 20/11/2026, chaque phrase durait les 6 s du maximum —
 * jugé tampon par tampon, le moindre pic du bruit de fond relançait le compte du silence.
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
    /**
     * L'essai ANTICIPÉ (20/11/2026) : la phrase a déjà été rendue après une courte pause ; le jeton change dès que la
     * parole reprend ou que la phrase se termine, ce qui périme l'essai.
     */
    private var pauseSent = false
    private var pauseToken = 0
    /** Les niveaux des derniers tampons (un dixième de seconde) et la voix la plus forte de la phrase. */
    private val recent = ArrayDeque<Float>()
    private var peak = -120f

    /**
     * Une phrase complète (échantillons 16 bits mis bout à bout), rendue sur le fil du micro. Le second argument :
     * finie SANS reprise de la parole depuis sa pause, le jeton de cette pause — sa reconnaissance anticipée vaut pour
     * elle, à reprendre au lieu d'en lancer une seconde en même temps (iPhone XS, 20/11/2026). Pendant de
     * `Utterance.pauseToken` (iOS).
     */
    var onUtterance: ((ShortArray, Int?) -> Unit)? = null

    /**
     * La phrase telle qu'elle est après [PAUSE_SILENCE] de silence, avec son jeton : si elle donne déjà un coup,
     * [claim] la prend et le coup se joue sans attendre la fin ([END_SILENCE]).
     */
    var onPause: ((ShortArray, Int) -> Unit)? = null

    fun setEnabled(on: Boolean) = synchronized(lock) {
        enabled = on
        recent.clear()
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
        pauseSent = false
        pauseToken += 1
        peak = -120f
    }

    /**
     * Prend la phrase rendue à la pause [token] si rien n'a bougé depuis (pas de reprise de la parole, phrase pas
     * encore finie) : elle est alors close, et ne reviendra pas par [onUtterance].
     */
    fun claim(token: Int): Boolean = synchronized(lock) {
        if (!enabled || !inSpeech || !pauseSent || token != pauseToken) return false
        reset()
        true
    }

    private fun joined(): ShortArray {
        val all = ShortArray(buffers.sumOf { it.size })
        var at = 0
        for (b in buffers) { b.copyInto(all, at); at += b.size }
        return all
    }

    /** [samples] : les [count] premiers échantillons comptent (le tampon d'`AudioRecord` est réutilisé). */
    fun ingest(samples: ShortArray, count: Int = samples.size) {
        if (count <= 0) return
        val seconds = count.toDouble() / sampleRate
        val level = level(samples, count)
        var finished: ShortArray? = null
        var finishedToken: Int? = null
        var paused: Pair<ShortArray, Int>? = null
        synchronized(lock) {
            if (!enabled) return
            val copy = samples.copyOf(count)
            recent.addLast(level)
            val window = max(1, Math.round(SMOOTHING_SECONDS / seconds).toInt())
            while (recent.size > window) recent.removeFirst()
            val steady = recent.sorted()[recent.size / 2]
            if (!inSpeech) {
                // Le bruit de fond suit lentement ce qu'on entend hors parole.
                noiseFloor = noiseFloor * 0.95f + min(steady, noiseFloor + 6) * 0.05f
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
            peak = max(peak, steady)
            if (steady > max(noiseFloor + 6, peak - BELOW_VOICE)) {
                if (pauseSent) {
                    // La parole reprend (« cavalier… f3 ») : l'essai anticipé ne vaut plus.
                    pauseSent = false
                    pauseToken += 1
                }
                speechSeconds += seconds
                silenceSeconds = 0.0
            } else {
                silenceSeconds += seconds
            }
            if (silenceSeconds >= END_SILENCE || totalSeconds >= MAXIMUM_LENGTH) {
                // Un bruit bref (le son d'un coup, une porte) n'est pas une phrase.
                if (speechSeconds >= MINIMUM_SPEECH) {
                    finished = joined()
                    if (pauseSent) finishedToken = pauseToken
                }
                reset()
            } else if (!pauseSent && silenceSeconds >= PAUSE_SILENCE && speechSeconds >= MINIMUM_SPEECH) {
                pauseSent = true
                pauseToken += 1
                paused = joined() to pauseToken
            }
        }
        paused?.let { (samples, token) -> onPause?.invoke(samples, token) }
        finished?.let { onUtterance?.invoke(it, finishedToken) }
    }

    companion object {
        const val END_SILENCE = 0.7
        const val PAUSE_SILENCE = 0.3
        const val MINIMUM_SPEECH = 0.35
        const val MAXIMUM_LENGTH = 6.0
        const val PRE_ROLL_SECONDS = 0.3
        const val SMOOTHING_SECONDS = 0.1
        /** Sous la voix de la phrase d'autant, c'est du silence, même si le bruit de fond a été mal estimé. */
        const val BELOW_VOICE = 20f

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
