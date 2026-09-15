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
    /** Le personnage affronté, ou `null` pour Stockfish et pour toute partie antérieure. */
    @ColumnInfo(name = "opponent_id") val opponentId: String? = null,
    /** Le niveau approximatif de l'adversaire, en Elo — ce qui fait la progression « par niveau ». */
    @ColumnInfo(name = "engine_elo") val engineElo: Int? = null,
    /**
     * La couleur du moteur, « white » ou « black » ; `null` pour deux humains.
     * Champ SÉMANTIQUE : la couleur du joueur s'en déduit, là où le nom
     * « Vous » est traduit et ne peut plus servir de repère.
     */
    @ColumnInfo(name = "engine_color") val engineColor: String? = null,
    /**
     * Les étiquettes libres posées par l'utilisateur, en une seule chaîne
     * séparée par des virgules (« ouverture,à revoir »). Une chaîne plutôt
     * qu'une table : on ne cherche jamais « toutes les parties d'une
     * étiquette » ailleurs que dans cette liste, et une table de jointure
     * coûterait une migration pour rien.
     */
    val tags: String? = null,
    /**
     * L'empreinte canonique de la partie — position de départ et suite des
     * coups. C'est le SEUL lien entre une session d'analyse et la partie
     * enregistrée : l'écran d'analyse ne reçoit qu'un texte PGN, jamais une
     * identité. La clé porte la partie JOUÉE et non sa mise en forme, si bien
     * que deux PGN aux en-têtes différents se retrouvent.
     */
    @ColumnInfo(name = "analysis_key") val analysisKey: String? = null,
    /**
     * La version du BARÈME ayant produit les chiffres ci-dessous. Ne JAMAIS
     * moyenner des parties de versions différentes : sans ce numéro, une
     * moyenne mélangerait des mesures faites à des aunes différentes, et
     * personne ne le verrait.
     */
    @ColumnInfo(name = "analysis_version") val analysisVersion: Int? = null,
    @ColumnInfo(name = "white_accuracy") val whiteAccuracy: Double? = null,
    @ColumnInfo(name = "black_accuracy") val blackAccuracy: Double? = null,
    /** Perte moyenne de probabilité de gain, hors théorie, non pondérée. */
    @ColumnInfo(name = "white_average_loss") val whiteAverageLoss: Double? = null,
    @ColumnInfo(name = "black_average_loss") val blackAverageLoss: Double? = null,
    /** Coups pris en compte, hors théorie. */
    @ColumnInfo(name = "white_classified") val whiteClassified: Int? = null,
    @ColumnInfo(name = "black_classified") val blackClassified: Int? = null,
    /** Coups de théorie reconnus, par camp. */
    @ColumnInfo(name = "white_book") val whiteBook: Int? = null,
    @ColumnInfo(name = "black_book") val blackBook: Int? = null,
) {
    /** Les étiquettes, découpées et nettoyées. */
    val tagList: List<String>
        get() = tags?.split(",")?.map { it.trim() }?.filter { it.isNotEmpty() }.orEmpty()
}

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

    @Query("DELETE FROM games WHERE id IN (:ids)")
    suspend fun deleteAll(ids: List<Long>)

    @Query("UPDATE games SET tags = :tags WHERE id = :id")
    suspend fun setTags(id: Long, tags: String?)

    /** Le bilan chiffré d'une partie analysée, rangé pour être relu tel quel. */
    @Query(
        """UPDATE games SET analysis_key = :key, analysis_version = :version,
           white_accuracy = :whiteAccuracy, black_accuracy = :blackAccuracy,
           white_average_loss = :whiteLoss, black_average_loss = :blackLoss,
           white_classified = :whiteClassified, black_classified = :blackClassified,
           white_book = :whiteBook, black_book = :blackBook
           WHERE id = :id"""
    )
    suspend fun setMetrics(
        id: Long, key: String, version: Int,
        whiteAccuracy: Double?, blackAccuracy: Double?,
        whiteLoss: Double?, blackLoss: Double?,
        whiteClassified: Int?, blackClassified: Int?,
        whiteBook: Int?, blackBook: Int?,
    )

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
    /**
     * La position de DÉPART de la partie. Sans elle, une partie commencée sur
     * une position venue d'un autre mode était irrécupérable : on la rejouait
     * depuis l'échiquier initial, et les coups ne collaient plus.
     */
    @ColumnInfo(name = "start_fen") val startFen: String? = null,
    /** Le camp de l'utilisateur, pour le rétablir tel quel (mode Jouer). */
    @ColumnInfo(name = "user_color") val userColor: String? = null,
    /** La cadence, et les deux temps RESTANTS : reprendre à temps plein serait un cadeau. */
    @ColumnInfo(name = "time_control_id") val timeControlId: String? = null,
    @ColumnInfo(name = "white_ms") val whiteMs: Long? = null,
    @ColumnInfo(name = "black_ms") val blackMs: Long? = null,
    /** Les réglages du mode Deux joueurs — les noms, surtout — en JSON. */
    @ColumnInfo(name = "settings_json") val settingsJson: String? = null,
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
    version = 9, exportSchema = false,
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

        /**
         * TOUTES les migrations, en un seul endroit.
         *
         * Le test de migration s'en sert aussi : une liste recopiée à la main
         * dans le test finit par prendre du retard sur la base, et un schéma
         * neuf passe alors par le filet DESTRUCTEUR sans que rien ne l'annonce
         * — c'est arrivé au passage en v6. Ici, oublier une migration fait
         * échouer le test.
         */
        val ALL_MIGRATIONS get() = arrayOf(
            MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8, MIGRATION_8_9,
        )

        /**
         * v8 → v9 : la bibliothèque devient un vrai classeur. Les ÉTIQUETTES
         * posées à la main, et le BILAN CHIFFRÉ d'une partie analysée — écrit
         * une fois la ligne principale entièrement classée, pour que le bilan
         * se rouvre sans tout recalculer et que la mesure du niveau ait une
         * matière.
         *
         * Onze colonnes optionnelles : `NULL` veut dire « pas encore
         * analysée », ce qui est l'état de la plupart des parties.
         */
        val MIGRATION_8_9 = object : Migration(8, 9) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE games ADD COLUMN tags TEXT")
                db.execSQL("ALTER TABLE games ADD COLUMN analysis_key TEXT")
                db.execSQL("ALTER TABLE games ADD COLUMN analysis_version INTEGER")
                db.execSQL("ALTER TABLE games ADD COLUMN white_accuracy REAL")
                db.execSQL("ALTER TABLE games ADD COLUMN black_accuracy REAL")
                db.execSQL("ALTER TABLE games ADD COLUMN white_average_loss REAL")
                db.execSQL("ALTER TABLE games ADD COLUMN black_average_loss REAL")
                db.execSQL("ALTER TABLE games ADD COLUMN white_classified INTEGER")
                db.execSQL("ALTER TABLE games ADD COLUMN black_classified INTEGER")
                db.execSQL("ALTER TABLE games ADD COLUMN white_book INTEGER")
                db.execSQL("ALTER TABLE games ADD COLUMN black_book INTEGER")
            }
        }

        /**
         * Une partie interrompue se reprend TELLE QUELLE : sa position de
         * départ, le camp de l'utilisateur, la cadence et les deux temps
         * restants. Jusqu'ici on reprenait une partie jouée avec les Noirs à
         * trente secondes… avec les Blancs et le temps plein.
         *
         * Sept colonnes optionnelles : les sauvegardes existantes restent
         * lisibles, et repartent simplement sans pendule.
         */
        val MIGRATION_7_8 = object : Migration(7, 8) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE autosaves ADD COLUMN start_fen TEXT")
                db.execSQL("ALTER TABLE autosaves ADD COLUMN user_color TEXT")
                db.execSQL("ALTER TABLE autosaves ADD COLUMN time_control_id TEXT")
                db.execSQL("ALTER TABLE autosaves ADD COLUMN white_ms INTEGER")
                db.execSQL("ALTER TABLE autosaves ADD COLUMN black_ms INTEGER")
                db.execSQL("ALTER TABLE autosaves ADD COLUMN settings_json TEXT")
            }
        }

        /**
         * v6 → v7 : la progression VENTILÉE. La note du puzzle sur sa
         * progression (réussite par palier), et sur une partie le personnage,
         * son niveau et la couleur du moteur (bilan par niveau d'adversaire,
         * par personnage, meilleure victoire). Trois colonnes ajoutées, rien à
         * convertir : les anciennes lignes gardent leurs `NULL` et comptent
         * dans les totaux sans entrer dans les ventilations — comme iOS pour
         * ses enregistrements antérieurs.
         */
        val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE puzzle_progress ADD COLUMN rating INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE games ADD COLUMN opponent_id TEXT")
                db.execSQL("ALTER TABLE games ADD COLUMN engine_elo INTEGER")
                db.execSQL("ALTER TABLE games ADD COLUMN engine_color TEXT")
            }
        }

        fun get(context: Context): LibraryDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext, LibraryDatabase::class.java, "chesslab.db",
            )
                .addMigrations(*ALL_MIGRATIONS)
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
