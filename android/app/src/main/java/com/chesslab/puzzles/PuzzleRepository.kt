package com.chesslab.puzzles

import android.content.res.AssetManager
import android.util.JsonReader
import kotlin.random.Random
import androidx.annotation.StringRes
import com.chesslab.R

/** Un puzzle de la bibliothèque Lichess embarquée. */
data class Puzzle(
    val id: String,
    val fen: String,
    val solution: List<String>,
    val theme: String,
    val rating: Int,
    val phase: String?,
    /**
     * Le PGN de la partie D'OÙ vient le puzzle, pour les puzzles maison :
     * revoir la faute dans son contexte vaut mieux que la revoir seule.
     * `null` pour les 106 094 puzzles de Lichess, qui n'ont pas de partie.
     */
    val sourcePgn: String? = null,
) {
    /** Le thème en toutes lettres. Repris de `PuzzleTheme.label`. */
    @get:StringRes
    val themeLabel: Int
        get() = when (theme) {
            "checkmate" -> R.string.theme_mate
            "hangingPiece" -> R.string.theme_hanging
            "fork" -> R.string.theme_fork
            "pin" -> R.string.theme_pin
            "skewer" -> R.string.theme_skewer
            "discoveredAttack" -> R.string.theme_discovered
            "sacrifice" -> R.string.theme_sacrifice
            else -> R.string.theme_tactic
        }
}

/**
 * Lit la bibliothèque de puzzles.
 *
 * **Pourquoi en flux et non d'un bloc.** L'app iOS décode les 106 094 entrées
 * en mémoire d'un coup ; sur un téléphone d'entrée de gamme, ce serait des
 * dizaines de mégaoctets d'objets pour n'en montrer que quelques-uns. On lit
 * donc le fichier en flux et on n'en retient qu'un échantillon, par
 * échantillonnage « de réservoir » : une seule passe, mémoire constante, et un
 * tirage réellement uniforme sur tout le corpus.
 */
object PuzzleRepository {

    private const val ASSET = "lichess_puzzles.json"

    fun sample(
        assets: AssetManager,
        count: Int,
        ratings: IntRange = 0..4000,
        /** `null` = tous les thèmes. */
        theme: String? = null,
        /** `null` = toutes les phases. */
        phase: String? = null,
        /** Des puzzles déjà filtrés à verser au même tirage (vos puzzles maison). */
        extra: List<Puzzle> = emptyList(),
        random: Random = Random.Default,
    ): List<Puzzle> {
        val kept = ArrayList<Puzzle>(count)
        var seen = 0

        assets.open(ASSET).reader().use { stream ->
            JsonReader(stream).use { json ->
                json.beginArray()
                while (json.hasNext()) {
                    val puzzle = readPuzzle(json) ?: continue
                    if (puzzle.rating !in ratings) continue
                    if (theme != null && puzzle.theme != theme) continue
                    if (phase != null && puzzle.phase != phase) continue

                    seen++
                    if (kept.size < count) {
                        kept += puzzle
                    } else {
                        val slot = random.nextInt(seen)
                        if (slot < count) kept[slot] = puzzle
                    }
                }
                json.endArray()
            }
        }
        // Les puzzles maison entrent au MÊME tirage que la bibliothèque, et
        // non en tête : « Toutes » tire uniformément dans l'ensemble, comme
        // iOS — un choix explicite « Mes parties » existe pour les retrouver.
        for (puzzle in extra) {
            seen++
            if (kept.size < count) {
                kept += puzzle
            } else {
                val slot = random.nextInt(seen)
                if (slot < count) kept[slot] = puzzle
            }
        }
        return kept.sortedBy { it.rating }
    }

    /** Les puzzles de la bibliothèque dont l'identifiant est demandé, en une passe. */
    fun byIds(assets: AssetManager, ids: Set<String>): List<Puzzle> {
        if (ids.isEmpty()) return emptyList()
        val found = ArrayList<Puzzle>(ids.size)
        assets.open(ASSET).reader().use { stream ->
            JsonReader(stream).use { json ->
                json.beginArray()
                while (json.hasNext()) {
                    val puzzle = readPuzzle(json) ?: continue
                    if (puzzle.id in ids) found += puzzle
                }
                json.endArray()
            }
        }
        return found
    }

    private fun readPuzzle(json: JsonReader): Puzzle? {
        var id = ""; var fen = ""; var theme = ""; var rating = 0
        var phase: String? = null
        val solution = mutableListOf<String>()

        json.beginObject()
        while (json.hasNext()) {
            when (json.nextName()) {
                "id" -> id = json.nextString()
                "fen" -> fen = json.nextString()
                "theme" -> theme = json.nextString()
                "rating" -> rating = json.nextInt()
                "phase" -> phase = json.nextString()
                "solutionLANs" -> {
                    json.beginArray()
                    while (json.hasNext()) solution += json.nextString()
                    json.endArray()
                }
                else -> json.skipValue()
            }
        }
        json.endObject()

        if (fen.isEmpty() || solution.isEmpty()) return null
        return Puzzle(id, fen, solution, theme, rating, phase)
    }
}
