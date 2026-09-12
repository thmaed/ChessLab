package com.chesslab.courses

import android.content.res.AssetManager
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import org.json.JSONArray
import org.json.JSONObject
import androidx.annotation.StringRes
import com.chesslab.R

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
    /** Profondeur maximale de l'arbre, en demi-coups. */
    val maxDepth: Int?,
) {
    @get:StringRes
    val sideLabel: Int get() = if (side == "white") R.string.color_white else R.string.color_black

    @get:StringRes
    val levelLabel: Int get() = if (level == "advanced") R.string.level_advanced else R.string.level_club
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
    /** Le camp que l'on joue : « white » ou « black ». */
    val side: String,
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
    private var catalogLanguage: String? = null
    private val cache = LinkedHashMap<String, Course>()

    /**
     * La langue dans laquelle lire les cours.
     *
     * Les fichiers portent `{"fr": …, "en": …}` pour chaque texte. Tant qu'on
     * ne lisait que `fr`, une app en anglais montrait des commentaires en
     * français : le décor traduit et le contenu non, ce qui est pire que rien.
     */
    private fun language(): String =
        if (java.util.Locale.getDefault().language == "fr") "fr" else "en"

    /** Le texte dans la langue courante, avec repli sur le français. */
    private fun localized(o: JSONObject?): String? {
        if (o == null) return null
        val value = o.optString(language()).ifEmpty { o.optString("fr") }
        return value.ifEmpty { null }
    }

    /** La clé d'indexation : les quatre premiers champs d'une FEN. */
    fun fenKey(fen: String): String = fen.trim().split(" ").take(4).joinToString(" ")

    /**
     * La position décrite par une FEN de cours — de QUATRE à six champs.
     *
     * Les fichiers de cours portent des FEN à quatre champs : c'est la clé du
     * graphe (voir [fenKey]), les pendules n'y ont pas leur place. `FenParser`,
     * lui, en exige six. Sans ce complément, toute finale s'ouvrait sur la
     * POSITION DE DÉPART — et comme les 59 ouvertures commencent justement au
     * début, le repli habituel `?: Position.standard` donnait par accident la
     * bonne réponse et masquait le défaut sur les 78 finales.
     *
     * Rend `null` sur une FEN qui ne décrit pas une vraie position : le parseur
     * est très permissif (six jetons quelconques lui font un échiquier vide),
     * on exige donc la présence des DEUX rois. Pendant d'`OpeningFENKey.position(from:)`.
     */
    fun position(fen: String): Position? {
        val trimmed = fen.trim()
        val padded = when (trimmed.split(" ").filter { it.isNotEmpty() }.size) {
            4 -> "$trimmed 0 1"
            5 -> "$trimmed 1"
            else -> trimmed
        }
        val position = FenParser.parse(padded) ?: return null
        val kings = position.pieces.filter { it.kind == Piece.Kind.king }
        val bothKings = kings.any { it.color == Piece.Color.white } &&
            kings.any { it.color == Piece.Color.black }
        return position.takeIf { bothKings }
    }

    fun catalog(assets: AssetManager): List<CatalogEntry> {
        // Le catalogue est mémorisé, mais la langue peut avoir changé entre
        // deux ouvertures de l'app : on le relit alors.
        if (catalogLanguage == language()) catalog?.let { return it }
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
                summary = localized(o.optJSONObject("summary")) ?: "",
                positionCount = o.optInt("positionCount", 0),
                isEndgame = o.optString("kind") == "endgame",
                maxDepth = if (o.has("maxDepth")) o.getInt("maxDepth") else null,
                family = o.optString("family").ifEmpty { null },
            )
        }
        catalog = out
        catalogLanguage = language()
        cache.clear()
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
                    title = localized(c.optJSONObject("title")) ?: c.optString("id", ""),
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
                        comment = localized(m.optJSONObject("comment")),
                        eval = if (m.has("eval")) m.getDouble("eval") else null,
                        popularity = if (m.has("popularityClub")) m.getDouble("popularityClub") else null,
                    )
                }
            }
        }

        val course = Course(
            id = o.getString("id"),
            name = o.getString("name"),
            summary = localized(o.optJSONObject("summary")) ?: "",
            side = o.optString("side", "white"),
            rootFEN = o.optString("rootFEN"),
            chapters = chapters,
            positions = positions,
        )
        if (cache.size > 3) cache.remove(cache.keys.first())   // quelques cours suffisent en mémoire
        cache[id] = course
        return course
    }
}
