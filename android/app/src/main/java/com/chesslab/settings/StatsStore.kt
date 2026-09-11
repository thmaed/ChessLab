package com.chesslab.settings

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/** Ce que l'app retient de vos puzzles. */
data class PuzzleStats(val attempted: Int = 0, val solved: Int = 0) {
    val rate: Int get() = if (attempted == 0) 0 else solved * 100 / attempted
}

private val Context.statsStore by preferencesDataStore("stats")

/**
 * Les compteurs de puzzles.
 *
 * Séparés des réglages : ce ne sont pas des préférences mais un HISTORIQUE, et
 * les mélanger rendrait une remise à zéro des réglages destructrice.
 */
object StatsStore {

    private val attempted = intPreferencesKey("puzzlesAttempted")
    private val solved = intPreferencesKey("puzzlesSolved")
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun puzzles(context: Context): Flow<PuzzleStats> =
        context.applicationContext.statsStore.data.map {
            PuzzleStats(it[attempted] ?: 0, it[solved] ?: 0)
        }

    fun recordPuzzle(context: Context, solvedIt: Boolean) {
        val store = context.applicationContext.statsStore
        scope.launch {
            store.edit {
                it[attempted] = (it[attempted] ?: 0) + 1
                if (solvedIt) it[solved] = (it[solved] ?: 0) + 1
            }
        }
    }
}
