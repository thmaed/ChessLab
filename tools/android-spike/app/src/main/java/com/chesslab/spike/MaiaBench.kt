package com.chesslab.spike

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import org.json.JSONObject
import java.math.BigInteger
import java.nio.FloatBuffer

/**
 * Volet Maia du spike : le réseau de politique converti en ONNX tourne-t-il
 * sur Android, rend-il les MÊMES coups que côté iOS, et à quelle vitesse ?
 *
 * L'encodeur n'est pas porté ici — inutile. Les entrées viennent des fixtures
 * qui servent déjà aux tests iOS (`ChessLabTests/Fixtures_maia3.json`,
 * prémâchées en `android_fixture.json`) : 64 cases × 96 bits en hexadécimal,
 * exactement ce que `MaiaEncoder.swift` produit. On compare donc deux
 * plateformes à une seule et même référence.
 */
object MaiaBench {

    private const val SQUARES = 64
    private const val FEATURES = 97      // 8 positions d'historique × 12 plans + 1

    data class Result(
        val cases: Int,
        val agree: Int,
        val worstProbDelta: Double,
        val medianMs: Double,
        val p90Ms: Double,
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
        val cases = fixture.getJSONArray("cases")

        var agree = 0
        var worst = 0.0
        val timings = ArrayList<Double>(cases.length())

        session.use {
            for (c in 0 until cases.length()) {
                val case = cases.getJSONObject(c)
                val tokens = decodeTokens(case.getJSONArray("tokens"))
                val selfElo = case.getDouble("selfElo").toFloat()
                val oppoElo = case.getDouble("oppoElo").toFloat()

                val started = System.nanoTime()
                val logits = infer(env, session, tokens, selfElo, oppoElo)
                timings += (System.nanoTime() - started) / 1_000_000.0

                // Softmax restreinte aux coups légaux, comme dans MaiaPolicy.
                val legal = case.getJSONArray("legal")
                var best = ""
                var bestLogit = Float.NEGATIVE_INFINITY
                var sum = 0.0
                val exps = DoubleArray(legal.length())
                var max = Float.NEGATIVE_INFINITY
                for (k in 0 until legal.length()) {
                    val v = logits[legal.getJSONObject(k).getInt("i")]
                    if (v > max) max = v
                }
                for (k in 0 until legal.length()) {
                    val entry = legal.getJSONObject(k)
                    val v = logits[entry.getInt("i")]
                    exps[k] = Math.exp((v - max).toDouble())
                    sum += exps[k]
                    if (v > bestLogit) { bestLogit = v; best = entry.getString("uci") }
                }

                if (best == case.getString("expect")) agree++
                var bestP = 0.0
                for (k in 0 until legal.length()) {
                    if (legal.getJSONObject(k).getString("uci") == case.getString("expect")) {
                        bestP = exps[k] / sum
                    }
                }
                worst = maxOf(worst, kotlin.math.abs(bestP - case.getDouble("expectP")))
            }
        }

        timings.sort()
        return Result(
            cases = cases.length(),
            agree = agree,
            worstProbDelta = worst,
            medianMs = timings[timings.size / 2],
            p90Ms = timings[(timings.size * 9 / 10).coerceAtMost(timings.size - 1)],
            threads = threads,
        )
    }

    private fun infer(
        env: OrtEnvironment,
        session: OrtSession,
        tokens: FloatArray,
        selfElo: Float,
        oppoElo: Float,
    ): FloatArray {
        val t = OnnxTensor.createTensor(env, FloatBuffer.wrap(tokens), longArrayOf(1, SQUARES.toLong(), FEATURES.toLong()))
        val s = OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(selfElo)), longArrayOf(1))
        val o = OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(oppoElo)), longArrayOf(1))
        t.use { _ -> s.use { _ -> o.use { _ ->
            session.run(mapOf("tokens" to t, "self_elo" to s, "oppo_elo" to o)).use { out ->
                @Suppress("UNCHECKED_CAST")
                return (out[0].value as Array<FloatArray>)[0]
            }
        } } }
    }

    /** 24 caractères hexadécimaux par case = 96 bits, le plus significatif d'abord. */
    private fun decodeTokens(rows: org.json.JSONArray): FloatArray {
        val out = FloatArray(SQUARES * FEATURES)
        for (sq in 0 until SQUARES) {
            val bits = BigInteger(rows.getString(sq), 16)
            for (j in 0 until 96) {
                if (bits.testBit(95 - j)) out[sq * FEATURES + j] = 1f
            }
        }
        return out
    }
}
