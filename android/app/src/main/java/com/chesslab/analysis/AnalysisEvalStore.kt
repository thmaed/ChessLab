package com.chesslab.analysis

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

/**
 * Persistance LOCALE des analyses de parties : ce que le moteur a calculé une
 * fois ne se recalcule plus. Pendant d'`AnalysisEvalStore.swift`.
 *
 * ## Ce qui est conservé, et pourquoi ça suffit
 *
 * Pour chaque position de la ligne principale, l'évaluation complète —
 * centipions, mat, meilleur coup, écart au 2e choix, réfutation, verdict
 * d'une position finie. Les verdicts des coups, la courbe et la précision en
 * DÉRIVENT par une fonction pure (`classify`) : on ne range pas ce qu'on sait
 * recalculer en une milliseconde. Rechargée, la partie s'affiche classifiée à
 * l'identique, sans une seule requête moteur.
 *
 * ## La clé : la partie, pas son texte
 *
 * SHA-256 de la FEN de départ et de la séquence LAN de la ligne principale.
 * Deux PGN cosmétiquement différents (autres en-têtes, autres commentaires,
 * CRLF…) de la MÊME partie partagent donc leur analyse.
 *
 * ## Invalidation
 *
 * Le fichier embarque un profil (moteur + budget). Changer de Stockfish ou de
 * budget invalide TOUT — mieux vaut réanalyser que mélanger deux vérités.
 */
class AnalysisEvalStore(private val directory: File) {

    companion object {
        const val currentSchema = 1

        /** À CHANGER à chaque changement de moteur ou de budget de revue. */
        val engineProfile =
            "SF17.1/${AnalysisViewModel.REVIEW_NODES}n+${AnalysisViewModel.REVIEW_CAP_MS}ms/MPV2"

        /** Nombre de parties conservées (LRU par date de modification). Un cache n'est pas une base. */
        const val maxSnapshots = 300

        /**
         * Clé stable d'une partie : position de départ + ligne principale (LAN).
         * `null` sans coup — une position seule n'a rien à mettre en cache.
         * [variantId] : quatre variantes partagent la position de départ
         * standard ; sans lui, deux « 1.e4 e5 » de variantes différentes
         * partageraient à tort leur classification.
         */
        fun key(startFen: String, lans: List<String>, variantId: String? = null): String? {
            if (lans.isEmpty()) return null
            var material = startFen + "|" + lans.joinToString(" ")
            if (variantId != null) material = "$variantId|$material"
            val digest = MessageDigest.getInstance("SHA-256").digest(material.toByteArray(Charsets.UTF_8))
            return digest.joinToString("") { "%02x".format(it) }
        }
    }

    fun file(key: String): File = File(directory, "$key.json")

    /** Les évaluations par demi-coup (0 = position de départ), ou `null` si rien d'utilisable. */
    fun load(key: String, profile: String = engineProfile): Map<Int, PositionEval>? {
        val file = file(key)
        val text = runCatching { file.readText() }.getOrNull() ?: return null
        val root = runCatching { JSONObject(text) }.getOrNull() ?: return null
        if (root.optInt("schema", -1) != currentSchema) return null
        if (root.optString("profile") != profile) return null
        val evals = root.optJSONObject("evals") ?: return null
        val result = HashMap<Int, PositionEval>()
        for (ply in evals.keys()) {
            val node = evals.optJSONObject(ply) ?: continue
            val index = ply.toIntOrNull() ?: continue
            result[index] = PositionEval(
                cp = if (node.isNull("cp")) null else node.getInt("cp"),
                mate = if (node.isNull("mate")) null else node.getInt("mate"),
                bestLan = if (node.isNull("bestLan")) null else node.getString("bestLan"),
                gapToSecondBest = if (node.isNull("gapToSecondBest")) null else node.getDouble("gapToSecondBest"),
                secondBestLan = if (node.isNull("secondBestLan")) null else node.getString("secondBestLan"),
                pv = node.optJSONArray("pv")?.let { array -> List(array.length()) { array.getString(it) } } ?: emptyList(),
                terminalWinWhite = if (node.isNull("terminalWinWhite")) null else node.getDouble("terminalWinWhite"),
            )
        }
        // LRU : consulter un instantané le rajeunit.
        file.setLastModified(System.currentTimeMillis())
        return result
    }

    /** Écrit les évaluations — rien si elles sont vides — et garde le cache à sa taille. */
    fun save(key: String, evals: Map<Int, PositionEval>) {
        if (evals.isEmpty()) return
        directory.mkdirs()
        val root = JSONObject()
        root.put("schema", currentSchema)
        root.put("profile", engineProfile)
        val node = JSONObject()
        for ((ply, eval) in evals) {
            node.put(ply.toString(), JSONObject().apply {
                put("cp", eval.cp ?: JSONObject.NULL)
                put("mate", eval.mate ?: JSONObject.NULL)
                put("bestLan", eval.bestLan ?: JSONObject.NULL)
                put("gapToSecondBest", eval.gapToSecondBest ?: JSONObject.NULL)
                put("secondBestLan", eval.secondBestLan ?: JSONObject.NULL)
                put("pv", JSONArray(eval.pv))
                put("terminalWinWhite", eval.terminalWinWhite ?: JSONObject.NULL)
            })
        }
        root.put("evals", node)
        // Écriture ATOMIQUE : un fichier à moitié écrit se lirait comme un
        // cache vide, pas comme un cache faux — mais autant ne pas y compter.
        val tmp = File(directory, "$key.tmp")
        tmp.writeText(root.toString())
        if (!tmp.renameTo(file(key))) {
            file(key).writeText(root.toString())
            tmp.delete()
        }
        prune()
    }

    /** Garde les [maxSnapshots] plus récents. */
    fun prune() {
        val files = directory.listFiles { f -> f.extension == "json" } ?: return
        if (files.size <= maxSnapshots) return
        files.sortedByDescending { it.lastModified() }.drop(maxSnapshots).forEach { it.delete() }
    }
}
