package com.chesslab.voicelab

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.chesslab.play.UtteranceDetector
import kotlin.math.max

/**
 * DÉBOGAGE SEULEMENT (21/11/2026) : « le micro du Galaxy est-il bas ? ». Enregistre 4 s avec CHAQUE source du micro,
 * pendant que la personne répète une phrase à une distance fixe, et affiche pour chacune la crête, le niveau de la voix
 * et le bruit de fond. Rien n'est gardé : seuls des NIVEAUX (des chiffres) sortent, jamais le son.
 */
class MicLevelActivity : Activity() {
    private lateinit var report: TextView
    private lateinit var start: Button
    private val lines = mutableListOf<String>()

    private val sources = listOf(
        "VOICE_RECOGNITION (celle de l'app)" to MediaRecorder.AudioSource.VOICE_RECOGNITION,
        "MIC (micro standard)" to MediaRecorder.AudioSource.MIC,
        "VOICE_COMMUNICATION (appel)" to MediaRecorder.AudioSource.VOICE_COMMUNICATION,
        "UNPROCESSED (brut)" to MediaRecorder.AudioSource.UNPROCESSED,
        "CAMCORDER (caméra)" to MediaRecorder.AudioSource.CAMCORDER,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 80, 40, 40)
        }
        column.addView(TextView(this).apply {
            text = "Niveau du micro\n\nTenez le téléphone à ~20 cm. Au signal, répétez « pion e quatre » à voix normale, " +
                "pendant 4 s, pour CHAQUE source (5 essais)."
            textSize = 16f
        })
        start = Button(this).apply {
            text = "Commencer"
            setOnClickListener { begin() }
        }
        column.addView(start)
        report = TextView(this).apply { typeface = Typeface.MONOSPACE; textSize = 13f; gravity = Gravity.START }
        column.addView(ScrollView(this).apply { addView(report) })
        setContentView(column)
    }

    private fun begin() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
            return
        }
        start.isEnabled = false
        lines.clear()
        Thread {
            for ((name, source) in sources) {
                show("→ $name : préparez-vous (2 s)…")
                Thread.sleep(2_000)
                show("→ $name : PARLEZ maintenant (4 s)")
                val result = measure(source)
                lines += "$name\n    $result"
                Log.d(TAG, "$name : $result")
                show("")
            }
            runOnUiThread { start.isEnabled = true }
            show("Terminé.")
        }.start()
    }

    private fun show(current: String) = runOnUiThread {
        report.text = (lines + current).joinToString("\n")
    }

    /** Crête, voix (médiane des dixièmes de seconde les plus forts) et bruit de fond (le plus bas), en dB pleine échelle. */
    private fun measure(source: Int): String {
        val rate = 16_000
        val minimum = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val record = try {
            AudioRecord(source, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, max(minimum, rate))
        } catch (e: Exception) {
            return "indisponible (${e.javaClass.simpleName})"
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); return "indisponible" }
        val levels = mutableListOf<Float>()
        var peak = -120f
        try {
            record.startRecording()
            val buffer = ShortArray(rate / 10)
            val end = System.currentTimeMillis() + 4_000
            while (System.currentTimeMillis() < end) {
                val count = record.read(buffer, 0, buffer.size)
                if (count <= 0) continue
                val level = UtteranceDetector.level(buffer, count)
                levels += level
                var top = 0
                for (i in 0 until count) top = max(top, kotlin.math.abs(buffer[i].toInt()))
                peak = max(peak, (20 * kotlin.math.log10(max(top, 1) / 32768.0)).toFloat())
            }
            record.stop()
        } catch (e: Exception) {
            return "erreur (${e.javaClass.simpleName})"
        } finally {
            record.release()
        }
        if (levels.isEmpty()) return "aucun son lu"
        val sorted = levels.sorted()
        val noise = sorted[sorted.size / 10]
        val voice = sorted[(sorted.size * 9 / 10).coerceAtMost(sorted.size - 1)]
        return "crête %.0f dB · voix %.0f dB · fond %.0f dB".format(peak, voice, noise)
    }

    private companion object { const val TAG = "ChessLabNiveau" }
}
