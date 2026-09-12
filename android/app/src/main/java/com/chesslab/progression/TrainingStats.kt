package com.chesslab.progression

import android.content.Context
import com.chesslab.library.LibraryDatabase
import com.chesslab.training.Fsrs
import com.chesslab.training.FsrsRating
import com.chesslab.training.TrainingQueue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt
import com.chesslab.R

/**
 * Ce que la répétition espacée a retenu de vous.
 *
 * Tout se déduit de la table de progression et du journal — rien n'est
 * inventé, et un chiffre sans données se tait plutôt que d'afficher un zéro
 * qui ressemblerait à un résultat.
 */
data class TrainingStats(
    /** Positions vues au moins une fois. */
    val studied: Int,
    /** Positions acquises : au moins une semaine avant le prochain oubli. */
    val solid: Int,
    /** Positions oubliées ou pas encore solides. */
    val hard: Int,
    /** Positions dont l'échéance est passée. */
    val due: Int,
    val reviewsThisWeek: Int,
    /** Part de révisions réussies sur les trente derniers jours, ou `null`. */
    val retention: Double?,
    /** Quand la prochaine échéance tombe, si aucune n'est déjà passée. */
    val nextDueAt: Long?,
) {
    val retentionLabel: String get() = retention?.let { "${(it * 100).roundToInt()} %" } ?: "—"

    fun nextDueLabel(context: Context): String? {
        if (due > 0) return null
        val next = nextDueAt ?: return null
        val days = ((next - System.currentTimeMillis()).toDouble() / Fsrs.DAY_MS).roundToInt()
        return when {
            days <= 0 -> context.getString(R.string.progress_next_today)
            days == 1 -> context.getString(R.string.progress_next_tomorrow)
            else -> context.getString(R.string.progress_next_days, days)
        }
    }

    companion object {
        /** Au-delà d'une semaine de stabilité, la position tient : on la dit acquise. */
        private const val SOLID_DAYS = 7.0

        suspend fun read(context: Context): TrainingStats = withContext(Dispatchers.IO) {
            val dao = LibraryDatabase.get(context).training()
            val all = dao.allProgress()
            val now = System.currentTimeMillis()
            val week = now - 7 * Fsrs.DAY_MS
            val month = now - 30 * Fsrs.DAY_MS

            // Le journal porte la vérité des notes : la table, elle, n'a que
            // l'état courant. Mille entrées suffisent à une moyenne honnête.
            val logs = dao.recentLogs(1000).filter { it.reviewedAt >= month }
            val retention = if (logs.isEmpty()) null
            else logs.count { it.ratingRaw != FsrsRating.again.raw }.toDouble() / logs.size

            TrainingStats(
                studied = all.count { it.reps > 0 },
                solid = all.count { it.reps > 0 && it.stability >= SOLID_DAYS },
                hard = all.count { TrainingQueue.isHard(it.snapshot) },
                due = all.count { it.dueAt != null && it.dueAt <= now },
                reviewsThisWeek = dao.reviewsSince(week),
                retention = retention,
                nextDueAt = all.mapNotNull { it.dueAt }.filter { it > now }.minOrNull(),
            )
        }
    }
}
