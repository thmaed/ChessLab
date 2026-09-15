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
class AnalysisEvalStore(
    private val directory: File,
    /**
     * Le profil écrit dans chaque instantané et exigé à la relecture. Donné à
     * la construction plutôt que lu d'un `Context` : le magasin n'a alors
     * besoin de rien d'Android, et se vérifie sur la JVM.
     */
    private val profile: String = DEFAULT_PROFILE,
) {

    companion object {
        const val currentSchema = 1

        /**
         * À CHANGER à chaque changement de moteur ou de budget de revue —
         * l'affinage des verdicts limites en fait partie. Le PALIER de
         * l'appareil y entre aussi : le budget d'une position en dépend, et
         * un cache écrit à 180 000 nœuds ne vaut pas un cache écrit à 300 000.
         *
         * Par défaut, le palier haut : c'est l'ancienne valeur, et un cache
         * écrit avant ce changement porte donc un profil différent — il est
         * ignoré, ce qui est exactement ce qu'on veut, puisqu'il ne connaît
         * pas l'affinage.
         */
        /** Le profil d'un appareil de palier haut — le repli, et celui des tests. */
        const val DEFAULT_PROFILE = "SF17.1/high/300000n+1600ms/MPV2+refine"

        fun engineProfile(context: android.content.Context): String {
            val tier = com.chesslab.engine.DevicePerformance.tier(context)
            val nodes = com.chesslab.engine.DevicePerformance.classificationNodes(context)
            val cap = com.chesslab.engine.DevicePerformance.classificationCapMs(context)
            return "SF17.1/$tier/${nodes}n+${cap}ms/MPV2+refine"
        }

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
    fun load(key: String, profile: String = this.profile): Map<Int, PositionEval>? {
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
        root.put("profile", profile)
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
