package com.chesslab.puzzles

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Upsert
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.random.Random

/**
 * La méthode Woodpecker : un lot FIXE de puzzles, résolu en entier, puis repris
 * en cycles successifs — pour en trouver plus, et plus vite, à chaque passage.
 * Pendant de `WoodpeckerPlan.swift`, mêmes décisions (23/10/2026) :
 *
 * - le programme ne touche PAS la répétition espacée des puzzles ;
 * - lots de 10, 25 ou 50 puzzles, 25 par défaut (ramenés de 25/50/100 le
 *   23/10/2026, à la demande de l'utilisateur) ;
 * - l'ordre est MÉLANGÉ à chaque cycle ;
 * - le nombre d'essais suit le réglage habituel ;
 * - réussi avec l'indice = réussi.
 *
 * Les puzzles sont COPIÉS dans le plan : un programme ne dépend ni de la
 * bibliothèque ni de la table des puzzles maison. Valeur pure et immuable —
 * chaque réponse rend un NOUVEAU plan —, vérifiable en JVM.
 */
data class WoodpeckerPlan(
    val items: List<Item>,
    val cycles: List<Cycle>,
) {
    data class Item(
        val fen: String,
        val solution: List<String>,
        val theme: String,
        val phase: String?,
        /** 0 = sans cote (puzzle maison), comme [Puzzle.rating]. */
        val rating: Int,
    ) {
        /** Le puzzle que l'écran de résolution sait jouer. */
        fun toPuzzle(index: Int) = Puzzle(
            id = "woodpecker-$index", fen = fen, solution = solution,
            theme = theme, rating = rating, phase = phase,
        )

        companion object {
            fun of(puzzle: Puzzle) = Item(puzzle.fen, puzzle.solution, puzzle.theme, puzzle.phase, puzzle.rating)
        }
    }

    /** Une réponse : trouvée ou non, et le temps passé dessus (secondes). */
    data class Attempt(val solved: Boolean, val seconds: Double)

    data class Cycle(
        val number: Int,
        /** L'ordre de passage de CE cycle : des index dans [items]. */
        val order: List<Int>,
        /** Les réponses dans l'ordre de passage ; leur nombre est la position. */
        val attempts: List<Attempt> = emptyList(),
        val startedAt: Long,
        val finishedAt: Long? = null,
    ) {
        val isComplete: Boolean get() = attempts.size >= order.size
        val solvedCount: Int get() = attempts.count { it.solved }
        /** Temps ACTIF : la somme des réponses, pas l'écart début-fin. */
        val activeSeconds: Double get() = attempts.sumOf { it.seconds }
    }

    val currentCycle: Cycle get() = cycles.last()

    /** Le puzzle à présenter, `null` une fois le cycle terminé. */
    val currentItemIndex: Int?
        get() = currentCycle.let { if (it.isComplete) null else it.order[it.attempts.size] }

    val previousCycle: Cycle? get() = if (cycles.size >= 2) cycles[cycles.size - 2] else null

    /** C8 : les deux cycles à comparer en barres. `null` sans cycle précédent bouclé. */
    val cycleComparison: CycleComparison?
        get() {
            val previous = previousCycle ?: return null
            if (!currentCycle.isComplete || !previous.isComplete) return null
            return CycleComparison.of(previous, currentCycle)
        }

    /** Enregistre la réponse au puzzle courant ; sans effet sur un cycle fini. */
    fun record(solved: Boolean, seconds: Double, now: Long = System.currentTimeMillis()): WoodpeckerPlan {
        if (currentCycle.isComplete) return this
        val cycle = currentCycle.copy(attempts = currentCycle.attempts + Attempt(solved, max(0.0, seconds)))
        val closed = if (cycle.isComplete) cycle.copy(finishedAt = now) else cycle
        return copy(cycles = cycles.dropLast(1) + closed)
    }

    /** Un nouveau passage sur le MÊME lot, dans un nouvel ordre. */
    fun startNextCycle(now: Long = System.currentTimeMillis(), random: Random = Random.Default): WoodpeckerPlan {
        if (!currentCycle.isComplete) return this
        val next = Cycle(currentCycle.number + 1, items.indices.shuffled(random), startedAt = now)
        return copy(cycles = cycles + next)
    }

    /** L'objectif classique : la moitié du temps du dernier cycle fini. */
    val nextCycleTargetSeconds: Double?
        get() = cycles.lastOrNull { it.isComplete }?.activeSeconds?.div(2)

    fun toJson(): String = JSONObject().apply {
        put("items", JSONArray().apply {
            items.forEach { item ->
                put(JSONObject().apply {
                    put("fen", item.fen)
                    put("solution", JSONArray(item.solution))
                    put("theme", item.theme)
                    item.phase?.let { put("phase", it) }
                    put("rating", item.rating)
                })
            }
        })
        put("cycles", JSONArray().apply {
            cycles.forEach { cycle ->
                put(JSONObject().apply {
                    put("number", cycle.number)
                    put("order", JSONArray(cycle.order))
                    put("attempts", JSONArray().apply {
                        cycle.attempts.forEach { put(JSONObject().put("solved", it.solved).put("seconds", it.seconds)) }
                    })
                    put("startedAt", cycle.startedAt)
                    cycle.finishedAt?.let { put("finishedAt", it) }
                })
            }
        })
    }.toString()

    companion object {
        val SIZES = listOf(10, 25, 50)
        const val DEFAULT_SIZE = 25

        /** Premier cycle d'un nouveau programme. `null` sans aucun puzzle. */
        fun start(items: List<Item>, now: Long = System.currentTimeMillis(), random: Random = Random.Default): WoodpeckerPlan? {
            if (items.isEmpty()) return null
            return WoodpeckerPlan(items, listOf(Cycle(1, items.indices.shuffled(random), startedAt = now)))
        }

        /** « 7:05 », « 1:02:03 » — les heures seulement quand il y en a. */
        fun formatDuration(seconds: Double): String {
            val total = max(0, seconds.roundToInt())
            val hours = total / 3600
            val minutes = (total % 3600) / 60
            val secs = total % 60
            return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, secs) else "%d:%02d".format(minutes, secs)
        }

        fun fromJson(json: String): WoodpeckerPlan? = runCatching {
            val root = JSONObject(json)
            val items = root.getJSONArray("items").let { array ->
                (0 until array.length()).map { i ->
                    val o = array.getJSONObject(i)
                    val solution = o.getJSONArray("solution")
                    Item(
                        fen = o.getString("fen"),
                        solution = (0 until solution.length()).map { solution.getString(it) },
                        theme = o.optString("theme", "tactic"),
                        phase = if (o.has("phase")) o.getString("phase") else null,
                        rating = o.optInt("rating", 0),
                    )
                }
            }
            val cycles = root.getJSONArray("cycles").let { array ->
                (0 until array.length()).map { i ->
                    val o = array.getJSONObject(i)
                    val order = o.getJSONArray("order")
                    val attempts = o.getJSONArray("attempts")
                    Cycle(
                        number = o.getInt("number"),
                        order = (0 until order.length()).map { order.getInt(it) },
                        attempts = (0 until attempts.length()).map {
                            val a = attempts.getJSONObject(it)
                            Attempt(a.getBoolean("solved"), a.getDouble("seconds"))
                        },
                        startedAt = o.getLong("startedAt"),
                        finishedAt = if (o.has("finishedAt")) o.getLong("finishedAt") else null,
                    )
                }
            }
            if (cycles.isEmpty()) null else WoodpeckerPlan(items, cycles)
        }.getOrNull()
    }
}

/**
 * Un programme Woodpecker enregistré. Pendant de `WoodpeckerProgram` (iOS),
 * dont le plan voyage de même en un seul bloc JSON.
 */
@Entity(tableName = "woodpecker_programs")
data class WoodpeckerProgram(
    @PrimaryKey val id: String,
    val createdAt: Long,
    val updatedAt: Long,
    /** Les critères du lot, en clair (« 50 puzzles · Intermédiaire »). */
    val criteria: String,
    val planJson: String,
    /** Arrêté par l'utilisateur : gardé, plus proposé. */
    val archived: Boolean = false,
) {
    val plan: WoodpeckerPlan? get() = WoodpeckerPlan.fromJson(planJson)
}

@Dao
interface WoodpeckerDao {
    @Query("SELECT * FROM woodpecker_programs WHERE id = :id")
    suspend fun byId(id: String): WoodpeckerProgram?

    /** Le programme en cours : le plus récent non arrêté. */
    @Query("SELECT * FROM woodpecker_programs WHERE archived = 0 ORDER BY updatedAt DESC LIMIT 1")
    suspend fun active(): WoodpeckerProgram?

    @Query("SELECT * FROM woodpecker_programs")
    suspend fun all(): List<WoodpeckerProgram>

    @Upsert
    suspend fun put(program: WoodpeckerProgram)

    @Query("DELETE FROM woodpecker_programs")
    suspend fun clear()
}

/**
 * C8 : comparaison de deux cycles bouclés. Pendant de `CycleComparison` (iOS) —
 * mêmes chiffres, même règle de progrès.
 */
data class CycleComparison(
    val previousScore: Double,
    val currentScore: Double,
    /** Temps ramenés à 0..1 par le plus long des deux. */
    val previousTime: Double,
    val currentTime: Double,
    /** Secondes gagnées (positif) ou perdues (négatif) sur le cycle d'avant. */
    val secondsSaved: Double,
) {
    /** Vrai quand le nouveau cycle est à la fois plus rapide et au moins aussi juste. */
    val isProgress: Boolean get() = secondsSaved > 0 && currentScore >= previousScore

    companion object {
        fun of(previous: WoodpeckerPlan.Cycle, current: WoodpeckerPlan.Cycle): CycleComparison {
            val longest = maxOf(1.0, previous.activeSeconds, current.activeSeconds)
            return CycleComparison(
                previousScore = previous.solvedCount.toDouble() / maxOf(1, previous.order.size),
                currentScore = current.solvedCount.toDouble() / maxOf(1, current.order.size),
                previousTime = previous.activeSeconds / longest,
                currentTime = current.activeSeconds / longest,
                secondsSaved = previous.activeSeconds - current.activeSeconds,
            )
        }
    }
}
