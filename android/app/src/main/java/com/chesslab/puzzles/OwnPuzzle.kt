package com.chesslab.puzzles

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query

/**
 * Un puzzle tiré d'UNE DE VOS PARTIES : la position d'avant une faute, et le
 * coup qu'il fallait jouer. Pendant du `Puzzle` iOS de source `ownGames`.
 *
 * Ce sont les puzzles qui valent le plus : la position est déjà arrivée sur
 * votre échiquier, et l'erreur est la vôtre. La bibliothèque Lichess, elle,
 * propose des positions d'inconnus.
 */
@Entity(tableName = "own_puzzles")
data class OwnPuzzle(
    @PrimaryKey val uid: String,
    val fen: String,
    /** Le coup réellement joué, en SAN : ce qu'il ne fallait pas faire. */
    val playedSan: String,
    /** La solution, en LAN, séparée par des espaces. */
    val solution: String,
    val theme: String,
    val rating: Int,
    val createdAt: Long,
    /** Le PGN de la partie d'où il sort, pour pouvoir y retourner. */
    val sourcePgn: String,
) {
    /** Vers la forme que l'écran de résolution sait déjà jouer. */
    fun toPuzzle(): Puzzle = Puzzle(
        id = uid,
        fen = fen,
        solution = solution.split(" ").filter { it.isNotEmpty() },
        theme = theme,
        rating = rating,
        phase = null,
    )
}

@Dao
interface OwnPuzzleDao {
    @Query("SELECT * FROM own_puzzles ORDER BY createdAt DESC")
    suspend fun all(): List<OwnPuzzle>

    @Query("SELECT COUNT(*) FROM own_puzzles")
    suspend fun count(): Int

    /** La même position ne donne qu'un puzzle : deux revues d'une partie ne doivent pas la doubler. */
    @Query("SELECT COUNT(*) FROM own_puzzles WHERE fen = :fen")
    suspend fun countFor(fen: String): Int

    @Insert
    suspend fun insert(puzzle: OwnPuzzle)

    @Query("DELETE FROM own_puzzles")
    suspend fun clear()
}
