package com.chesslab.training

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Upsert

/**
 * La progression d'une POSITION, indexée par FEN normalisée — jamais par
 * identifiant de cours ni index de coup.
 *
 * C'est la règle d'architecture fondamentale, reprise telle quelle d'iOS :
 * régénérer ou approfondir les arbres ne détruit jamais la mémorisation, et
 * une position apprise dans une ouverture compte dans toutes celles où elle
 * transpose.
 *
 * L'état FSRS-5 est stocké BRUT : [Fsrs] n'est qu'un calculateur, la vérité
 * vit ici.
 */
@Entity(tableName = "opening_progress")
data class OpeningProgress(
    @PrimaryKey @ColumnInfo(name = "fen_key") val fenKey: String,
    val stability: Double = 0.0,
    val difficulty: Double = 0.0,
    /** [FsrsState] : 0 = neuve … 3 = réapprentissage. */
    @ColumnInfo(name = "state_raw") val stateRaw: Int = 0,
    val reps: Int = 0,
    val lapses: Int = 0,
    @ColumnInfo(name = "last_reviewed_at") val lastReviewedAt: Long? = null,
    @ColumnInfo(name = "due_at") val dueAt: Long? = null,
    @ColumnInfo(name = "first_seen_at") val firstSeenAt: Long? = null,
    @ColumnInfo(name = "updated_at") val updatedAt: Long = 0,
) {
    val card: FsrsCard
        get() = FsrsCard(stability, difficulty, FsrsState.of(stateRaw), reps, lapses, lastReviewedAt, dueAt)

    val snapshot: ProgressSnapshot get() =
        ProgressSnapshot(dueAt, lapses, stability, reps, FsrsState.of(stateRaw))

    fun applying(outcome: FsrsOutcome): OpeningProgress {
        val c = outcome.card
        return copy(
            stability = c.stability, difficulty = c.difficulty, stateRaw = c.state.raw,
            reps = c.reps, lapses = c.lapses,
            lastReviewedAt = c.lastReview, dueAt = c.due,
            firstSeenAt = firstSeenAt ?: outcome.reviewedAt,
            updatedAt = outcome.reviewedAt,
        )
    }
}

/**
 * Le journal des révisions : une entrée par événement, jamais réécrite.
 *
 * Il sert à reconstruire une courbe de progression et, le jour où la synchro
 * arrivera, il fusionne par union plutôt que de s'écraser.
 */
@Entity(tableName = "opening_review_log")
data class OpeningReviewLog(
    /**
     * L'identifiant de l'ÉVÉNEMENT, tiré au sort à l'écriture.
     *
     * Ce n'est pas un détail : c'est lui qui rend la fusion possible. Un
     * compteur auto-incrémenté est LOCAL — deux appareils écriraient chacun
     * 1, 2, 3… et l'union perdrait la moitié des révisions. Un UUID n'entre
     * jamais en collision, donc réunir deux journaux se réduit à supprimer
     * les doublons.
     */
    @PrimaryKey val uid: String = java.util.UUID.randomUUID().toString(),
    @ColumnInfo(name = "fen_key") val fenKey: String,
    /** [FsrsRating] : 1 = encore … 4 = facile. */
    @ColumnInfo(name = "rating_raw") val ratingRaw: Int,
    @ColumnInfo(name = "reviewed_at") val reviewedAt: Long,
    @ColumnInfo(name = "elapsed_days") val elapsedDays: Double,
    @ColumnInfo(name = "scheduled_days") val scheduledDays: Double,
    @ColumnInfo(name = "stability_after") val stabilityAfter: Double,
)

@Dao
interface TrainingDao {
    @Query("SELECT * FROM opening_progress")
    suspend fun allProgress(): List<OpeningProgress>

    @Query("SELECT * FROM opening_progress WHERE fen_key = :fenKey")
    suspend fun progress(fenKey: String): OpeningProgress?

    @Upsert
    suspend fun put(progress: OpeningProgress)

    /** `IGNORE` : réimporter un journal déjà connu ne doit rien casser. */
    @Insert(onConflict = androidx.room.OnConflictStrategy.IGNORE)
    suspend fun log(entry: OpeningReviewLog)

    @Insert(onConflict = androidx.room.OnConflictStrategy.IGNORE)
    suspend fun logAll(entries: List<OpeningReviewLog>)

    @Query("SELECT * FROM opening_review_log ORDER BY reviewed_at")
    suspend fun allLogs(): List<OpeningReviewLog>

    @Upsert
    suspend fun putAll(rows: List<OpeningProgress>)

    @Query("SELECT COUNT(*) FROM opening_progress WHERE due_at IS NOT NULL AND due_at <= :now")
    suspend fun dueCount(now: Long): Int

    @Query("SELECT COUNT(*) FROM opening_progress WHERE reps > 0")
    suspend fun studiedCount(): Int

    @Query("SELECT COUNT(*) FROM opening_review_log WHERE reviewed_at >= :since")
    suspend fun reviewsSince(since: Long): Int

    @Query("SELECT * FROM opening_review_log ORDER BY reviewed_at DESC LIMIT :limit")
    suspend fun recentLogs(limit: Int): List<OpeningReviewLog>

    @Query("DELETE FROM opening_progress")
    suspend fun clearProgress()

    @Query("DELETE FROM opening_review_log")
    suspend fun clearLogs()
}
