package com.chesslab.library

import android.content.Context
import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import kotlinx.coroutines.flow.Flow

/**
 * Une partie enregistrée. Pendant réduit de `GameRecord.swift` (SwiftData).
 *
 * Le PGN est la source de vérité : il porte les coups, les tags et, pour une
 * variante ou une position de départ non standard, la FEN. Le reste des
 * colonnes n'existe que pour dresser une liste sans relire chaque partie.
 */
@Entity(tableName = "games")
data class GameRecord(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "played_at") val playedAt: Long,
    val white: String,
    val black: String,
    /** « 1-0 », « 0-1 », « 1/2-1/2 » ou « * » pour une partie inachevée. */
    val result: String,
    /** Le mode dont vient la partie : « engine », « twoPlayer », « variant »… */
    val source: String,
    /** L'identifiant de variante, ou `null` pour les échecs classiques. */
    val variant: String? = null,
    @ColumnInfo(name = "move_count") val moveCount: Int,
    val pgn: String,
)

@Dao
interface GameDao {
    @Query("SELECT * FROM games ORDER BY played_at DESC")
    fun all(): Flow<List<GameRecord>>

    @Query("SELECT * FROM games WHERE id = :id")
    suspend fun byId(id: Long): GameRecord?

    @Insert
    suspend fun insert(record: GameRecord): Long

    @Query("DELETE FROM games WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("SELECT COUNT(*) FROM games")
    suspend fun count(): Int
}

/**
 * Une partie EN COURS, pour la reprendre.
 *
 * Une seule par mode : reprendre, c'est reprendre LA partie interrompue, pas
 * en choisir une dans une pile. Les coups sont gardés en UCI — le format que
 * le plateau rejoue sans ambiguïté.
 */
@Entity(tableName = "autosaves")
data class Autosave(
    /** Le mode : « engine », « twoPlayer »… Clé primaire : une par mode. */
    @PrimaryKey val mode: String,
    @ColumnInfo(name = "saved_at") val savedAt: Long,
    /** Les coups joués, en UCI, séparés par des espaces. */
    val moves: String,
    /** L'adversaire, pour le rétablir tel quel. */
    @ColumnInfo(name = "opponent_id") val opponentId: String? = null,
    val level: Double = 1500.0,
    val label: String,
) {
    val moveList: List<String> get() = moves.split(" ").filter { it.isNotEmpty() }
}

@Dao
interface AutosaveDao {
    @Query("SELECT * FROM autosaves ORDER BY saved_at DESC")
    fun all(): Flow<List<Autosave>>

    @Query("SELECT * FROM autosaves WHERE mode = :mode")
    suspend fun byMode(mode: String): Autosave?

    @Insert(onConflict = androidx.room.OnConflictStrategy.REPLACE)
    suspend fun put(autosave: Autosave)

    @Query("DELETE FROM autosaves WHERE mode = :mode")
    suspend fun clear(mode: String)
}

@Database(entities = [GameRecord::class, Autosave::class], version = 2, exportSchema = false)
abstract class LibraryDatabase : RoomDatabase() {
    abstract fun games(): GameDao
    abstract fun autosaves(): AutosaveDao

    companion object {
        @Volatile private var instance: LibraryDatabase? = null

        fun get(context: Context): LibraryDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext, LibraryDatabase::class.java, "chesslab.db",
            )
                // Une base de PARTIES : rien d'irremplaçable, tout est
                // reconstructible ou déjà joué. Une migration ratée ne doit pas
                // empêcher l'app de démarrer.
                .fallbackToDestructiveMigration()
                .build().also { instance = it }
        }
    }
}
