package com.chesslab.voicelab

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chesskit.Board
import chesskit.Position
import chesskit.Square
import com.chesslab.play.VoiceMoveParser
import com.chesslab.play.VoiceMoveParser.Candidate
import com.chesslab.play.VoiceMoveParser.Outcome
import com.chesslab.puzzles.Puzzle
import com.chesslab.puzzles.PuzzleRepository
import com.chesslab.ui.MoveNarration
import com.chesslab.ui.Palette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile
import java.util.UUID
import kotlin.concurrent.thread
import kotlin.coroutines.resume

/**
 * MESURE « coups à la voix » côté Android (19/11/2026) — DÉBOGAGE SEULEMENT, pendant de `VoiceDictationLab.swift`.
 * Mêmes essais (position de puzzle, coup légal tiré par genre, micro maintenu, essai < 1 s non compté, passage
 * automatique quand au moins une reconnaissance trouve), même journal (`files/voice-lab/trials.jsonl` + sons .wav).
 *
 * Deux reconnaissances, toutes deux SUR L'APPAREIL (`createOnDeviceSpeechRecognizer`) et nourries du MÊME
 * enregistrement (EXTRA_AUDIO_SOURCE) : A seule, B avec les façons de dire les coups légaux (EXTRA_BIASING_STRINGS).
 * Le reconnaisseur de Google ordinaire n'est PAS mesuré : il peut envoyer la voix sur le réseau.
 */
class VoiceDictationLabActivity : ComponentActivity() {
    private lateinit var lab: VoiceLab

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lab = VoiceLab(this)
        val ask = registerForActivityResult(ActivityResultContracts.RequestPermission()) { lab.start(it) }
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(background = Palette.background, primary = Palette.accent)) {
                Box(Modifier.fillMaxSize().background(Palette.background).safeDrawingPadding()) { LabScreen(lab) }
            }
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) lab.start(true)
        else ask.launch(Manifest.permission.RECORD_AUDIO)
    }

    override fun onDestroy() {
        lab.release()
        super.onDestroy()
    }
}

class VoiceLab(private val activity: Activity) {
    data class EngineResult(val engine: String, val transcripts: List<String>, val outcome: String,
                            val correct: Boolean, val millis: Long)
    data class Trial(val id: String, val date: Long, val fen: String, val target: Candidate,
                     val candidates: List<Candidate>, val results: List<EngineResult>)
    enum class Phase { idle, recording, analysing }

    companion object {
        val engines = listOf("A sur l'appareil", "B + indices")
        private const val RATE = 16_000
    }

    var phase by mutableStateOf(Phase.idle); private set
    var target by mutableStateOf<Candidate?>(null); private set
    var candidates by mutableStateOf(emptyList<Candidate>()); private set
    var last by mutableStateOf<Trial?>(null); private set
    var status by mutableStateOf(""); private set
    var modelStatus by mutableStateOf("modèle : vérification…"); private set
    val trials = mutableStateListOf<Trial>()

    /** La variante du français demandée au reconnaisseur : celle installée sur le téléphone (voir checkFrenchModel). */
    private var locale = com.chesslab.play.VoiceRecognizers.locale("fr")
    private var fen = ""
    private var positions: List<Puzzle> = emptyList()
    private val scope = MainScope()
    private val dir = File(activity.filesDir, "voice-lab").apply { mkdirs() }
    private val journal = File(dir, "trials.jsonl")

    private var recorder: AudioRecord? = null
    private var reader: Thread? = null
    @Volatile private var recording = false
    private val pcm = ByteArrayOutputStream()

    fun start(granted: Boolean) {
        loadJournal()
        scope.launch {
            positions = withContext(Dispatchers.IO) { PuzzleRepository.sample(activity.assets, 400) }
            nextPosition()
        }
        if (!granted) { status = "Micro refusé : la mesure ne peut pas enregistrer."; return }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            modelStatus = "Pas de reconnaissance SUR L'APPAREIL sur ce téléphone."
            return
        }
        checkFrenchModel()
    }

    /** Le modèle français est-il installé sur le téléphone ? Sinon on en demande le téléchargement (par le système). */
    private fun checkFrenchModel() {
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        val intent = baseIntent()
        recognizer.checkRecognitionSupport(intent, activity.mainExecutor, object : RecognitionSupportCallback {
            override fun onSupportResult(support: RecognitionSupport) {
                val installed = support.installedOnDeviceLanguages
                val french = installed.any { it.startsWith("fr") }
                // La variante INSTALLÉE (fr-CH sur un téléphone suisse) : demander fr-FR donnait l'erreur 13.
                locale = com.chesslab.play.VoiceRecognizers.locale("fr",
                    if (french) installed else support.supportedOnDeviceLanguages)
                modelStatus = when {
                    french -> "modèle français installé (${installed.filter { it.startsWith("fr") }.joinToString()}) · reconnaissance en $locale"
                    support.pendingOnDeviceLanguages.any { it.startsWith("fr") } -> "modèle français en téléchargement…"
                    support.supportedOnDeviceLanguages.any { it.startsWith("fr") } -> {
                        recognizer.triggerModelDownload(baseIntent())
                        "modèle français ($locale) demandé au système — réessayez dans un moment"
                    }
                    else -> "français NON proposé sur l'appareil (installées : ${installed.joinToString()})"
                }
                recognizer.destroy()
            }

            override fun onError(error: Int) {
                modelStatus = "support du français : erreur $error"
                recognizer.destroy()
            }
        })
    }

    private fun loadJournal() {
        trials.clear()
        if (!journal.exists()) return
        journal.readLines().filter { it.isNotBlank() }.forEach { line ->
            runCatching { trials += decode(JSONObject(line)) }
        }
    }

    /** Une position de puzzle et un coup à dire, tiré d'abord par GENRE (comme iOS). */
    fun nextPosition(keepingLast: Boolean = false) {
        repeat(50) {
            val puzzle = positions.randomOrNull() ?: return
            val position = Position.fromFen(puzzle.fen) ?: return@repeat
            val board = Board(position)
            puzzle.solution.firstOrNull()?.takeIf { it.length >= 4 }?.let {
                board.move(pieceAt = Square(it.take(2)), to = Square(it.drop(2).take(2)))
            }
            val legal = VoiceMoveParser.candidates(board)
            if (legal.isEmpty()) return@repeat
            val families = legal.groupBy {
                when {
                    it.isCastle -> "roque"; it.promotion != null -> "promotion"; 'x' in it.san -> "prise"
                    else -> it.piece.toString()
                }
            }
            val move = families.values.random().random()
            fen = board.position.fen
            candidates = legal
            target = move
            if (!keepingLast) last = null
            return
        }
    }

    // Enregistrer

    @SuppressLint("MissingPermission")
    fun beginRecording() {
        if (phase != Phase.idle || target == null) return
        val minimum = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val record = runCatching {
            AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(minimum, RATE * 2))
        }.getOrNull()
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            status = "Le micro ne démarre pas."
            return
        }
        synchronized(pcm) { pcm.reset() }
        recording = true
        record.startRecording()
        recorder = record
        reader = thread(name = "voice-lab-micro") {
            val buffer = ByteArray(3200)
            while (recording) {
                val read = record.read(buffer, 0, buffer.size)
                if (read > 0) synchronized(pcm) { pcm.write(buffer, 0, read) }
            }
        }
        phase = Phase.recording
    }

    fun endRecording() {
        if (phase != Phase.recording) return
        phase = Phase.analysing
        scope.launch {
            delay(250) // la fin du mot se perd si l'on coupe pile au relâchement
            recording = false
            withContext(Dispatchers.IO) { reader?.join() }
            recorder?.run { stop(); release() }
            recorder = null
            val audio = synchronized(pcm) { pcm.toByteArray() }
            if (audio.size < RATE * 2) { // moins d'une seconde
                status = "Trop court : gardez le doigt sur le micro pendant toute la phrase."
                phase = Phase.idle
                return@launch
            }
            status = ""
            analyse(audio)
        }
    }

    // Reconnaître

    private suspend fun analyse(audio: ByteArray) {
        val target = target ?: return
        val id = UUID.randomUUID().toString().uppercase()
        withContext(Dispatchers.IO) { writeWav(File(dir, "$id.wav"), audio) }
        val hints = VoiceMoveParser.spokenForms(candidates)
        val results = mutableListOf<EngineResult>()
        for ((engine, biasing) in listOf(engines[0] to null, engines[1] to hints)) {
            val started = SystemClock.elapsedRealtime()
            val (transcripts, error) = recognize(audio, biasing)
            val millis = SystemClock.elapsedRealtime() - started
            val outcome = VoiceMoveParser.resolve(transcripts, candidates)
            val correct = outcome is Outcome.Move && outcome.move == target
            results += EngineResult(engine, transcripts, error ?: describe(outcome), correct, millis)
        }
        val trial = Trial(id, System.currentTimeMillis(), fen, target, candidates, results)
        trials += trial
        last = trial
        withContext(Dispatchers.IO) { journal.appendText(encode(trial).toString() + "\n") }
        phase = Phase.idle
        if (results.any { it.correct }) nextPosition(keepingLast = true)
    }

    private fun baseIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
    }

    /** Fait passer l'enregistrement par la reconnaissance SUR L'APPAREIL ; rend les transcriptions, ou une erreur. */
    private suspend fun recognize(audio: ByteArray, biasing: List<String>?): Pair<List<String>, String?> {
        val (source, sink) = ParcelFileDescriptor.createPipe()
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        val result: Pair<List<String>, String?> = withTimeoutOrNull(15_000) {
            suspendCancellableCoroutine<Pair<List<String>, String?>> { continuation ->
                var done = false
                fun finish(value: Pair<List<String>, String?>) {
                    if (done) return
                    done = true
                    continuation.resume(value)
                }
                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onResults(results: Bundle) {
                        finish(results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty() to null)
                    }
                    override fun onError(error: Int) {
                        finish(emptyList<String>() to if (error == SpeechRecognizer.ERROR_NO_MATCH) "rien entendu" else "erreur $error")
                    }
                    override fun onReadyForSpeech(params: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onPartialResults(partialResults: Bundle?) {}
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                val intent = baseIntent().apply {
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, RATE)
                    biasing?.let { putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(it)) }
                }
                recognizer.startListening(intent)
                // Le son, puis une seconde de silence pour que la fin de phrase soit reconnue.
                thread(name = "voice-lab-feed") {
                    runCatching {
                        ParcelFileDescriptor.AutoCloseOutputStream(sink).use { out ->
                            out.write(audio)
                            out.write(ByteArray(RATE * 2))
                        }
                    }
                }
            }
        } ?: (emptyList<String>() to ("délai dépassé" as String?))
        recognizer.destroy()
        runCatching { source.close() }
        return result
    }

    fun discardLast() {
        val last = last ?: return
        if (trials.lastOrNull()?.id != last.id) return
        trials.removeAt(trials.lastIndex)
        this.last = null
        journal.writeText(trials.joinToString("") { encode(it).toString() + "\n" })
    }

    fun resetAll() {
        dir.listFiles()?.filter { it.extension == "wav" || it.name == "trials.jsonl" }?.forEach { it.delete() }
        trials.clear()
        last = null
    }

    fun score(engine: String): Pair<Int, Int> {
        val runs = trials.mapNotNull { trial -> trial.results.firstOrNull { it.engine == engine } }
        return runs.count { it.correct } to runs.size
    }

    fun release() {
        recording = false
        recorder?.release()
        scope.cancel()
    }

    // Journal — même schéma qu'iOS.

    private fun describe(outcome: Outcome) = when (outcome) {
        is Outcome.Move -> outcome.move.san
        is Outcome.Ambiguous -> "ambigu : " + outcome.moves.joinToString { it.san }
        is Outcome.Conflicting -> "hésite : " + outcome.moves.joinToString(" ou ") { it.san }
        Outcome.Illegal -> "coup impossible"
        Outcome.NotUnderstood -> "pas compris"
    }

    private fun candidateJson(c: Candidate) = JSONObject().put("uci", c.uci).put("san", c.san)
    private fun candidateOf(o: JSONObject) = Candidate(o.getString("uci"), o.getString("san"))

    private fun encode(trial: Trial) = JSONObject()
        .put("id", trial.id).put("date", trial.date).put("fen", trial.fen)
        .put("target", candidateJson(trial.target))
        .put("candidates", JSONArray(trial.candidates.map { candidateJson(it) }))
        .put("results", JSONArray(trial.results.map {
            JSONObject().put("engine", it.engine).put("transcripts", JSONArray(it.transcripts))
                .put("outcome", it.outcome).put("correct", it.correct).put("millis", it.millis)
        }))

    private fun decode(o: JSONObject): Trial {
        val candidates = o.getJSONArray("candidates").let { a -> (0 until a.length()).map { candidateOf(a.getJSONObject(it)) } }
        val results = o.getJSONArray("results").let { a ->
            (0 until a.length()).map { i ->
                val r = a.getJSONObject(i)
                val transcripts = r.getJSONArray("transcripts").let { t -> (0 until t.length()).map { t.getString(it) } }
                EngineResult(r.getString("engine"), transcripts, r.getString("outcome"), r.getBoolean("correct"), r.getLong("millis"))
            }
        }
        return Trial(o.getString("id"), o.getLong("date"), o.getString("fen"), candidateOf(o.getJSONObject("target")),
            candidates, results)
    }

    private fun writeWav(file: File, audio: ByteArray) {
        RandomAccessFile(file, "rw").use { out ->
            out.setLength(0)
            fun int(v: Int) = out.write(byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte()))
            fun short(v: Int) = out.write(byteArrayOf(v.toByte(), (v shr 8).toByte()))
            out.write("RIFF".toByteArray()); int(36 + audio.size); out.write("WAVEfmt ".toByteArray())
            int(16); short(1); short(1); int(RATE); int(RATE * 2); short(2); short(16)
            out.write("data".toByteArray()); int(audio.size); out.write(audio)
        }
    }
}

@Composable
private fun LabScreen(lab: VoiceLab) {
    var confirmReset by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Mesure de la dictée", color = Palette.textPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${lab.trials.size} essais", color = Palette.textPrimary, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f))
                TextButton(onClick = { confirmReset = true }, enabled = lab.trials.isNotEmpty()) {
                    Text("Remettre à zéro", color = Palette.danger)
                }
            }
            VoiceLab.engines.forEach { engine ->
                val (correct, total) = lab.score(engine)
                Row {
                    Text(engine, color = Palette.textSecondary, modifier = Modifier.weight(1f))
                    Text(if (total == 0) "—" else "$correct/$total · ${correct * 100 / total} %", color = Palette.textSecondary)
                }
            }
        }
        lab.target?.let { target ->
            Card {
                Text("Dites, à votre façon :", color = Palette.textSecondary, fontSize = 14.sp)
                Text(MoveNarration.describe(context, target.san), color = Palette.textPrimary, fontSize = 26.sp,
                    fontWeight = FontWeight.Bold)
                Text("${target.san} · ${lab.candidates.size} coups légaux", color = Palette.textTertiary, fontSize = 12.sp)
                Row {
                    TextButton(onClick = { lab.nextPosition() }) { Text("Autre coup", color = Palette.accent) }
                    Spacer(Modifier.weight(1f))
                    if (lab.last != null) {
                        TextButton(onClick = { lab.discardLast() }) { Text("Ne pas compter le dernier", color = Palette.danger) }
                    }
                }
            }
        }
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            val recording = lab.phase == VoiceLab.Phase.recording
            Box(
                Modifier
                    .size(if (recording) 120.dp else 110.dp)
                    .background(if (recording) Palette.danger else Palette.accent, CircleShape)
                    .pointerInput(Unit) {
                        detectTapGestures(onPress = {
                            lab.beginRecording()
                            tryAwaitRelease()
                            lab.endRecording()
                        })
                    },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.Mic, null, tint = Color.White, modifier = Modifier.size(44.dp)) }
            Text(
                when (lab.phase) {
                    VoiceLab.Phase.idle -> "Maintenir pour parler"
                    VoiceLab.Phase.recording -> "Je vous écoute…"
                    VoiceLab.Phase.analysing -> "Analyse…"
                },
                color = Palette.textSecondary, modifier = Modifier.padding(top = 8.dp),
            )
        }
        lab.last?.let { trial ->
            Card {
                Text("Dernier essai : ${MoveNarration.describe(context, trial.target.san)}", color = Palette.textSecondary,
                    fontWeight = FontWeight.SemiBold)
                trial.results.forEach { result ->
                    Row {
                        Text(if (result.correct) "✓ " else "✗ ", color = if (result.correct) Palette.accent else Palette.danger)
                        Text(result.engine, color = Palette.textPrimary, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f))
                        Text("${result.millis} ms", color = Palette.textTertiary, fontSize = 12.sp)
                    }
                    Text("« ${result.transcripts.firstOrNull() ?: "—"} » → ${result.outcome}", color = Palette.textPrimary,
                        fontSize = 13.sp)
                    if (result.transcripts.size > 1) {
                        Text("aussi : " + result.transcripts.drop(1).take(4).joinToString(" | "), color = Palette.textTertiary,
                            fontSize = 11.sp)
                    }
                }
            }
        }
        Text(lab.modelStatus, color = Palette.textTertiary, fontSize = 12.sp)
        if (lab.status.isNotEmpty()) Text(lab.status, color = Palette.warning, fontSize = 12.sp)
    }
    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("Effacer tous les essais ?") },
            confirmButton = {
                TextButton(onClick = { lab.resetAll(); confirmReset = false }) { Text("Effacer", color = Palette.danger) }
            },
            dismissButton = { TextButton(onClick = { confirmReset = false }) { Text("Annuler") } },
        )
    }
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(Palette.surfaceElevated, RoundedCornerShape(16.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) { content() }
}
