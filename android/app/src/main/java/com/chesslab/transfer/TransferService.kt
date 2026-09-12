package com.chesslab.transfer

import android.content.Context
import android.net.Uri
import android.os.Build
import com.chesslab.library.GameRecord
import com.chesslab.library.LibraryDatabase
import com.chesslab.settings.StatsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream

/**
 * L'export et l'import d'un fichier de transfert.
 *
 * Le seul endroit qui touche à la fois la base, le disque et le format ; tout
 * ce qui DÉCIDE vit dans [TransferMerge] et se teste sans rien de tout cela.
 *
 * Le fichier est gzippé : il est presque entièrement fait de clés FEN
 * répétées, qui se compriment d'un facteur trois.
 */
object TransferService {

    /** Le nom proposé au sélecteur de fichier. */
    fun suggestedName(): String {
        val date = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ROOT)
            .format(java.util.Date())
        return "chesslab-$date.clab"
    }

    /** Ramasse tout ce qui voyage. */
    suspend fun collect(context: Context): TransferFile = withContext(Dispatchers.IO) {
        val db = LibraryDatabase.get(context)
        val stats = StatsStore.snapshot(context)
        TransferFile(
            exportedAt = System.currentTimeMillis(),
            device = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            reviewLog = db.training().allLogs().map {
                TransferFile.LogEntry(
                    it.uid, it.fenKey, it.ratingRaw, it.reviewedAt,
                    it.elapsedDays, it.scheduledDays, it.stabilityAfter,
                )
            },
            games = db.games().allOnce().map {
                TransferFile.GameEntry(
                    it.uid, it.playedAt, it.white, it.black, it.result,
                    it.source, it.variant, it.moveCount, it.pgn,
                )
            },
            puzzlesAttempted = stats.attempted,
            puzzlesSolved = stats.solved,
        )
    }

    suspend fun export(context: Context, target: Uri): Result<Int> = withContext(Dispatchers.IO) {
        runCatching {
            val file = collect(context)
            context.contentResolver.openOutputStream(target)?.use { out ->
                GZIPOutputStream(out).use { it.write(TransferFile.encode(file).toByteArray()) }
            } ?: error("flux de sortie indisponible")
            file.reviewLog.size
        }
    }

    /**
     * Lit un fichier et le FUSIONNE — jamais ne remplace.
     *
     * L'état FSRS de chaque position touchée est réécrit d'après le journal
     * fusionné : c'est le rejeu qui fait foi, pas ce que l'un ou l'autre
     * appareil avait calculé de son côté.
     */
    suspend fun import(context: Context, source: Uri): Result<TransferMerge.Summary> =
        withContext(Dispatchers.IO) {
            runCatching {
                val text = context.contentResolver.openInputStream(source)?.use { raw ->
                    // Gzippé par nous, mais un fichier recopié à la main peut
                    // arriver en clair : on accepte les deux.
                    val bytes = raw.readBytes()
                    if (bytes.size > 2 && bytes[0] == 0x1f.toByte() && bytes[1] == 0x8b.toByte()) {
                        GZIPInputStream(bytes.inputStream()).use { it.readBytes() }.decodeToString()
                    } else {
                        bytes.decodeToString()
                    }
                } ?: error("fichier illisible")

                val incoming = TransferFile.decode(text).getOrThrow()
                val db = LibraryDatabase.get(context)
                val training = db.training()

                val localLog = training.allLogs()
                val merged = TransferMerge.mergeLogs(localLog, incoming.reviewLog)
                val added = merged.size - localLog.size

                if (added > 0) {
                    training.logAll(merged.filter { entry -> localLog.none { it.uid == entry.uid } })
                    // Seules les positions TOUCHÉES sont réécrites : rejouer
                    // tout le journal pour en réécrire l'intégralité coûterait
                    // cher et ne changerait rien aux autres.
                    val touched = incoming.reviewLog.mapTo(HashSet()) { it.fenKey }
                    val replayed = TransferMerge.replay(merged).filterKeys { it in touched }
                    training.putAll(replayed.values.toList())
                }

                val localGames = db.games().allOnce()
                val fresh = TransferMerge.mergeGames(localGames.mapTo(HashSet()) { it.uid }, incoming.games)
                if (fresh.isNotEmpty()) {
                    db.games().insertAll(
                        fresh.map {
                            GameRecord(
                                playedAt = it.playedAt, uid = it.uid, white = it.white,
                                black = it.black, result = it.result, source = it.source,
                                variant = it.variant, moveCount = it.moveCount, pgn = it.pgn,
                            )
                        }
                    )
                }

                StatsStore.raiseTo(context, incoming.puzzlesAttempted, incoming.puzzlesSolved)

                TransferMerge.Summary(
                    newReviews = added,
                    newGames = fresh.size,
                    positionsAffected = incoming.reviewLog.mapTo(HashSet()) { it.fenKey }.size,
                )
            }
        }
}
