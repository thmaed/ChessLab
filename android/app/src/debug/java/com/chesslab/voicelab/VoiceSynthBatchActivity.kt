package com.chesslab.voicelab

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.WindowManager
import android.widget.TextView
import chesskit.Board
import chesskit.Position
import com.chesslab.play.VoiceMoveParser
import com.chesslab.play.VoiceRecognizers
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import kotlin.concurrent.thread
import kotlin.coroutines.resume

/**
 * BANC DE VOIX SYNTHÉTIQUES (21/11/2026) — DÉBOGAGE SEULEMENT. Fait passer par la reconnaissance SUR L'APPAREIL des
 * enregistrements fabriqués par `tools/voix-synthese/generer.py` (une voix du Mac lit chaque coup, dans chaque langue)
 * et écrit ce que le moteur a entendu, pour le comparer au coup attendu (`SynthEvalTest`). Mêmes indices et même
 * intention que `VoiceMoveListener` : on mesure ce que fait l'app, pas un cas d'école.
 *
 * Entrée : `files/synth/index.jsonl` + `files/synth/bundle.bin` (PCM 16 kHz, 16 bits, mono). Sortie :
 * `files/synth/out.jsonl`, une ligne par enregistrement, puis le fichier `done`. Lancé par `tools/voix-synthese/mesurer.sh`.
 */
class VoiceSynthBatchActivity : Activity() {
    private val scope = CoroutineScope(Dispatchers.Main)
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        status = TextView(this).apply { textSize = 16f; setPadding(32, 64, 32, 32); text = "Banc de voix synthétiques…" }
        setContentView(status)
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
            status.text = "Autorisez le micro puis relancez."
            return
        }
        scope.launch { run() }
    }

    override fun onDestroy() {
        scope.coroutineContext[kotlinx.coroutines.Job]?.cancel()
        super.onDestroy()
    }

    private suspend fun run() {
        val dir = File(filesDir, "synth")
        val rows = File(dir, "index.jsonl").readLines().filter { it.isNotBlank() }.map { JSONObject(it) }
        val bundle = File(dir, "bundle.bin").readBytes()
        val out = File(dir, "out.jsonl").apply { writeText("") }
        File(dir, "done").delete()
        // Comme l'app : la variante de langue dont le paquet est INSTALLÉ (« fr-CH » sur ce Galaxy), sinon erreur 13.
        // Le résultat de la vérification est consigné dans `avail.txt`, une ligne par langue.
        val availability = File(dir, "avail.txt").apply { writeText("") }
        val usable = HashMap<String, Boolean>()
        for (language in rows.map { it.getString("lang") }.distinct()) {
            val state = suspendCancellableCoroutine<VoiceRecognizers.Availability> { cont ->
                VoiceRecognizers.availability(this, language) { if (cont.isActive) cont.resume(it) }
            }
            usable[language] = state != VoiceRecognizers.Availability.unavailable
            availability.appendText("$language : $state\n")
        }
        var recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        var current = ""
        for ((index, row) in rows.withIndex()) {
            status.text = "${index + 1} / ${rows.size} — ${row.getString("lang")} · ${row.getString("text")}"
            val language = row.getString("lang")
            val vocabulary = VoiceMoveParser.vocabulary(language)
            val hints = runCatching {
                VoiceMoveParser.spokenForms(VoiceMoveParser.candidates(Board(Position.fromFen(row.getString("fen"))!!)), vocabulary)
            }.getOrDefault(emptyList())
            if (usable[language] == false) {
                out.appendText(JSONObject().put("id", row.getString("id")).put("transcripts", JSONArray())
                    .put("error", "langue indisponible").toString() + "\n")
                continue
            }
            // Un reconnaisseur NEUF à chaque changement de langue : après l'espagnol, le même rendait des phrases vides
            // pour le français et l'italien (essai du 21/11/2026).
            if (language != current) {
                recognizer.destroy()
                recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                current = language
                delay(1000)
            }
            val audio = bundle.copyOfRange(row.getInt("offset"), row.getInt("offset") + row.getInt("length"))
            val (transcripts, error) = recognize(recognizer, language, audio, hints)
            out.appendText(JSONObject().put("id", row.getString("id")).put("transcripts", JSONArray(transcripts))
                .put("error", error ?: JSONObject.NULL).toString() + "\n")
            delay(300)
        }
        recognizer.destroy()
        File(dir, "done").writeText("ok")
        status.text = "Terminé : ${rows.size} enregistrements → synth/out.jsonl"
    }

    /** Pendant de `VoiceMoveListener.hear` : indices, résultats partiels (le final peut arriver vide), délai borné. */
    private suspend fun recognize(
        recognizer: SpeechRecognizer, language: String, audio: ByteArray, hints: List<String>,
    ): Pair<List<String>, String?> {
        val pipe = try { ParcelFileDescriptor.createPipe() } catch (e: IOException) { return emptyList<String>() to "tube" }
        val answer = withTimeoutOrNull(12_000) {
            suspendCancellableCoroutine<Pair<List<String>, String?>> { continuation ->
                var done = false
                var lastPartial: List<String> = emptyList()
                fun finish(value: Pair<List<String>, String?>) {
                    if (done) return
                    done = true
                    continuation.resume(value)
                }
                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onResults(results: Bundle?) {
                        val final = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                        finish(final.ifEmpty { lastPartial } to null)
                    }
                    override fun onError(error: Int) {
                        finish(lastPartial to if (error == SpeechRecognizer.ERROR_NO_MATCH) "erreur 7" else "erreur $error")
                    }
                    override fun onPartialResults(partialResults: Bundle?) {
                        val partial = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                        if (partial.isNotEmpty()) lastPartial = partial
                    }
                    override fun onReadyForSpeech(params: Bundle?) = Unit
                    override fun onBeginningOfSpeech() = Unit
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() = Unit
                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                })
                val intent = VoiceRecognizers.intent(language)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16_000)
                    .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                if (hints.isNotEmpty()) intent.putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(hints))
                try { recognizer.startListening(intent) } catch (e: Exception) { finish(emptyList<String>() to "démarrage") }
                thread(name = "synth-feed") {
                    try {
                        ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { out ->
                            out.write(audio)
                            out.write(ByteArray(16_000 * 2 * 7 / 10)) // 0,7 s de silence : la fin de phrase de l'app (plus, le français rendait des phrases vides)
                        }
                    } catch (_: IOException) { }
                }
            }
        } ?: (emptyList<String>() to "délai")
        runCatching { recognizer.cancel() }
        runCatching { pipe[0].close() }
        return answer
    }
}
