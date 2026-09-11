package com.chesslab.vision

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import chesskit.Piece
import java.nio.FloatBuffer

/**
 * Le détecteur de pièces : YOLO11n, converti en ONNX depuis le modèle Core ML
 * de l'app iOS (`tools/yolo-spike/`).
 *
 * **La NMS est ici et non dans le modèle.** L'export Core ML d'ultralytics
 * l'embarque dans le graphe ; l'export ONNX sort les boîtes brutes. C'est donc
 * du code neuf — vérifié contre le modèle embarqué iOS à 75 détections sur 76.
 */
class PieceDetector private constructor(private val session: OrtSession) {

    companion object {
        private const val ASSET = "chess_pieces_yolo.onnx"
        const val SIZE = 640
        private const val CONF = 0.25f
        private const val IOU = 0.7f

        /** L'ordre des classes du dataset — le contrat entre le modèle et l'app. */
        private val labels = listOf(
            Piece.Color.white to Piece.Kind.pawn,
            Piece.Color.white to Piece.Kind.knight,
            Piece.Color.white to Piece.Kind.bishop,
            Piece.Color.white to Piece.Kind.rook,
            Piece.Color.white to Piece.Kind.queen,
            Piece.Color.white to Piece.Kind.king,
            Piece.Color.black to Piece.Kind.pawn,
            Piece.Color.black to Piece.Kind.knight,
            Piece.Color.black to Piece.Kind.bishop,
            Piece.Color.black to Piece.Kind.rook,
            Piece.Color.black to Piece.Kind.queen,
            Piece.Color.black to Piece.Kind.king,
        )

        @Volatile private var instance: PieceDetector? = null

        /** `null` si le modèle est absent — le scanner le dit plutôt que de mentir. */
        @Synchronized
        fun shared(context: Context, threads: Int = 2): PieceDetector? {
            instance?.let { return it }
            return runCatching {
                val bytes = context.applicationContext.assets.open(ASSET).use { it.readBytes() }
                val options = OrtSession.SessionOptions().apply {
                    setIntraOpNumThreads(threads)
                    setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
                }
                PieceDetector(OrtEnvironment.getEnvironment().createSession(bytes, options))
            }.getOrNull()?.also { instance = it }
        }
    }

    /**
     * Redresse le quadrilatère [corners] de [source] en carré de 640, puis y
     * détecte les pièces.
     *
     * L'échantillonnage se fait en sens INVERSE — pour chaque pixel de sortie,
     * on va chercher d'où il vient — ce qui évite les trous qu'un parcours
     * direct laisserait.
     */
    fun detect(source: Bitmap, corners: List<Homography.Point>): List<Detection> {
        val h = Homography.fromSquare(corners, SIZE.toDouble())
        val width = source.width
        val height = source.height
        val pixels = IntArray(width * height)
        source.getPixels(pixels, 0, width, 0, 0, width, height)

        val plane = SIZE * SIZE
        val tensor = FloatArray(3 * plane)
        for (y in 0 until SIZE) {
            for (x in 0 until SIZE) {
                val p = Homography.map(h, x + 0.5, y + 0.5)
                val sx = p.x.toInt().coerceIn(0, width - 1)
                val sy = p.y.toInt().coerceIn(0, height - 1)
                val argb = pixels[sy * width + sx]
                val index = y * SIZE + x
                tensor[index] = ((argb shr 16) and 0xFF) / 255f
                tensor[plane + index] = ((argb shr 8) and 0xFF) / 255f
                tensor[2 * plane + index] = (argb and 0xFF) / 255f
            }
        }

        val env = OrtEnvironment.getEnvironment()
        val raw = OnnxTensor.createTensor(
            env, FloatBuffer.wrap(tensor), longArrayOf(1, 3, SIZE.toLong(), SIZE.toLong()),
        ).use { input ->
            session.run(mapOf(session.inputNames.first() to input)).use { out ->
                @Suppress("UNCHECKED_CAST")
                (out[0].value as Array<Array<FloatArray>>)[0]
            }
        }
        return postProcess(raw)
    }

    /**
     * Boîtes brutes → détections. YOLO sort `(4 + classes) × ancres` : les
     * quatre premières lignes sont cx, cy, w, h en pixels d'entrée, les
     * suivantes le score par classe. On garde la meilleure classe par ancre,
     * puis NMS PAR CLASSE.
     */
    private fun postProcess(raw: Array<FloatArray>): List<Detection> {
        val classes = raw.size - 4
        val anchors = raw[0].size
        val kept = ArrayList<Detection>()

        for (a in 0 until anchors) {
            var bestClass = 0
            var bestScore = raw[4][a]
            for (k in 1 until classes) {
                if (raw[4 + k][a] > bestScore) { bestScore = raw[4 + k][a]; bestClass = k }
            }
            if (bestScore < CONF) continue
            val (color, kind) = labels[bestClass]
            val cx = raw[0][a].toDouble() / SIZE
            val cy = raw[1][a].toDouble() / SIZE
            val w = raw[2][a].toDouble() / SIZE
            val hh = raw[3][a].toDouble() / SIZE
            kept += Detection(
                color, kind, bestScore.toDouble(),
                left = cx - w / 2, top = cy - hh / 2, right = cx + w / 2, bottom = cy + hh / 2,
            )
        }
        kept.sortByDescending { it.confidence }

        val out = ArrayList<Detection>()
        val suppressed = BooleanArray(kept.size)
        for (i in kept.indices) {
            if (suppressed[i]) continue
            out += kept[i]
            for (j in i + 1 until kept.size) {
                if (suppressed[j]) continue
                if (kept[j].color == kept[i].color && kept[j].kind == kept[i].kind &&
                    iou(kept[i], kept[j]) > IOU
                ) suppressed[j] = true
            }
        }
        return out
    }

    private fun iou(a: Detection, b: Detection): Double {
        val ix = maxOf(0.0, minOf(a.right, b.right) - maxOf(a.left, b.left))
        val iy = maxOf(0.0, minOf(a.bottom, b.bottom) - maxOf(a.top, b.top))
        val inter = ix * iy
        val union = (a.right - a.left) * (a.bottom - a.top) +
            (b.right - b.left) * (b.bottom - b.top) - inter
        return if (union > 0) inter / union else 0.0
    }
}
