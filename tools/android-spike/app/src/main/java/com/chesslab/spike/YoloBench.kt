package com.chesslab.spike

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.BitmapFactory
import org.json.JSONObject
import java.nio.FloatBuffer

/**
 * Volet Scanner du spike : le détecteur de pièces YOLO, converti en ONNX,
 * retrouve-t-il sur Android les MÊMES pièces que le modèle Core ML embarqué
 * dans l'app iOS ?
 *
 * Ce banc mesure le MODÈLE, pas le pipeline. La détection du plateau
 * (`VNDetectRectanglesRequest`) et la rectification ne sont pas portées :
 * les images fournies sont déjà au format d'entrée (640 × 640), découpées
 * côté Python. Les porter est du travail ordinaire (OpenCV), pas un risque
 * de conversion.
 *
 * La post-traitement (NMS) est en revanche bien réimplémenté ici : l'export
 * Core ML d'ultralytics l'embarque dans le modèle, l'export ONNX non. C'est
 * donc du code neuf, et c'est exactement ce qu'on veut vérifier.
 */
object YoloBench {

    private const val SIZE = 640

    data class Detection(val cls: Int, val conf: Float, val cx: Float, val cy: Float, val w: Float, val h: Float)

    data class Result(
        val images: Int,
        val expected: Int,
        val matched: Int,
        val worstIou: Double,
        val medianMs: Double,
        val threads: Int,
    )

    fun run(context: Context, modelAsset: String, fixtureAsset: String): Result {
        val env = OrtEnvironment.getEnvironment()
        val threads = (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, 4)
        val options = OrtSession.SessionOptions().apply {
            setIntraOpNumThreads(threads)
            setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        }
        val session = env.createSession(context.assets.open(modelAsset).use { it.readBytes() }, options)

        val fixture = JSONObject(context.assets.open(fixtureAsset).use { it.readBytes() }.decodeToString())
        val confThreshold = fixture.getDouble("conf").toFloat()
        val iouThreshold = fixture.getDouble("iou").toFloat()
        val cases = fixture.getJSONArray("cases")

        var expected = 0
        var matched = 0
        var worstIou = 1.0
        val timings = ArrayList<Double>()

        session.use {
            val inputName = session.inputNames.first()
            for (c in 0 until cases.length()) {
                val case = cases.getJSONObject(c)
                val pixels = decodeImage(context, case.getString("image"))

                val started = System.nanoTime()
                val raw = infer(env, session, inputName, pixels)
                val found = postProcess(raw, confThreshold, iouThreshold)
                timings += (System.nanoTime() - started) / 1_000_000.0

                val expect = case.getJSONArray("expect")
                expected += expect.length()
                for (k in 0 until expect.length()) {
                    val e = expect.getJSONObject(k)
                    val cls = e.getInt("cls")
                    val box = e.getJSONArray("xywh")
                    val target = Detection(
                        cls, 0f,
                        box.getDouble(0).toFloat(), box.getDouble(1).toFloat(),
                        box.getDouble(2).toFloat(), box.getDouble(3).toFloat(),
                    )
                    val best = found.filter { it.cls == cls }.maxOfOrNull { iou(it, target) } ?: 0.0
                    if (best > 0.9) { matched++; worstIou = minOf(worstIou, best) }
                }
            }
        }

        timings.sort()
        return Result(cases.length(), expected, matched, worstIou, timings[timings.size / 2], threads)
    }

    /** L'image est déjà au format d'entrée : décodage direct, sans redimensionnement. */
    private fun decodeImage(context: Context, name: String): FloatArray {
        val bitmap = context.assets.open(name).use { BitmapFactory.decodeStream(it) }
            ?: error("image illisible : $name")
        require(bitmap.width == SIZE && bitmap.height == SIZE) {
            "attendu ${SIZE}×$SIZE, reçu ${bitmap.width}×${bitmap.height}"
        }
        val argb = IntArray(SIZE * SIZE)
        bitmap.getPixels(argb, 0, SIZE, 0, 0, SIZE, SIZE)
        val out = FloatArray(3 * SIZE * SIZE)
        val plane = SIZE * SIZE
        for (i in 0 until plane) {
            val p = argb[i]
            out[i] = ((p shr 16) and 0xFF) / 255f              // R
            out[plane + i] = ((p shr 8) and 0xFF) / 255f       // V
            out[2 * plane + i] = (p and 0xFF) / 255f           // B
        }
        return out
    }

    private fun infer(
        env: OrtEnvironment,
        session: OrtSession,
        inputName: String,
        pixels: FloatArray,
    ): Array<FloatArray> {
        OnnxTensor.createTensor(env, FloatBuffer.wrap(pixels), longArrayOf(1, 3, SIZE.toLong(), SIZE.toLong()))
            .use { input ->
                session.run(mapOf(inputName to input)).use { out ->
                    @Suppress("UNCHECKED_CAST")
                    return (out[0].value as Array<Array<FloatArray>>)[0]   // (4 + classes) × ancres
                }
            }
    }

    /**
     * Boîtes brutes → détections. YOLOv8 sort `(4 + classes) × ancres` :
     * les quatre premières lignes sont cx, cy, w, h en pixels d'entrée, les
     * suivantes le score de chaque classe. On garde la meilleure classe par
     * ancre (comme ultralytics en `multi_label=False`), puis NMS PAR CLASSE.
     */
    private fun postProcess(raw: Array<FloatArray>, confThreshold: Float, iouThreshold: Float): List<Detection> {
        val classes = raw.size - 4
        val anchors = raw[0].size
        val kept = ArrayList<Detection>()
        for (a in 0 until anchors) {
            var bestCls = 0
            var bestScore = raw[4][a]
            for (k in 1 until classes) {
                if (raw[4 + k][a] > bestScore) { bestScore = raw[4 + k][a]; bestCls = k }
            }
            if (bestScore < confThreshold) continue
            kept += Detection(
                bestCls, bestScore,
                raw[0][a] / SIZE, raw[1][a] / SIZE, raw[2][a] / SIZE, raw[3][a] / SIZE,
            )
        }
        kept.sortByDescending { it.conf }

        val out = ArrayList<Detection>()
        val suppressed = BooleanArray(kept.size)
        for (i in kept.indices) {
            if (suppressed[i]) continue
            out += kept[i]
            for (j in i + 1 until kept.size) {
                if (!suppressed[j] && kept[j].cls == kept[i].cls && iou(kept[i], kept[j]) > iouThreshold) {
                    suppressed[j] = true
                }
            }
        }
        return out
    }

    private fun iou(a: Detection, b: Detection): Double {
        val ax1 = a.cx - a.w / 2; val ay1 = a.cy - a.h / 2
        val ax2 = a.cx + a.w / 2; val ay2 = a.cy + a.h / 2
        val bx1 = b.cx - b.w / 2; val by1 = b.cy - b.h / 2
        val bx2 = b.cx + b.w / 2; val by2 = b.cy + b.h / 2
        val ix = maxOf(0f, minOf(ax2, bx2) - maxOf(ax1, bx1))
        val iy = maxOf(0f, minOf(ay2, by2) - maxOf(ay1, by1))
        val inter = (ix * iy).toDouble()
        val union = (a.w * a.h + b.w * b.h).toDouble() - inter
        return if (union > 0) inter / union else 0.0
    }
}
