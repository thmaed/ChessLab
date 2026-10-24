package com.chesslab.courses

import android.content.Context
import com.chesslab.library.LibraryDatabase
import com.chesslab.training.TrainingQueue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Ce que la carte d'un cours montre en plus de son texte (C5) : la position
 * clé en vignette et la maîtrise (positions travaillées / à travailler).
 * Pendant de `CourseCardInfo.swift`.
 */
data class CourseCardInfo(val fen: String, val studied: Int, val total: Int) {
    val progress: Float get() = if (total == 0) 0f else minOf(1f, studied.toFloat() / total)

    companion object {
        /** Une ouverture : la position après dix demi-coups de la ligne principale ; une finale : la position de départ. */
        const val OPENING_PLIES = 10

        fun thumbnailFen(course: Course, isEndgame: Boolean): String {
            if (isEndgame) return course.rootFEN
            return TrainingQueue.mainLine(course).take(OPENING_PLIES).lastOrNull()?.second?.toFEN ?: course.rootFEN
        }

        fun compute(course: Course, entry: CatalogEntry, studied: Set<String>): CourseCardInfo {
            val cards = TrainingQueue.trainableCards(course, entry.side)
            return CourseCardInfo(
                fen = thumbnailFen(course, entry.isEndgame),
                studied = cards.count { it.fenKey in studied },
                total = cards.size,
            )
        }

        /** Les cartes de tous les cours d'une liste, calculées hors du dessin. */
        suspend fun load(context: Context, entries: List<CatalogEntry>): Map<String, CourseCardInfo> =
            withContext(Dispatchers.IO) {
                val studied = LibraryDatabase.get(context).training().allProgress()
                    .filter { it.reps > 0 }.map { it.fenKey }.toSet()
                val out = HashMap<String, CourseCardInfo>()
                for (entry in entries) {
                    val course = CourseRepository.course(context.assets, entry.id) ?: continue
                    out[entry.id] = compute(course, entry, studied)
                }
                out
            }
    }
}
