package com.chesslab.maia

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import java.nio.FloatBuffer

/** Ce que le réseau rend pour une position. */
data class MaiaPrediction(
    val moveLogits: FloatArray,
    val win: Double,
    val draw: Double,
    val loss: Double,
) {
    override fun equals(other: Any?): Boolean = this === other
    override fun hashCode(): Int = System.identityHashCode(this)
}

/**
 * Maia-3 sur Android, par ONNX Runtime. Pendant de `MaiaModel.swift`, qui
 * passe lui par Core ML.
 *
 * Le modèle est le MÊME réseau : converti depuis le checkpoint PyTorch par
 * `tools/maia3-spike/convert_maia3_onnx.py`, et vérifié coup pour coup contre
 * les fixtures de l'app iOS — 56 positions, mêmes coups de tête.
 *
 * Une seule instance : le fichier fait 43 Mo et le chargement coûte, alors que
 * l'inférence est sans état.
 *
 * ## La session se rend, et se rouvre toute seule
 *
 * Chargée, elle occupe environ 170 Mo — le modèle plus les tampons d'ONNX
 * Runtime. Sur un téléphone de 4 Go, c'est ce qui fait de ChessLab la première
 * chose qu'Android évince dès qu'on passe à une autre app : on revient, la
 * partie a disparu. Mesuré sur un Galaxy A16 : 582 Mo en jeu, et le système
 * reprend la main.
 *
 * D'où [release], appelée quand l'app passe en arrière-plan. La session se
 * rouvre au premier coup suivant, en une seconde ou deux — un prix qu'on paie
 * seulement quand le système a réclamé, et jamais pendant qu'on joue.
 */
class MaiaModel private constructor(
    private val context: Context,
    private val threads: Int,
    private var session: OrtSession?,
) {

    /** La session, rouverte si on l'a rendue. `null` si elle ne rouvre pas. */
    @Synchronized
    private fun session(): OrtSession? =
        session ?: open(context, threads)?.also { session = it }

    /**
     * Rend au système la mémoire de la session. Sans effet si elle est déjà
     * rendue ; l'objet, lui, reste valide — c'est tout l'intérêt, les
     * appelants gardent leur référence.
     */
    @Synchronized
    fun release() {
        runCatching { session?.close() }
        session = null
    }

    fun predict(tokens: FloatArray, selfElo: Double, oppoElo: Double): MaiaPrediction {
        val session = session() ?: error("session Maia indisponible")
        val env = OrtEnvironment.getEnvironment()
        val shape = longArrayOf(1, MaiaEncoder.SQUARE_COUNT.toLong(), MaiaEncoder.FEATURES_PER_SQUARE.toLong())

        OnnxTensor.createTensor(env, FloatBuffer.wrap(tokens), shape).use { t ->
            OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(clamp(selfElo))), longArrayOf(1)).use { s ->
                OnnxTensor.createTensor(env, FloatBuffer.wrap(floatArrayOf(clamp(oppoElo))), longArrayOf(1)).use { o ->
                    session.run(mapOf("tokens" to t, "self_elo" to s, "oppo_elo" to o)).use { out ->
                        @Suppress("UNCHECKED_CAST")
                        val moves = (out[0].value as Array<FloatArray>)[0]
                        @Suppress("UNCHECKED_CAST")
                        val value = (out[1].value as Array<FloatArray>)[0]

                        // le réseau rend [défaite, nulle, victoire] ; on adopte
                        // l'ordre de l'app iOS
                        val p = MaiaPolicy.softmax(value.map { it.toDouble() })
                        return MaiaPrediction(moves, win = p[2], draw = p[1], loss = p[0])
                    }
                }
            }
        }
    }

    private fun clamp(elo: Double): Float = elo.coerceIn(0.0, 5000.0).toFloat()

    companion object {
        private const val ASSET = "maia3_23m_fp16.onnx"
        private var instance: MaiaModel? = null

        private fun open(context: Context, threads: Int): OrtSession? = runCatching {
            val bytes = context.assets.open(ASSET).use { it.readBytes() }
            val options = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(threads)
                setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            }
            OrtEnvironment.getEnvironment().createSession(bytes, options)
        }.getOrNull()

        /**
         * `null` si le modèle est absent ou illisible — l'app retombe alors sur
         * Stockfish. La session est ouverte ICI et non à la demande : c'est ce
         * qui permet de dire tout de suite si les personnages sont disponibles.
         */
        @Synchronized
        fun shared(context: Context, threads: Int): MaiaModel? {
            instance?.let { return it }
            val app = context.applicationContext
            val session = open(app, threads) ?: return null
            return MaiaModel(app, threads, session).also { instance = it }
        }

        /** Rend la mémoire du modèle partagé, s'il y en a un. */
        @Synchronized
        fun releaseShared() { instance?.release() }
    }
}
