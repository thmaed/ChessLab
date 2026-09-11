package com.chesslab.spike

import android.content.Context
import android.util.Log
import java.io.File

/** Une étape du spike, telle qu'affichée à l'écran. */
data class Step(val name: String, val ok: Boolean?, val detail: String = "")

/**
 * Le scénario de dérisquage. Deux volets, indépendants :
 *
 *  A. **Stockfish** — les sources C++ de l'app iOS, recompilées au NDK,
 *     démarrent-elles et jouent-elles juste ?
 *  B. **Maia3** — le réseau de politique converti en ONNX rend-il les mêmes
 *     coups que côté iOS, et à quelle vitesse ?
 *  C. **Scanner** — le détecteur de pièces YOLO, converti en ONNX et sa NMS
 *     réécrite, retrouve-t-il les mêmes pièces que le Core ML embarqué ?
 *
 * Les trois tournent même si l'une échoue : ce sont trois questions séparées.
 */
object SpikeScenario {

    /** Mat en un coup (mat du berger) : la réponse attendue est Qxf7#. */
    private const val MATE_FEN = "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4"
    private const val MATE_BEST = "f3f7"

    private const val MAIA_MODEL = "maia3_23m_fp16.onnx"
    private const val MAIA_FIXTURE = "android_fixture.json"

    private const val YOLO_MODEL = "chess_pieces_yolo.onnx"
    private const val YOLO_FIXTURE = "android_yolo_fixture.json"

    fun run(context: Context, emit: (Step) -> Unit, log: (String) -> Unit) {
        val step: (String, Boolean?, String) -> Unit = { name, ok, detail ->
            val mark = when (ok) { true -> "OK "; false -> "ECHEC"; null -> "..." }
            Log.i("chesslab", "[$mark] $name — $detail")
            emit(Step(name, ok, detail))
        }
        runEngine(context, step, log)
        runMaia(context, step)
        runYolo(context, step)
    }

    // ------------------------------------------------------------ A. Stockfish

    private fun runEngine(context: Context, step: (String, Boolean?, String) -> Unit, log: (String) -> Unit) {
        // Sur iOS les réseaux NNUE sont lus directement dans le bundle ; sur
        // Android les assets ne sont pas de vrais fichiers, il faut les
        // extraire une fois vers le stockage de l'app.
        val engineDir = File(context.filesDir, "engine").apply { mkdirs() }
        val t0 = System.currentTimeMillis()
        var bytes = 0L
        try {
            for (name in context.assets.list("")!!.filter { it.endsWith(".nnue") }) {
                val target = File(engineDir, name)
                if (!target.exists() || target.length() == 0L) {
                    context.assets.open(name).use { input ->
                        target.outputStream().use { output -> input.copyTo(output, 1 shl 20) }
                    }
                }
                bytes += target.length()
            }
        } catch (e: Exception) {
            step("Extraction des réseaux NNUE", false, e.message ?: "échec")
            return
        }
        step(
            "Extraction des réseaux NNUE", bytes > 0,
            "%.1f Mo en %d ms".format(bytes / 1_048_576.0, System.currentTimeMillis() - t0)
        )

        val session = EngineSession(File(engineDir, "stockfish").absolutePath, log)
        try {
            val t1 = System.currentTimeMillis()
            if (!session.start()) {
                step("Démarrage du moteur", false, "un moteur tourne déjà")
                return
            }
            session.send("uci")
            var identity = ""
            val uciok = session.awaitLine(10_000, onLine = { line ->
                if (line.startsWith("id name")) identity = line.removePrefix("id name ").trim()
                log("< $line")
            }) { it.trim() == "uciok" }
            step(
                "Poignée de main UCI", uciok != null,
                if (uciok != null) "$identity — ${System.currentTimeMillis() - t1} ms"
                else "uciok jamais reçu (10 s)"
            )
            if (uciok == null) return

            val threads = (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, 4)
            session.send("setoption name Threads value $threads")
            session.send("setoption name Hash value 64")
            val t2 = System.currentTimeMillis()
            session.send("isready")
            val ready = session.awaitLine(30_000, onLine = { log("< $it") }) { it.trim() == "readyok" }
            step(
                "Chargement des réseaux NNUE", ready != null,
                if (ready != null) "$threads thread(s) — ${System.currentTimeMillis() - t2} ms"
                else "readyok jamais reçu (30 s)"
            )
            if (ready == null) return

            session.send("position fen $MATE_FEN")
            session.send("go depth 12")
            val mate = session.awaitLine(30_000, onLine = { log("< $it") }) { it.startsWith("bestmove") }
            val played = mate?.split(" ")?.getOrNull(1)
            step("Mat en un trouvé", played == MATE_BEST, "attendu $MATE_BEST, obtenu ${played ?: "rien"}")

            session.send("position startpos")
            val t3 = System.currentTimeMillis()
            var lastInfo = ""
            session.send("go depth 20")
            val done = session.awaitLine(120_000, onLine = { line ->
                if (line.startsWith("info") && line.contains(" nps ")) lastInfo = line
                if (!line.startsWith("info")) log("< $line")
            }) { it.startsWith("bestmove") }
            val elapsed = System.currentTimeMillis() - t3
            val nps = lastInfo.substringAfter(" nps ", "").substringBefore(" ").toLongOrNull()
            step(
                "Recherche profondeur 20", done != null,
                if (done != null) {
                    "%d ms — %s nœuds/s".format(elapsed, nps?.let { "%.1f M".format(it / 1_000_000.0) } ?: "?")
                } else "pas de bestmove (120 s)"
            )
        } finally {
            session.stop()
            step("Arrêt propre du moteur", !Stockfish.nativeIsRunning(), "")
        }
    }

    // ----------------------------------------------------------------- B. Maia

    private fun runMaia(context: Context, step: (String, Boolean?, String) -> Unit) {
        val sizeMb = try {
            context.assets.openFd(MAIA_MODEL).use { it.length / 1_048_576.0 }
        } catch (_: Exception) {
            // Les .onnx sont compressés dans l'APK : pas de descripteur direct.
            context.assets.open(MAIA_MODEL).use { it.readBytes().size / 1_048_576.0 }
        }
        val t0 = System.currentTimeMillis()
        val result = try {
            MaiaBench.run(context, MAIA_MODEL, MAIA_FIXTURE)
        } catch (e: Throwable) {
            step("Maia3 en ONNX Runtime", false, e.message?.take(120) ?: e.javaClass.simpleName)
            return
        }
        step(
            "Maia3 chargé et exécuté", true,
            "%.0f Mo — %d cas en %d ms".format(sizeMb, result.cases, System.currentTimeMillis() - t0)
        )
        step(
            "Mêmes coups que les fixtures iOS", result.agree == result.cases,
            "${result.agree}/${result.cases} top-1, Δprob max %.3f".format(result.worstProbDelta)
        )
        step(
            "Latence par coup", result.medianMs > 0,
            "médiane %.1f ms, p90 %.1f ms — %d thread(s)".format(result.medianMs, result.p90Ms, result.threads)
        )
    }

    // -------------------------------------------------------------- C. Scanner

    private fun runYolo(context: Context, step: (String, Boolean?, String) -> Unit) {
        val t0 = System.currentTimeMillis()
        val result = try {
            YoloBench.run(context, YOLO_MODEL, YOLO_FIXTURE)
        } catch (e: Throwable) {
            step("Détecteur YOLO en ONNX Runtime", false, e.message?.take(120) ?: e.javaClass.simpleName)
            return
        }
        step(
            "Détecteur YOLO chargé et exécuté", true,
            "${result.images} image(s) en ${System.currentTimeMillis() - t0} ms"
        )
        // Le bon critère n'est PAS l'égalité stricte. Le modèle embarqué côté
        // iOS est en fp16 et fait sa NMS dans le graphe Core ML ; celui-ci est
        // en fp32 avec une NMS réécrite. Une boîte limite peut basculer d'un
        // côté ou de l'autre du seuil sans que le portage soit en cause — la
        // même comparaison faite sur le Mac, en Python, donne exactement le
        // même écart. On exige donc 95 %, et on affiche le compte exact.
        val rate = result.matched.toDouble() / result.expected
        step(
            "Mêmes pièces que le Core ML embarqué", rate >= 0.95,
            "${result.matched}/${result.expected} détections (%.0f %%), IoU min %.3f"
                .format(rate * 100, result.worstIou)
        )
        step(
            "Latence par image", result.medianMs > 0,
            "médiane %.1f ms — %d thread(s)".format(result.medianMs, result.threads)
        )
    }
}
