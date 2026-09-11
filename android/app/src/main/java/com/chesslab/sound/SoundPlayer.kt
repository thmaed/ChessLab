package com.chesslab.sound

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

/**
 * Les sons du plateau, SYNTHÉTISÉS — traduction de `SoundPlayer.swift`.
 *
 * Aucun fichier audio n'est embarqué, côté iOS comme ici : chaque son est une
 * somme de sinusoïdes sous une enveloppe percussive, avec les mêmes fréquences
 * et les mêmes durées. Rien à licencier, rien à télécharger, et un son qui ne
 * dépend pas du décodeur de l'appareil.
 */
object SoundPlayer {

    private const val SAMPLE_RATE = 44_100

    enum class Event(val frequencies: DoubleArray, val duration: Double) {
        move(doubleArrayOf(880.0), 0.07),
        capture(doubleArrayOf(660.0, 990.0), 0.09),
        castle(doubleArrayOf(523.0, 659.0, 784.0), 0.14),
        check(doubleArrayOf(988.0, 1318.0), 0.16),
    }

    private val cache = HashMap<Event, ShortArray>()

    var enabled: Boolean = true

    fun play(event: Event) {
        if (!enabled) return
        val samples = cache.getOrPut(event) { render(event) }
        runCatching { track(samples).play() }
    }

    /** Le même calcul que côté iOS : sinusoïdes / n, enveloppe e^(−18t), gain 0,5. */
    private fun render(event: Event): ShortArray {
        val frames = (SAMPLE_RATE * event.duration).toInt()
        val out = ShortArray(frames)
        for (frame in 0 until frames) {
            val t = frame.toDouble() / SAMPLE_RATE
            val envelope = exp(-t * 18)
            var sample = 0.0
            for (f in event.frequencies) sample += sin(2 * PI * f * t)
            sample = sample / event.frequencies.size * envelope * 0.5
            out[frame] = (sample * Short.MAX_VALUE).toInt().coerceIn(-32768, 32767).toShort()
        }
        return out
    }

    private fun track(samples: ShortArray): AudioTrack {
        val bytes = samples.size * 2
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bytes)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(samples, 0, samples.size)
        track.setNotificationMarkerPosition(samples.size)
        track.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
            override fun onMarkerReached(t: AudioTrack?) { t?.release() }
            override fun onPeriodicNotification(t: AudioTrack?) = Unit
        })
        return track
    }

    /** Le son qui convient à un coup : prise, roque, échec, ou déplacement. */
    fun forMove(isCapture: Boolean, isCastle: Boolean, isCheck: Boolean) = play(
        when {
            isCheck -> Event.check
            isCastle -> Event.castle
            isCapture -> Event.capture
            else -> Event.move
        }
    )
}
