package com.chesslab.play

import android.Manifest
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.IOException

/**
 * L'ÉCOUTE À MON TOUR (décision du 19/11/2026) : le micro s'ouvre seul quand c'est au joueur de jouer et que l'app ne
 * parle pas ; chaque phrase entendue est reconnue SUR L'APPAREIL et rendue en transcriptions. Rien n'est gardé : la
 * phrase passe dans un tube vers le reconnaisseur, puis disparaît. Pendant de `VoiceMoveListener` (iOS,
 * `VoiceMoveListener.swift`), même découpe (`UtteranceDetector`), même essai anticipé.
 *
 * Le micro est lu par NOUS (`AudioRecord`, 16 kHz, 16 bits) : le détecteur découpe les phrases, puis chacune est
 * donnée au reconnaisseur du système par `EXTRA_AUDIO_SOURCE` (Android 13+) — le reconnaisseur n'ouvre donc jamais le
 * micro lui-même, et rien ne se bat pour lui. Sous Android 13, pas de source audio donnée : voir
 * [VoiceRecognizers.availability], qui grise la ligne « Coups à la voix » et le dit.
 *
 * UNE SEULE reconnaissance à la fois (comme iOS) : la fin de phrase REPREND l'essai anticipé en cours au lieu d'en
 * lancer une seconde. Tout l'état vit sur le fil principal ; le fil du micro ne fait que passer les tampons au
 * détecteur, qui rappelle ici par [Handler].
 */
class VoiceMoveListener(context: Context, private val language: () -> String) {
    private val app = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val debuggable = app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    private val statusFlow = MutableStateFlow(VoiceListenStatus.starting)
    val status: StateFlow<VoiceListenStatus> get() = statusFlow

    /** Les transcriptions d'une phrase, à confronter à la position. */
    var onTranscripts: ((List<String>) -> Unit)? = null
    /** Ces transcriptions donnent-elles déjà un coup sûr ? Si oui, l'essai anticipé le joue sans attendre la fin. */
    var isDecisive: ((List<String>) -> Boolean)? = null

    private val detector = UtteranceDetector(SAMPLE_RATE)
    private var recognizer: SpeechRecognizer? = null
    private var record: AudioRecord? = null
    private var reader: Thread? = null
    @Volatile private var capturing = false
    private var running = false
    /** Change à chaque [start] et [stop] : une réponse arrivée après coup (disponibilité, reconnaissance) se périme. */
    private var generation = 0
    private var wantsToListen = false
    private var hints: List<String> = emptyList()
    private var recognizing = false

    /** Le dernier essai anticipé et le jeton de sa pause ; [waiting] : la fin de phrase qui attend son résultat. */
    private class Early(val token: Int) {
        var result: List<String>? = null
        var waiting: ((List<String>) -> Unit)? = null
    }
    private var early: Early? = null
    private var busy = false
    private var lastSpeaking = false
    private val watchVoice = object : Runnable {
        override fun run() {
            if (!running) return
            val speaking = BlindfoldVoice.isSpeaking
            if (speaking != lastSpeaking) {
                lastSpeaking = speaking
                refresh()
            }
            main.postDelayed(this, WATCH_MILLIS)
        }
    }

    /** Autorisation, reconnaissance sur l'appareil, micro. Appelé à l'ouverture de la partie, sur le fil principal. */
    fun start() {
        if (running) return
        val mine = ++generation
        statusFlow.value = VoiceListenStatus.starting
        if (app.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            statusFlow.value = VoiceListenStatus.denied
            return
        }
        VoiceRecognizers.availability(app, language()) { availability ->
            if (mine != generation) return@availability
            if (availability != VoiceRecognizers.Availability.available) {
                statusFlow.value = VoiceListenStatus.unavailable
                return@availability
            }
            open()
        }
    }

    private fun open() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            statusFlow.value = VoiceListenStatus.unavailable
            return
        }
        val minimum = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minimum <= 0) { statusFlow.value = VoiceListenStatus.unavailable; return }
        val audio = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(minimum, SAMPLE_RATE / 2),
            )
        } catch (e: SecurityException) {
            statusFlow.value = VoiceListenStatus.denied
            return
        }
        if (audio.state != AudioRecord.STATE_INITIALIZED) {
            audio.release()
            statusFlow.value = VoiceListenStatus.unavailable
            return
        }
        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(app)
        detector.onUtterance = { samples, token -> main.post { onUtterance(samples, token) } }
        detector.onPause = { samples, token -> main.post { onPause(samples, token) } }
        try {
            audio.startRecording()
        } catch (e: IllegalStateException) {
            audio.release()
            recognizer?.destroy(); recognizer = null
            statusFlow.value = VoiceListenStatus.unavailable
            return
        }
        record = audio
        capturing = true
        running = true
        if (debuggable) Log.d(TAG, "micro ouvert (${SAMPLE_RATE} Hz), langue ${VoiceRecognizers.intent(language()).getStringExtra(RecognizerIntent.EXTRA_LANGUAGE)}")
        reader = Thread({
            val buffer = ShortArray(SAMPLE_RATE / 10)
            var peak = -120f
            var lastLevelLog = System.currentTimeMillis()
            while (capturing) {
                val count = audio.read(buffer, 0, buffer.size)
                if (count > 0) {
                    detector.ingest(buffer, count)
                    if (debuggable) {
                        peak = maxOf(peak, UtteranceDetector.level(buffer, count))
                        if (System.currentTimeMillis() - lastLevelLog > 3_000) {
                            Log.d(TAG, "niveau du micro (3 s) : crête ${"%.0f".format(peak)} dB")
                            peak = -120f
                            lastLevelLog = System.currentTimeMillis()
                        }
                    }
                } else if (count < 0) break
            }
        }, "voice-move-mic").also { it.start() }
        lastSpeaking = BlindfoldVoice.isSpeaking
        main.postDelayed(watchVoice, WATCH_MILLIS)
        refresh()
    }

    fun stop() {
        generation += 1
        early = null
        busy = false
        recognizing = false
        capturing = false
        running = false
        main.removeCallbacksAndMessages(null)
        detector.setEnabled(false)
        reader?.let { try { it.join(300) } catch (_: InterruptedException) { } }
        reader = null
        record?.let {
            try { it.stop() } catch (_: IllegalStateException) { }
            it.release()
        }
        record = null
        recognizer?.let { try { it.cancel() } catch (_: Exception) { }; it.destroy() }
        recognizer = null
    }

    /** C'est au joueur de jouer (ou plus) ; [hints] : les façons de dire les coups légaux, pour la reconnaissance. */
    fun setTurn(isMine: Boolean, hints: List<String>) {
        wantsToListen = isMine
        this.hints = hints
        refresh()
    }

    private fun refresh() {
        if (!running) return
        val listening = wantsToListen && !recognizing && !BlindfoldVoice.isSpeaking
        detector.setEnabled(listening)
        val next = when {
            recognizing -> VoiceListenStatus.recognizing
            listening -> VoiceListenStatus.listening
            else -> VoiceListenStatus.waiting
        }
        if (debuggable && next != statusFlow.value) Log.d(TAG, "état : ${statusFlow.value} → $next")
        statusFlow.value = next
    }

    // L'essai ANTICIPÉ (20/11/2026) : après PAUSE_SILENCE, la phrase est reconnue ; si elle donne déjà un coup sûr et
    // que personne n'a repris la parole entre-temps, le coup se joue. Sinon rien ne change : la phrase complète
    // arrivera par [onUtterance].
    private fun onPause(samples: ShortArray, token: Int) {
        val decisive = isDecisive ?: return
        if (!running || !wantsToListen || recognizing || busy) return
        val attempt = Early(token)
        early = attempt
        hear(samples) { transcripts ->
            attempt.result = transcripts
            val waiting = attempt.waiting
            if (waiting != null) {
                waiting(transcripts)
                return@hear
            }
            if (!running || !wantsToListen || recognizing || transcripts.isEmpty() || !decisive(transcripts) ||
                !detector.claim(token)
            ) {
                trace("essai anticipé écarté", samples, transcripts)
                return@hear
            }
            trace("essai anticipé JOUÉ", samples, transcripts)
            onTranscripts?.invoke(transcripts)
        }
    }

    private fun onUtterance(samples: ShortArray, pauseToken: Int?) {
        if (!running || !wantsToListen) return
        recognizing = true
        refresh()
        val attempt = early
        when {
            attempt != null && pauseToken != null && attempt.token == pauseToken -> {
                // Rien dit depuis la pause : l'essai anticipé reconnaît déjà ce son-là.
                val finish = { transcripts: List<String> -> finish(samples, "phrase (essai anticipé repris)", transcripts) }
                val ready = attempt.result
                if (ready != null) finish(ready) else attempt.waiting = finish
            }
            busy && attempt != null -> {
                // Un essai plus ancien tourne encore : on attend qu'il finisse, puis on reconnaît CETTE phrase.
                attempt.waiting = { _ -> hear(samples) { finish(samples, "phrase", it) } }
            }
            else -> hear(samples) { finish(samples, "phrase", it) }
        }
    }

    private fun finish(samples: ShortArray, what: String, transcripts: List<String>) {
        trace(what, samples, transcripts)
        early = null
        recognizing = false
        if (running && transcripts.isNotEmpty()) onTranscripts?.invoke(transcripts)
        refresh()
    }

    /** Reconnaît [samples] sur l'appareil ; [done] est rappelé UNE fois sur le fil principal (vide si rien compris). */
    private fun hear(samples: ShortArray, done: (List<String>) -> Unit) {
        val engine = recognizer
        if (engine == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) { done(emptyList()); return }
        val pipe = try { ParcelFileDescriptor.createPipe() } catch (e: IOException) { done(emptyList()); return }
        val mine = generation
        busy = true
        var answered = false
        var lastPartial: List<String> = emptyList()
        val answer = { transcripts: List<String> ->
            if (!answered) {
                answered = true
                busy = false
                try { pipe[0].close() } catch (_: IOException) { }
                if (mine == generation) done(transcripts)
            }
        }
        val timeout = Runnable { try { engine.cancel() } catch (_: Exception) { }; answer(emptyList()) }
        main.postDelayed(timeout, RECOGNITION_TIMEOUT_MILLIS)
        engine.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                main.removeCallbacks(timeout)
                if (debuggable) {
                    Log.d(TAG, "réponse : clés ${results?.keySet()}, hypothèses " +
                        "${results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)}, " +
                        "confiances ${results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)?.toList()}")
                }
                // Le résultat FINAL peut arriver vide alors que le service a entendu des mots (Galaxy, 21/11/2026) :
                // le dernier résultat partiel les a.
                answer(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty().ifEmpty { lastPartial })
            }
            override fun onError(error: Int) {
                main.removeCallbacks(timeout)
                if (debuggable) Log.d(TAG, "reconnaissance : erreur $error")
                answer(emptyList())
            }
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) {
                val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                if (partial.isNotEmpty()) lastPartial = partial
                if (debuggable) Log.d(TAG, "partiel : $partial")
            }
            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        val intent = VoiceRecognizers.intent(language())
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        if (hints.isNotEmpty()) intent.putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(hints))
        try {
            engine.startListening(intent)
        } catch (e: Exception) {
            main.removeCallbacks(timeout)
            answer(emptyList())
            return
        }
        // Le son passe dans le tube, hors du fil principal ; le reconnaisseur lit jusqu'à la fin du tube. Il est
        // d'abord AMPLIFIÉ jusqu'à un niveau de voix normal : sur le Galaxy la source « reconnaissance vocale » ne donne
        // presque aucun gain (crête à −37 dB, 21/11/2026) et le reconnaisseur répondait à vide.
        val loud = normalized(samples)
        Thread({
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { out ->
                    val bytes = ByteArray(loud.size * 2)
                    for (i in loud.indices) {
                        bytes[2 * i] = (loud[i].toInt() and 0xFF).toByte()
                        bytes[2 * i + 1] = (loud[i].toInt() shr 8).toByte()
                    }
                    out.write(bytes)
                }
            } catch (_: IOException) { }
        }, "voice-move-pipe").start()
    }

    /** La phrase ramenée à une crête d'environ −3 dB (gain borné à +30 dB : jamais d'amplifier le bruit à l'infini). */
    private fun normalized(samples: ShortArray): ShortArray {
        var peak = 1
        for (v in samples) peak = maxOf(peak, kotlin.math.abs(v.toInt()))
        val gain = minOf(TARGET_PEAK.toDouble() / peak, MAX_GAIN)
        if (gain <= 1.05) return samples
        if (debuggable) Log.d(TAG, "amplification ×${"%.1f".format(gain)} (crête ${"%.0f".format(20 * kotlin.math.log10(peak / 32768.0))} dB)")
        return ShortArray(samples.size) { i ->
            (samples[i] * gain).toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
    }

    private fun trace(what: String, samples: ShortArray, transcripts: List<String>) {
        if (!debuggable) return
        Log.d(TAG, "$what ${"%.2f".format(samples.size.toDouble() / SAMPLE_RATE)} s → $transcripts")
    }

    companion object {
        const val SAMPLE_RATE = 16_000
        private const val WATCH_MILLIS = 150L
        private const val RECOGNITION_TIMEOUT_MILLIS = 8_000L
        private const val TAG = "ChessLabVoix"
        private const val TARGET_PEAK = 23_000
        private const val MAX_GAIN = 31.6
    }
}
