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
    /**
     * L'issue de la dernière tentative ([PuzzleResult.raw]), `null` pour un
     * puzzle tenté avant ce champ. Pendant de `PuzzleProgress.lastOutcomeRaw`.
     */
    val lastOutcome: Int? = null,
)

/**
 * Comment s'est terminée la DERNIÈRE tentative d'un puzzle. Pendant de
 * `PuzzleOutcome.swift` (nommé autrement ici : [PuzzleOutcome] désigne déjà
 * l'état de l'écran de résolution).
 *
 * - [mastered] : trouvé sans fausse tentative.
 * - [partial] : au moins un coup juste, mais pas la séquence propre — raté plus
 *   loin dans la séquence, ou trouvé après une fausse tentative (3 essais).
 * - [missed] : raté dès le premier coup, ou puzzle d'un seul coup raté.
 *
 * L'indice ne rend PAS un puzzle partiel : réussi avec l'indice = réussi pour
 * la répétition espacée (décision du 23/10/2026), seule la cote en tient compte.
 */
enum class PuzzleResult(val raw: Int) {
    mastered(0), partial(1), missed(2);

    companion object {
        fun of(raw: Int?): PuzzleResult? = entries.firstOrNull { it.raw == raw }

        /** [playerMovesFound] : coups du joueur trouvés avant la fin. */
        fun classify(solved: Boolean, hadWrongAttempt: Boolean, playerMovesFound: Int): PuzzleResult =
            if (solved) (if (hadWrongAttempt) partial else mastered)
            else (if (playerMovesFound >= 1) partial else missed)
    }
}

@Dao
interface PuzzleProgressDao {
    @Query("SELECT * FROM puzzle_progress WHERE externalId = :id")
    suspend fun byId(id: String): PuzzleProgress?

    /** Les puzzles à revoir, les plus en retard d'abord. */
    @Query("SELECT * FROM puzzle_progress WHERE dueAt IS NOT NULL AND dueAt <= :now ORDER BY dueAt ASC LIMIT :limit")
    suspend fun due(now: Long, limit: Int): List<PuzzleProgress>

    @Query("SELECT * FROM puzzle_progress")
    suspend fun all(): List<PuzzleProgress>

    /** Ratés à la dernière tentative, dus ou non — voir `PuzzleFilter.missedOnly`. */
    @Query(
        """SELECT externalId FROM puzzle_progress WHERE lastOutcome = 2
           OR (lastOutcome IS NULL AND failureCount > 0 AND repetitions = 0)"""
    )
    suspend fun missedIds(): List<String>

    /** Partiels à la dernière tentative (« À revoir »), dus ou non. */
    @Query("SELECT externalId FROM puzzle_progress WHERE lastOutcome = 1")
    suspend fun reviewIds(): List<String>

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
    private const val PARTIAL_QUALITY = 3.0
    private const val FAILURE_QUALITY = 2.0
    /** Retour d'un puzzle partiel : entre le lendemain d'un échec et les six jours de la 2e réussite. */
    const val PARTIAL_INTERVAL_DAYS = 2
    const val DAY_MS = 24L * 60 * 60 * 1000

    /** L'état suivant, après une réussite ou un échec. */
    fun next(current: PuzzleProgress, success: Boolean): PuzzleProgress =
        next(current, if (success) PuzzleResult.mastered else PuzzleResult.missed)

    /**
     * Même calcul, avec l'issue à trois états. Un partiel garde `repetitions`
     * tel quel (ni remis à zéro, ni incrémenté) et revient dans
     * [PARTIAL_INTERVAL_DAYS] jours. `successCount`/`failureCount` suivent
     * `résolu ou non`, comme avant : les statistiques ne bougent pas.
     */
    fun next(current: PuzzleProgress, result: PuzzleResult, solved: Boolean = result == PuzzleResult.mastered): PuzzleProgress {
        val success = result == PuzzleResult.mastered
        val quality = when (result) {
            PuzzleResult.mastered -> SUCCESS_QUALITY
            PuzzleResult.partial -> PARTIAL_QUALITY
            PuzzleResult.missed -> FAILURE_QUALITY
        }
        val delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
        val easiness = max(MINIMUM_EASINESS, current.easinessFactor + delta)

        if (result == PuzzleResult.partial) {
            return current.copy(
                successCount = current.successCount + if (solved) 1 else 0,
                failureCount = current.failureCount + if (solved) 0 else 1,
                easinessFactor = easiness,
                intervalDays = PARTIAL_INTERVAL_DAYS,
                lastOutcome = result.raw,
            )
        }
        if (!success) {
            // Un échec remet le compteur à zéro et rapproche la révision à
            // demain : ce qu'on vient de rater se revoit vite.
            return current.copy(
                failureCount = current.failureCount + 1,
                easinessFactor = easiness,
                intervalDays = 1,
                repetitions = 0,
                lastOutcome = result.raw,
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
            lastOutcome = result.raw,
        )
    }

    /** La date de la prochaine révision, en millisecondes. */
    fun dueAt(progress: PuzzleProgress, now: Long): Long = now + progress.intervalDays * DAY_MS
}
