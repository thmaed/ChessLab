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
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
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
    /**
     * L'identité de la partie entre appareils. Le `id` auto-incrémenté est
     * local : deux téléphones donneraient le même à deux parties différentes.
     */
    val uid: String = java.util.UUID.randomUUID().toString(),
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

    @Insert(onConflict = androidx.room.OnConflictStrategy.IGNORE)
    suspend fun insert(record: GameRecord): Long

    @Query("SELECT * FROM games ORDER BY played_at")
    suspend fun allOnce(): List<GameRecord>

    @Insert(onConflict = androidx.room.OnConflictStrategy.IGNORE)
    suspend fun insertAll(records: List<GameRecord>)

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

@Database(
    entities = [
        GameRecord::class, Autosave::class,
        com.chesslab.training.OpeningProgress::class, com.chesslab.training.OpeningReviewLog::class,
        com.chesslab.puzzles.OwnPuzzle::class, com.chesslab.puzzles.PuzzleProgress::class,
    ],
    version = 6, exportSchema = false,
)
abstract class LibraryDatabase : RoomDatabase() {
    abstract fun games(): GameDao
    abstract fun autosaves(): AutosaveDao
    abstract fun training(): com.chesslab.training.TrainingDao
    abstract fun ownPuzzles(): com.chesslab.puzzles.OwnPuzzleDao
    abstract fun puzzleProgress(): com.chesslab.puzzles.PuzzleProgressDao

    companion object {
        @Volatile private var instance: LibraryDatabase? = null

        /**
         * v3 → v4 : des identifiants STABLES pour le journal et les parties.
         *
         * C'est la migration qui rend le transfert entre appareils possible :
         * un compteur auto-incrémenté est local, un UUID ne l'est pas. Les
         * lignes existantes reçoivent le leur ici — sans quoi le premier
         * export d'une base déjà remplie sortirait des entrées sans identité,
         * que l'autre appareil ne saurait pas dédoublonner.
         *
         * Écrite À LA MAIN plutôt que laissée au filet destructeur : une
         * progression FSRS ne se reconstruit pas.
         */
        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE games ADD COLUMN uid TEXT NOT NULL DEFAULT ''")
                db.execSQL("UPDATE games SET uid = lower(hex(randomblob(16))) WHERE uid = ''")

                // Le journal change de CLÉ PRIMAIRE : SQLite ne sait pas le
                // faire en place, on recrée la table et on recopie.
                db.execSQL(
                    """
                    CREATE TABLE opening_review_log_new (
                        uid TEXT NOT NULL PRIMARY KEY,
                        fen_key TEXT NOT NULL,
                        rating_raw INTEGER NOT NULL,
                        reviewed_at INTEGER NOT NULL,
                        elapsed_days REAL NOT NULL,
                        scheduled_days REAL NOT NULL,
                        stability_after REAL NOT NULL
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    INSERT INTO opening_review_log_new
                        (uid, fen_key, rating_raw, reviewed_at, elapsed_days, scheduled_days, stability_after)
                    SELECT lower(hex(randomblob(16))), fen_key, rating_raw, reviewed_at,
                           elapsed_days, scheduled_days, stability_after
                    FROM opening_review_log
                    """.trimIndent()
                )
                db.execSQL("DROP TABLE opening_review_log")
                db.execSQL("ALTER TABLE opening_review_log_new RENAME TO opening_review_log")
            }
        }

        /**
         * v4 → v5 : les puzzles tirés de vos propres parties.
         *
         * Table NEUVE, donc rien à convertir — mais elle est écrite à la main
         * comme les autres : le filet destructeur effacerait la progression
         * FSRS pour un simple ajout de table.
         */
        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS own_puzzles (
                        uid TEXT NOT NULL PRIMARY KEY,
                        fen TEXT NOT NULL,
                        playedSan TEXT NOT NULL,
                        solution TEXT NOT NULL,
                        theme TEXT NOT NULL,
                        rating INTEGER NOT NULL,
                        createdAt INTEGER NOT NULL,
                        sourcePgn TEXT NOT NULL
                    )
                    """.trimIndent()
                )
            }
        }

        /**
         * v5 → v6 : la progression par puzzle. Table neuve, écrite à la main
         * comme les autres — le filet destructeur effacerait la progression
         * FSRS pour un simple ajout de table.
         */
        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS puzzle_progress (
                        externalId TEXT NOT NULL PRIMARY KEY,
                        successCount INTEGER NOT NULL,
                        failureCount INTEGER NOT NULL,
                        easinessFactor REAL NOT NULL,
                        intervalDays INTEGER NOT NULL,
                        repetitions INTEGER NOT NULL,
                        dueAt INTEGER,
                        updatedAt INTEGER NOT NULL,
                        theme TEXT NOT NULL
                    )
                    """.trimIndent()
                )
            }
        }

        fun get(context: Context): LibraryDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext, LibraryDatabase::class.java, "chesslab.db",
            )
                .addMigrations(MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
                // Le filet, et RIEN DE PLUS : chaque changement de schéma doit
                // fournir sa migration, comme ci-dessus. Il reste là pour
                // qu'une base corrompue n'empêche pas l'app de démarrer, jamais
                // pour éviter d'écrire une migration — une progression FSRS ne
                // se reconstruit pas.
                .fallbackToDestructiveMigration()
                .build().also { instance = it }
        }
    }
}
