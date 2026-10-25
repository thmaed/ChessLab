package com.chesslab.dailysession

import android.content.Context
import com.chesslab.courses.CourseRepository
import com.chesslab.library.LibraryDatabase
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * La série de jours d'entraînement (A5). Pendant de `TrainingStreak`
 * (`TrainingDays.swift`) : combien de jours de suite on a travaillé,
 * aujourd'hui compris — ou jusqu'à hier si la journée n'a pas encore commencé,
 * car une série ne meurt qu'à la fin d'un jour manqué.
 *
 * Un jour compte quand une position d'ouverture est révisée, un puzzle tenté ou
 * une finale ouverte depuis la séance. Les révisions que l'app planifie
 * elle-même après une partie (A3) n'y comptent pas. Local à l'appareil.
 */
object TrainingStreak {
    fun key(millis: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate().toString()

    fun current(days: Set<String>, nowMillis: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): Int {
        var cursor: LocalDate = Instant.ofEpochMilli(nowMillis).atZone(zone).toLocalDate()
        if (cursor.toString() !in days) cursor = cursor.minusDays(1)
        var count = 0
        while (cursor.toString() in days) {
            count++
            cursor = cursor.minusDays(1)
        }
        return count
    }
}

/** Le journal des jours d'entraînement, dans les préférences. */
object TrainingDays {
    private const val FILE = "training_days"
    private const val DAYS = "days"
    private const val ENDGAME = "endgame_day"
    private const val OPENINGS_DONE = "openings_done"

    /** Au-delà, les jours les plus anciens ne changent plus rien à une série. */
    private const val RETAINED = 400

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun all(context: Context): Set<String> =
        prefs(context).getString(DAYS, "")!!.split(",").filter { it.isNotEmpty() }.toSet()

    fun markToday(context: Context, nowMillis: Long = System.currentTimeMillis()) {
        val today = TrainingStreak.key(nowMillis)
        val days = all(context)
        if (today in days) return
        prefs(context).edit().putString(DAYS, (days + today).sorted().takeLast(RETAINED).joinToString(",")).apply()
    }

    fun streak(context: Context, nowMillis: Long = System.currentTimeMillis()): Int =
        TrainingStreak.current(all(context), nowMillis)

    fun didTrainToday(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean =
        TrainingStreak.key(nowMillis) in all(context)

    /**
     * Combien de positions d'ouverture DUES ont été révisées aujourd'hui dans la
     * séance. C'est ce compteur — et non le nombre de positions encore dues — qui
     * dit que l'objectif du jour est atteint : avec un plafond, il reste presque
     * toujours des positions dues après les avoir faites. Pendant d'iOS.
     */
    fun openingsReviewedToday(context: Context, nowMillis: Long = System.currentTimeMillis()): Int {
        val parts = prefs(context).getString(OPENINGS_DONE, "")!!.split(":")
        return if (parts.size == 2 && parts[0] == TrainingStreak.key(nowMillis)) parts[1].toIntOrNull() ?: 0 else 0
    }

    fun addOpeningsReviewed(context: Context, n: Int = 1, nowMillis: Long = System.currentTimeMillis()) {
        val total = openingsReviewedToday(context, nowMillis) + n
        prefs(context).edit().putString(OPENINGS_DONE, "${TrainingStreak.key(nowMillis)}:$total").apply()
    }

    /** La finale de la séance a-t-elle été ouverte aujourd'hui ? */
    fun endgameOpenedToday(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean =
        prefs(context).getString(ENDGAME, null) == TrainingStreak.key(nowMillis)

    fun markEndgameOpened(context: Context, nowMillis: Long = System.currentTimeMillis()) {
        prefs(context).edit().putString(ENDGAME, TrainingStreak.key(nowMillis)).apply()
        markToday(context, nowMillis)
    }
}

/** Une étape de la séance du jour. */
data class DailySessionStep(
    val kind: Kind,
    /** Ce qu'il reste à faire : positions, puzzles… 1 pour la finale tant qu'elle n'est pas ouverte. */
    val remaining: Int,
    /** Pour la finale : le cours choisi. */
    val courseId: String? = null,
) {
    enum class Kind { openings, missedPuzzles, ownPuzzles, endgame }

    val isDone: Boolean get() = remaining == 0
}

/**
 * La séance du jour : un agrégateur, pas un nouveau contenu. Ouvertures dues →
 * puzzles ratés → puzzles de vos parties → une finale, avec la série de jours.
 * Pendant de `DailySessionPlan` (iOS).
 */
data class DailySessionPlan(val steps: List<DailySessionStep>, val streak: Int, val trainedToday: Boolean) {
    val pending: List<DailySessionStep> get() = steps.filter { !it.isDone }
    val isComplete: Boolean get() = pending.isEmpty()
}

object DailySessionBuilder {
    /**
     * Une séance se veut courte : au plus 5 puzzles par étape, et un plafond
     * RÉGLABLE de positions d'ouverture — 3, 5 ou 10, 5 par défaut (comme iOS).
     */
    const val DEFAULT_OPENINGS_CAP = 5
    const val PUZZLES_CAP = 5

    fun plan(
        openingsDue: Int, missedPuzzles: Int, ownPuzzles: Int,
        endgameCourseId: String?, endgameOpenedToday: Boolean,
        streak: Int, trainedToday: Boolean,
        openingsCap: Int = DEFAULT_OPENINGS_CAP,
        openingsDoneToday: Int = 0,
    ): DailySessionPlan {
        val steps = arrayListOf(
            DailySessionStep(DailySessionStep.Kind.openings, minOf(maxOf(0, openingsCap - openingsDoneToday), maxOf(0, openingsDue))),
            DailySessionStep(DailySessionStep.Kind.missedPuzzles, minOf(PUZZLES_CAP, maxOf(0, missedPuzzles))),
            DailySessionStep(DailySessionStep.Kind.ownPuzzles, minOf(PUZZLES_CAP, maxOf(0, ownPuzzles))),
        )
        if (endgameCourseId != null) {
            steps += DailySessionStep(DailySessionStep.Kind.endgame, if (endgameOpenedToday) 0 else 1, endgameCourseId)
        }
        return DailySessionPlan(steps, streak, trainedToday)
    }

    /**
     * La finale du jour : on tourne sur les finales du catalogue, une par jour
     * (jours locaux depuis l'epoch modulo leur nombre). Mêmes règles qu'iOS.
     */
    fun endgameCourseId(ids: List<String>, nowMillis: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): String? {
        if (ids.isEmpty()) return null
        val days = Instant.ofEpochMilli(nowMillis).atZone(zone).toLocalDate().toEpochDay()
        return ids[Math.floorMod(days, ids.size.toLong()).toInt()]
    }

    /** Le plan d'aujourd'hui, lu dans les bases locales. */
    suspend fun load(context: Context, nowMillis: Long = System.currentTimeMillis()): DailySessionPlan {
        val db = LibraryDatabase.get(context)
        val due = runCatching { db.training().dueCount(nowMillis) }.getOrDefault(0)
        val progress = runCatching { db.puzzleProgress().all() }.getOrDefault(emptyList())
        val missed = runCatching { db.puzzleProgress().missedIds().size }.getOrDefault(0)
        val byId = progress.associateBy { it.externalId }
        val own = runCatching { db.ownPuzzles().all() }.getOrDefault(emptyList())
            .count { (byId[it.uid]?.dueAt ?: 0L) <= nowMillis }
        val endgames = CourseRepository.catalog(context.assets).filter { it.isEndgame }.map { it.id }
        return plan(
            openingsDue = due, missedPuzzles = missed, ownPuzzles = own,
            endgameCourseId = endgameCourseId(endgames, nowMillis),
            endgameOpenedToday = TrainingDays.endgameOpenedToday(context, nowMillis),
            streak = TrainingDays.streak(context, nowMillis),
            trainedToday = TrainingDays.didTrainToday(context, nowMillis),
            openingsCap = com.chesslab.settings.SettingsStore.state.value.dailyOpeningsCap,
            openingsDoneToday = TrainingDays.openingsReviewedToday(context, nowMillis),
        )
    }
}
