package com.chesslab.play

import chesskit.Board
import chesskit.Position
import com.chesslab.play.VoiceMoveParser.Outcome
import org.json.JSONObject
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

/**
 * Évalue un banc de voix synthétiques (21/11/2026) : pour chaque enregistrement, ce que le reconnaisseur a écrit
 * (`out.jsonl`, rendu par `VoiceSynthBatchActivity`) passe par le lecteur de coups ACTUEL et se compare au coup attendu
 * (`index.jsonl`). Ne fait rien sans `SYNTH_DIR` (la variable d'environnement posée par `tools/voix-synthese/mesurer.sh`).
 * Écrit `rapport.txt` : un tableau par langue et par voix, puis chaque échec avec ce qui a été entendu.
 */
class SynthEvalTest {
    @Test fun rapport() {
        val dir = System.getenv("SYNTH_DIR")?.let { File(it) }
        assumeTrue("SYNTH_DIR absent", dir != null && File(dir, "out.jsonl").exists())
        dir!!
        val index = File(dir, "index.jsonl").readLines().filter { it.isNotBlank() }.map { JSONObject(it) }.associateBy { it.getString("id") }
        val results = File(dir, "out.jsonl").readLines().filter { it.isNotBlank() }.map { JSONObject(it) }
        data class Row(val lang: String, val voice: String, val text: String, val ok: Boolean, val verdict: String, val heard: List<String>, val error: String?)
        val rows = results.map { r ->
            val meta = index.getValue(r.getString("id"))
            val lang = meta.getString("lang")
            val heard = r.getJSONArray("transcripts").let { a -> (0 until a.length()).map { a.getString(it) } }
            val expected = meta.getString("expected")
            val vocabulary = VoiceMoveParser.vocabulary(lang)
            val (ok, verdict) = if (expected == "undo") {
                val ok = heard.any { VoiceMoveParser.isUndo(it, vocabulary) }
                ok to if (ok) "annule" else "rien"
            } else {
                val legal = VoiceMoveParser.candidates(Board(Position.fromFen(meta.getString("fen"))!!))
                when (val outcome = VoiceMoveParser.resolve(heard, legal, vocabulary = vocabulary)) {
                    is Outcome.Move -> (outcome.move.uci == expected) to "joue ${outcome.move.uci}"
                    is Outcome.Conflicting -> false to "hésite"
                    is Outcome.Ambiguous -> false to "ambigu"
                    Outcome.Illegal -> false to "impossible"
                    Outcome.NotUnderstood -> false to "incompris"
                }
            }
            Row(lang, meta.getString("voice").substringBefore(" ("), meta.getString("text"), ok, verdict, heard,
                if (r.isNull("error")) null else r.getString("error"))
        }
        val report = StringBuilder()
        report.appendLine("RAPPORT — ${rows.size} enregistrements")
        for ((lang, group) in rows.groupBy { it.lang }) {
            report.appendLine("\n== $lang : ${group.count { it.ok }} / ${group.size}")
            for ((voice, g) in group.groupBy { it.voice }) report.appendLine("   $voice : ${g.count { it.ok }} / ${g.size}")
            val byText = group.groupBy { it.text }.filterValues { g -> g.any { !it.ok } }
            for ((text, g) in byText) {
                report.appendLine("   « $text » : ${g.count { it.ok }} / ${g.size}")
                for (f in g.filter { !it.ok }) {
                    report.appendLine("        ${f.voice} → ${f.verdict} ← ${f.heard.take(3)}${f.error?.let { " ($it)" } ?: ""}")
                }
            }
        }
        File(dir, "rapport.txt").writeText(report.toString())
    }
}
