package com.chesslab.transfer

import org.json.JSONArray
import org.json.JSONObject

/**
 * Le fichier de transfert : ce qu'un appareil emporte chez un autre.
 *
 * ## Ce qu'il contient, et ce qu'il ne contient PAS
 *
 * Le JOURNAL des révisions, les parties, et les compteurs de puzzles. Rien
 * d'autre — en particulier **pas l'état FSRS des positions** : il se
 * RECALCULE en rejouant le journal. C'est la stratégie d'`OpeningProgressSync`
 * côté iOS, et elle a deux mérites ici. Le fichier est deux fois plus léger,
 * et surtout il n'y a plus rien à arbitrer : deux journaux se réunissent, un
 * état FSRS se contredirait.
 *
 * Pas non plus la bibliothèque de puzzles ni les cours : ils sont EMBARQUÉS,
 * identiques sur chaque appareil. iOS l'a appris à ses dépens — dans un store
 * commun, la synchro poussait les cent mille puzzles vers iCloud.
 *
 * ## Le format
 *
 * Du JSON, compressé en gzip à l'écriture. Il porte son nom et sa version :
 * un fichier d'une version future est REFUSÉ avec un message clair plutôt
 * qu'à moitié lu.
 *
 * ```json
 * { "format": "chesslab-transfer", "version": 1, "exportedAt": 1757…,
 *   "device": "Pixel 7",
 *   "reviewLog": [ { "uid": "…", "fen": "…", "rating": 3, "at": 1757…,
 *                    "elapsedDays": 0.0, "scheduledDays": 1.0, "stabilityAfter": 3.17 } ],
 *   "games": [ { "uid": "…", "playedAt": …, "white": "…", "black": "…",
 *                "result": "1-0", "source": "engine", "variant": null,
 *                "moveCount": 42, "pgn": "…" } ],
 *   "puzzles": { "attempted": 12, "solved": 9 } }
 * ```
 *
 * Le format est le CONTRAT entre les plateformes : l'app iOS doit écrire et
 * lire exactement celui-ci pour que les deux se parlent.
 */
data class TransferFile(
    val exportedAt: Long,
    val device: String,
    val reviewLog: List<LogEntry>,
    val games: List<GameEntry>,
    val puzzlesAttempted: Int,
    val puzzlesSolved: Int,
) {
    data class LogEntry(
        val uid: String,
        val fenKey: String,
        val rating: Int,
        val reviewedAt: Long,
        val elapsedDays: Double,
        val scheduledDays: Double,
        val stabilityAfter: Double,
    )

    data class GameEntry(
        val uid: String,
        val playedAt: Long,
        val white: String,
        val black: String,
        val result: String,
        val source: String,
        val variant: String?,
        val moveCount: Int,
        val pgn: String,
    )

    companion object {
        const val FORMAT = "chesslab-transfer"
        const val VERSION = 1

        /** Ce qui peut mal tourner à la lecture, dit une fois pour toutes. */
        sealed class Failure {
            /** Le fichier n'est pas du JSON, ou pas le nôtre. */
            data object NotOurs : Failure()
            /** Écrit par une version PLUS RÉCENTE de l'app. */
            data class TooNew(val version: Int) : Failure()
        }

        fun encode(file: TransferFile): String {
            val root = JSONObject()
            root.put("format", FORMAT)
            root.put("version", VERSION)
            root.put("exportedAt", file.exportedAt)
            root.put("device", file.device)

            val log = JSONArray()
            for (e in file.reviewLog) {
                log.put(
                    JSONObject()
                        .put("uid", e.uid).put("fen", e.fenKey).put("rating", e.rating)
                        .put("at", e.reviewedAt).put("elapsedDays", e.elapsedDays)
                        .put("scheduledDays", e.scheduledDays).put("stabilityAfter", e.stabilityAfter)
                )
            }
            root.put("reviewLog", log)

            val games = JSONArray()
            for (g in file.games) {
                games.put(
                    JSONObject()
                        .put("uid", g.uid).put("playedAt", g.playedAt)
                        .put("white", g.white).put("black", g.black).put("result", g.result)
                        .put("source", g.source).put("variant", g.variant ?: JSONObject.NULL)
                        .put("moveCount", g.moveCount).put("pgn", g.pgn)
                )
            }
            root.put("games", games)
            root.put("puzzles", JSONObject()
                .put("attempted", file.puzzlesAttempted).put("solved", file.puzzlesSolved))
            return root.toString()
        }

        /**
         * Lit un fichier. Rend la [Failure] plutôt que de lever : un fichier
         * choisi par erreur dans le sélecteur est un cas ORDINAIRE, pas une
         * anomalie.
         */
        fun decode(text: String): Result<TransferFile> {
            val root = runCatching { JSONObject(text) }.getOrNull()
                ?: return Result.failure(DecodeError(Failure.NotOurs))
            if (root.optString("format") != FORMAT) {
                return Result.failure(DecodeError(Failure.NotOurs))
            }
            val version = root.optInt("version", 0)
            if (version > VERSION) return Result.failure(DecodeError(Failure.TooNew(version)))

            val log = ArrayList<LogEntry>()
            root.optJSONArray("reviewLog")?.let { array ->
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    val uid = o.optString("uid")
                    val fen = o.optString("fen")
                    if (uid.isEmpty() || fen.isEmpty()) continue
                    log += LogEntry(
                        uid, fen, o.optInt("rating", 3), o.optLong("at"),
                        o.optDouble("elapsedDays", 0.0), o.optDouble("scheduledDays", 0.0),
                        o.optDouble("stabilityAfter", 0.0),
                    )
                }
            }

            val games = ArrayList<GameEntry>()
            root.optJSONArray("games")?.let { array ->
                for (i in 0 until array.length()) {
                    val o = array.getJSONObject(i)
                    val uid = o.optString("uid")
                    if (uid.isEmpty()) continue
                    games += GameEntry(
                        uid, o.optLong("playedAt"), o.optString("white"), o.optString("black"),
                        o.optString("result", "*"), o.optString("source", "engine"),
                        o.optString("variant").ifEmpty { null }.takeIf { !o.isNull("variant") },
                        o.optInt("moveCount"), o.optString("pgn"),
                    )
                }
            }

            val puzzles = root.optJSONObject("puzzles")
            return Result.success(
                TransferFile(
                    exportedAt = root.optLong("exportedAt"),
                    device = root.optString("device"),
                    reviewLog = log,
                    games = games,
                    puzzlesAttempted = puzzles?.optInt("attempted") ?: 0,
                    puzzlesSolved = puzzles?.optInt("solved") ?: 0,
                )
            )
        }
    }

    /** Porte la cause pour que l'appelant sache quoi dire à l'utilisateur. */
    class DecodeError(val failure: Failure) : Exception(failure.toString())
}
