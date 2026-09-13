package com.chesslab.puzzles

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Upsert
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Ce qu'on sait d'un puzzle déjà rencontré. Pendant de `PuzzleProgress`.
 *
 * **Pourquoi SM-2 ici et FSRS pour les ouvertures.** Ce n'est pas une
 * incohérence : c'est le choix d'iOS, repris tel quel. Une position d'ouverture
 * se RÉVISE — on la reverra des dizaines de fois, et FSRS tire parti de cet
 * historique. Un puzzle, lui, se résout une fois ; le revoir sert surtout à
 * vérifier qu'on n'a pas oublié le motif, et l'algorithme simple suffit.
 */
@Entity(tableName = "puzzle_progress")
data class PuzzleProgress(
    @PrimaryKey val externalId: String,
    val successCount: Int = 0,
    val failureCount: Int = 0,
    val easinessFactor: Double = 2.5,
    val intervalDays: Int = 0,
    val repetitions: Int = 0,
    /** Quand ce puzzle redevient intéressant. `null` = jamais résolu. */
    val dueAt: Long? = null,
    val updatedAt: Long = 0,
    /** Le thème, gardé ici pour les statistiques sans relire la base. */
    val theme: String = "tactic",
    /**
     * La note Lichess du puzzle, pour ventiler la réussite par palier. 0 pour
     * un puzzle tiré de vos parties, qui n'en a pas — comme iOS, il compte
     * dans le total mais dans aucun palier.
     */
    val rating: Int = 0,
)

@Dao
interface PuzzleProgressDao {
    @Query("SELECT * FROM puzzle_progress WHERE externalId = :id")
    suspend fun byId(id: String): PuzzleProgress?

    /** Les puzzles à revoir, les plus en retard d'abord. */
    @Query("SELECT * FROM puzzle_progress WHERE dueAt IS NOT NULL AND dueAt <= :now ORDER BY dueAt ASC LIMIT :limit")
    suspend fun due(now: Long, limit: Int): List<PuzzleProgress>

    @Query("SELECT * FROM puzzle_progress")
    suspend fun all(): List<PuzzleProgress>

    @Query("SELECT COUNT(*) FROM puzzle_progress WHERE dueAt IS NOT NULL AND dueAt <= :now")
    suspend fun dueCount(now: Long): Int

    @Upsert
    suspend fun put(progress: PuzzleProgress)

    @Query("DELETE FROM puzzle_progress")
    suspend fun clear()
}

/**
 * Le calendrier de révision, à la SM-2. Pendant de `SpacedRepetition.swift`.
 *
 * Fonction pure : elle ne connaît ni base, ni horloge. On lui donne l'état et
 * le résultat, elle rend le nouvel état — c'est ce qui la rend vérifiable sur
 * des valeurs écrites à la main.
 */
object PuzzleSchedule {

    private const val MINIMUM_EASINESS = 1.3
    private const val SUCCESS_QUALITY = 5.0
    private const val FAILURE_QUALITY = 2.0
    const val DAY_MS = 24L * 60 * 60 * 1000

    /** L'état suivant, après une réussite ou un échec. */
    fun next(current: PuzzleProgress, success: Boolean): PuzzleProgress {
        val quality = if (success) SUCCESS_QUALITY else FAILURE_QUALITY
        val delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
        val easiness = max(MINIMUM_EASINESS, current.easinessFactor + delta)

        if (!success) {
            // Un échec remet le compteur à zéro et rapproche la révision à
            // demain : ce qu'on vient de rater se revoit vite.
            return current.copy(
                failureCount = current.failureCount + 1,
                easinessFactor = easiness,
                intervalDays = 1,
                repetitions = 0,
            )
        }

        val repetitions = current.repetitions + 1
        val interval = when (repetitions) {
            1 -> 1
            2 -> 6
            else -> (current.intervalDays * easiness).roundToInt()
        }
        return current.copy(
            successCount = current.successCount + 1,
            easinessFactor = easiness,
            intervalDays = max(1, interval),
            repetitions = repetitions,
        )
    }

    /** La date de la prochaine révision, en millisecondes. */
    fun dueAt(progress: PuzzleProgress, now: Long): Long = now + progress.intervalDays * DAY_MS
}
