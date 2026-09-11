package com.chesslab.courses

import android.content.res.AssetManager
import org.json.JSONArray
import org.json.JSONObject

/** Une entrée du catalogue : de quoi dresser la liste sans ouvrir les cours. */
data class CatalogEntry(
    val id: String,
    val name: String,
    val eco: List<String>,
    val side: String,
    val level: String,
    val summary: String,
    val positionCount: Int,
    val isEndgame: Boolean,
    val family: String?,
) {
    val sideLabel: String get() = if (side == "white") "Blancs" else "Noirs"
    val levelLabel: String get() = if (level == "advanced") "Avancé" else "Club"
}

/** Un coup possible depuis une position du cours. */
data class CourseMove(
    val san: String,
    val uci: String,
    val toFEN: String,
    val role: String,
    val comment: String?,
    val eval: Double?,
    val popularity: Double?,
) {
    val isMainLine: Boolean get() = role == "mainLine"
}

data class Chapter(val id: String, val title: String, val positionFENs: List<String>)

data class Course(
    val id: String,
    val name: String,
    val summary: String,
    val rootFEN: String,
    val chapters: List<Chapter>,
    val positions: Map<String, List<CourseMove>>,
)

/**
 * Les cours d'ouvertures et de finales, lus depuis les assets.
 *
 * Le catalogue (`opening_catalog.json`) suffit à dresser la liste : inutile
 * d'ouvrir les 136 fichiers pour afficher 136 lignes. Un cours n'est chargé
 * qu'à son ouverture.
 *
 * Les positions sont indexées par une FEN à QUATRE champs — placement, trait,
 * roques, prise en passant — sans les pendules, qui ne changent pas la
 * position. Voir [fenKey].
 */
object CourseRepository {

    private const val DIR = "openings"
    private var catalog: List<CatalogEntry>? = null
    private val cache = LinkedHashMap<String, Course>()

    /** La clé d'indexation : les quatre premiers champs d'une FEN. */
    fun fenKey(fen: String): String = fen.trim().split(" ").take(4).joinToString(" ")

    fun catalog(assets: AssetManager): List<CatalogEntry> {
        catalog?.let { return it }
        val text = assets.open("$DIR/opening_catalog.json").bufferedReader().use { it.readText() }
        val array = JSONArray(text)
        val out = ArrayList<CatalogEntry>(array.length())
        for (i in 0 until array.length()) {
            val o = array.getJSONObject(i)
            out += CatalogEntry(
                id = o.getString("id"),
                name = o.getString("name"),
                eco = o.optJSONArray("eco")?.let { e -> (0 until e.length()).map { e.getString(it) } } ?: emptyList(),
                side = o.optString("side", "white"),
                level = o.optString("level", "club"),
                summary = o.optJSONObject("summary")?.optString("fr") ?: "",
                positionCount = o.optInt("positionCount", 0),
                isEndgame = o.optString("kind") == "endgame",
                family = o.optString("family").ifEmpty { null },
            )
        }
        catalog = out
        return out
    }

    /** Le nom d'un cours si le catalogue est déjà lu — pour titrer l'écran. */
    fun cachedName(id: String): String? = catalog?.firstOrNull { it.id == id }?.name

    fun course(assets: AssetManager, id: String): Course? {
        cache[id]?.let { return it }
        val text = runCatching {
            assets.open("$DIR/$id.json").bufferedReader().use { it.readText() }
        }.getOrNull() ?: return null

        val o = JSONObject(text)

        val chapters = o.optJSONArray("chapters")?.let { array ->
            (0 until array.length()).map { i ->
                val c = array.getJSONObject(i)
                val fens = c.getJSONArray("positionFENs")
                Chapter(
                    id = c.optString("id", "ch$i"),
                    title = c.optJSONObject("title")?.optString("fr") ?: c.optString("id", "Chapitre ${i + 1}"),
                    positionFENs = (0 until fens.length()).map { fens.getString(it) },
                )
            }
        } ?: emptyList()

        val positions = HashMap<String, List<CourseMove>>()
        o.optJSONObject("positions")?.let { all ->
            for (key in all.keys()) {
                val moves = all.getJSONObject(key).optJSONArray("moves") ?: continue
                positions[fenKey(key)] = (0 until moves.length()).map { i ->
                    val m = moves.getJSONObject(i)
                    CourseMove(
                        san = m.optString("san"),
                        uci = m.optString("uci"),
                        toFEN = m.optString("toFEN"),
                        role = m.optString("role", "sideline"),
                        comment = m.optJSONObject("comment")?.optString("fr")?.ifEmpty { null },
                        eval = if (m.has("eval")) m.getDouble("eval") else null,
                        popularity = if (m.has("popularityClub")) m.getDouble("popularityClub") else null,
                    )
                }
            }
        }

        val course = Course(
            id = o.getString("id"),
            name = o.getString("name"),
            summary = o.optJSONObject("summary")?.optString("fr") ?: "",
            rootFEN = o.optString("rootFEN"),
            chapters = chapters,
            positions = positions,
        )
        if (cache.size > 3) cache.remove(cache.keys.first())   // quelques cours suffisent en mémoire
        cache[id] = course
        return course
    }
}
