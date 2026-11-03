package com.chesslab.puzzles

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query

/**
 * Un puzzle d'une COLLECTION importée d'un fichier PGN (voir
 * [PuzzleCollectionImporter]). Pendant du `Puzzle` iOS de source `imported`.
 *
 * Une collection n'a pas de ligne à elle : c'est l'ensemble des puzzles qui
 * portent son nom. Renommer réécrit ce champ, supprimer retire les puzzles.
 *
 * Table à part de [OwnPuzzle] : ces puzzles ne viennent pas de vos parties, et
 * restent HORS du tirage général (série ordinaire, « Ratés », séance du jour,
 * statistiques) — voir [PuzzleDraw]. Leur progression partage la table
 * `puzzle_progress`, sous un identifiant préfixé [ID_PREFIX] que les requêtes
 * générales écartent.
 */
@Entity(tableName = "imported_puzzles", indices = [Index("collection")])
data class ImportedPuzzle(
    @PrimaryKey val uid: String,
    val collection: String,
    val fen: String,
    /** La solution, en LAN, séparée par des espaces. */
    val solution: String,
    val theme: String,
    val phase: String,
    /** Le rang dans le fichier : l'ordre d'origine se garde. */
    val position: Int,
    val createdAt: Long,
) {
    fun toPuzzle(): Puzzle = Puzzle(
        id = uid,
        fen = fen,
        solution = solution.split(" ").filter { it.isNotEmpty() },
        theme = theme,
        // Sans cote : 0, comme un puzzle maison.
        rating = 0,
        phase = phase,
    )

    companion object {
        /** Préfixe de l'identifiant (et donc de la progression) : « imp-… ». */
        const val ID_PREFIX = "imp-"

        fun isImportedId(id: String) = id.startsWith(ID_PREFIX)
    }
}

/** Une collection et son compte, pour la liste. */
data class CollectionSummary(
    val name: String,
    val count: Int,
    /** Ceux dont la DERNIÈRE tentative est ratée. */
    val missedCount: Int = 0,
)

@Dao
interface ImportedPuzzleDao {
    @Query("SELECT * FROM imported_puzzles WHERE collection = :collection ORDER BY position ASC")
    suspend fun inCollection(collection: String): List<ImportedPuzzle>

    @Query("SELECT * FROM imported_puzzles ORDER BY collection ASC, position ASC")
    suspend fun all(): List<ImportedPuzzle>

    @Query("SELECT fen FROM imported_puzzles WHERE collection = :collection")
    suspend fun fensIn(collection: String): List<String>

    @Query("SELECT collection AS name, COUNT(*) AS count FROM imported_puzzles GROUP BY collection")
    suspend fun counts(): List<NameCount>

    @Query("SELECT COUNT(*) FROM imported_puzzles WHERE collection = :collection")
    suspend fun countIn(collection: String): Int

    @Query("SELECT COALESCE(MAX(position), -1) FROM imported_puzzles WHERE collection = :collection")
    suspend fun lastPosition(collection: String): Int

    @Insert
    suspend fun insertAll(puzzles: List<ImportedPuzzle>)

    @Query("UPDATE imported_puzzles SET collection = :to WHERE collection = :from")
    suspend fun rename(from: String, to: String)

    @Query("DELETE FROM imported_puzzles WHERE collection = :collection")
    suspend fun delete(collection: String)

    /** La progression des puzzles d'une collection : à retirer AVANT les puzzles qui la désignent. */
    @Query("DELETE FROM puzzle_progress WHERE externalId IN (SELECT uid FROM imported_puzzles WHERE collection = :collection)")
    suspend fun deleteProgress(collection: String)

    @Query("SELECT uid FROM imported_puzzles WHERE collection = :collection")
    suspend fun idsIn(collection: String): List<String>

    data class NameCount(val name: String, val count: Int)
}

/**
 * Les collections importées : créer depuis un fichier lu, lister, renommer,
 * supprimer. Pendant de `PuzzleCollectionStore.swift`.
 *
 * Local à l'appareil, comme sur iOS : ni le `.clab` ni rien d'autre ne les
 * emporte. Le fichier d'origine reste la sauvegarde, et réimporter un fichier
 * déjà importé n'ajoute que ce qui manque.
 */
object PuzzleCollectionStore {

    data class ImportReport(
        val collection: String,
        val added: Int,
        /** Déjà dans la collection (même position) : un fichier réimporté. */
        val alreadyThere: Int,
        val parsed: PuzzleCollectionImporter.Result,
    )

    /**
     * Verse les puzzles lus dans la collection [name] (créée au besoin). Une
     * position déjà présente n'est pas ajoutée deux fois : réimporter la version
     * à jour d'un fichier complète la collection sans rien dédoubler.
     */
    suspend fun add(
        dao: ImportedPuzzleDao,
        parsed: PuzzleCollectionImporter.Result,
        collection: String,
        now: Long = System.currentTimeMillis(),
    ): ImportReport {
        val name = normalized(collection)
        val known = dao.fensIn(name).toHashSet()
        var next = dao.lastPosition(name) + 1
        var already = 0
        val fresh = ArrayList<ImportedPuzzle>()
        for (item in parsed.puzzles) {
            if (!known.add(item.fen)) {
                already++
                continue
            }
            fresh += ImportedPuzzle(
                uid = ImportedPuzzle.ID_PREFIX + java.util.UUID.randomUUID(),
                collection = name,
                fen = item.fen,
                solution = item.solution.joinToString(" "),
                theme = item.theme,
                phase = item.phase,
                position = next++,
                createdAt = now,
            )
        }
        if (fresh.isNotEmpty()) dao.insertAll(fresh)
        return ImportReport(name, fresh.size, already, parsed)
    }

    /** Le nom proposé pour un fichier : son nom sans l'extension. */
    fun suggestedName(fileName: String, fallback: String): String {
        val name = normalized(fileName.substringBeforeLast('.', fileName))
        return name.ifEmpty { fallback }
    }

    fun normalized(name: String): String = name.trim()

    /**
     * Ordre « naturel », comme le `localizedStandardCompare` d'iOS : la casse ne compte pas
     * et les nombres se comparent comme des nombres (« Mats 2 » avant « Mats 10 »).
     */
    fun naturalCompare(a: String, b: String): Int {
        val chunk = Regex("""\d+|\D+""")
        val left = chunk.findAll(a).map { it.value }.toList()
        val right = chunk.findAll(b).map { it.value }.toList()
        for (i in 0 until minOf(left.size, right.size)) {
            val x = left[i]
            val y = right[i]
            val order = if (x[0].isDigit() && y[0].isDigit()) {
                val px = x.trimStart('0')
                val py = y.trimStart('0')
                if (px.length != py.length) px.length.compareTo(py.length) else px.compareTo(py)
            } else {
                x.compareTo(y, ignoreCase = true)
            }
            if (order != 0) return order
        }
        val bySize = left.size.compareTo(right.size)
        return if (bySize != 0) bySize else a.compareTo(b)
    }

    /** Les collections dans cet ordre, avec leurs ratés. */
    suspend fun collections(dao: ImportedPuzzleDao, missedIds: Set<String>): List<CollectionSummary> =
        dao.counts()
            .sortedWith { a, b -> naturalCompare(a.name, b.name) }
            .map { entry ->
                val missed = if (missedIds.isEmpty()) 0 else dao.idsIn(entry.name).count { it in missedIds }
                CollectionSummary(entry.name, entry.count, missed)
            }

    /** Retire la collection, ses puzzles ET leur progression. */
    suspend fun delete(dao: ImportedPuzzleDao, collection: String) {
        dao.deleteProgress(collection)
        dao.delete(collection)
    }

    /**
     * `false` si le nouveau nom est vide ou déjà pris par une AUTRE collection
     * (les fusionner en silence mélangerait deux fichiers).
     */
    suspend fun rename(dao: ImportedPuzzleDao, old: String, new: String): Boolean {
        val name = normalized(new)
        if (name.isEmpty()) return false
        if (name == old) return true
        if (dao.countIn(name) > 0) return false
        dao.rename(old, name)
        return true
    }
}
