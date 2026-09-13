package com.chesslab.courses

import android.content.res.AssetManager
import chesskit.Board
import chesskit.FenParser
import chesskit.Piece
import chesskit.Position
import chesskit.Square
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
    /**
     * Le commentaire, seulement s'il est VALIDÉ. Un brouillon (`draft`) reste
     * dans le fichier sans jamais s'afficher — c'est la règle d'iOS
     * (`MoveEdge.displayableComment`), et elle protège l'utilisateur d'un
     * texte que personne n'a relu.
     */
    val comment: String?,
    val eval: Double?,
    val popularity: Double?,
    /** Le coup critique de sa position, aux yeux de l'auteur. */
    val isCritical: Boolean = false,
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
    /**
     * Le nom de variante d'une position (« Italian Game: Giuoco Piano »),
     * indexé par clé FEN — 113 positions en portent un sur le catalogue. C'est
     * le sous-titre du lecteur, et le nom que l'index donne à une branche.
     */
    val ecoNames: Map<String, String> = emptyMap(),
) {
    /** Les coups jouables depuis une clé FEN, ou rien. */
    fun moves(key: String): List<CourseMove> = positions[key].orEmpty()
}

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
     * La clé CANONIQUE d'une position vivante. Pendant d'`OpeningFENKey.key(for:)`.
     *
     * [fenKey] suffit pour une FEN qui vient d'un FICHIER : le générateur
     * l'a déjà canonisée. Une position qu'on vient de JOUER, non — ChessKit
     * émet la case « en passant » après tout double pas, qu'un preneur existe
     * ou non, et garde un droit de roque quand la tour concernée est capturée
     * sur sa case. Deux chemins vers la même position donneraient alors deux
     * clés, et la transposition ne fusionnerait pas. Sémantique alignée sur
     * `python-chess`, côté générateur, pour que les clés coïncident.
     */
    fun key(position: Position): String {
        val fields = position.fen.split(" ")
        if (fields.size < 4) return position.fen
        return "${fields[0]} ${fields[1]} ${canonicalCastling(fields[2], position)} ${canonicalEnPassant(fields[3], position)}"
    }

    /**
     * On ne garde un droit de roque que si le roi ET la tour concernés sont
     * TOUJOURS sur leur case d'origine. On ne fait que RETIRER un droit
     * fantôme, jamais en accorder un : le filtre est borné par le champ de
     * ChessKit, qui retire bien les droits quand roi ou tour se déplacent.
     */
    private fun canonicalCastling(field: String, position: Position): String {
        if (field == "-") return "-"
        fun present(kind: Piece.Kind, color: Piece.Color, at: String): Boolean {
            val piece = position.piece(Square(at)) ?: return false
            return piece.kind == kind && piece.color == color
        }
        val whiteKingHome = present(Piece.Kind.king, Piece.Color.white, "e1")
        val blackKingHome = present(Piece.Kind.king, Piece.Color.black, "e8")
        val out = StringBuilder()
        if ('K' in field && whiteKingHome && present(Piece.Kind.rook, Piece.Color.white, "h1")) out.append('K')
        if ('Q' in field && whiteKingHome && present(Piece.Kind.rook, Piece.Color.white, "a1")) out.append('Q')
        if ('k' in field && blackKingHome && present(Piece.Kind.rook, Piece.Color.black, "h8")) out.append('k')
        if ('q' in field && blackKingHome && present(Piece.Kind.rook, Piece.Color.black, "a8")) out.append('q')
        return out.toString().ifEmpty { "-" }
    }

    /**
     * La case « en passant » n'est gardée que si une prise y est réellement
     * légale : case VIDE (le pion preneur s'y déplace) et un pion du camp au
     * trait sur une AUTRE colonne qui peut l'atteindre — un pion n'y arrive
     * que par une prise diagonale. Sans ces gardes, une case périmée pointant
     * sur une case occupée (juste après une prise e.p.) ferait passer une
     * prise normale pour une prise en passant.
     */
    private fun canonicalEnPassant(field: String, position: Position): String {
        if (field == "-" || field.length != 2) return "-"
        val target = Square(field)
        if (position.piece(target) != null) return "-"
        val board = Board(position)
        val mover = position.sideToMove
        val legal = position.pieces.any { piece ->
            piece.color == mover && piece.kind == Piece.Kind.pawn && piece.square.file != target.file &&
                target in board.legalMoves(piece.square)
        }
        return if (legal) field else "-"
    }

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
        val course = parse(text)
        if (cache.size > 3) cache.remove(cache.keys.first())   // quelques cours suffisent en mémoire
        cache[id] = course
        return course
    }

    /** Lit un cours depuis son texte JSON — l'entrée des tests, qui n'ont pas d'assets. */
    fun parse(text: String): Course {
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
        val ecoNames = HashMap<String, String>()
        o.optJSONObject("positions")?.let { all ->
            for (key in all.keys()) {
                val node = all.getJSONObject(key)
                node.optString("ecoName").ifEmpty { null }?.let { ecoNames[fenKey(key)] = it }
                val moves = node.optJSONArray("moves") ?: continue
                positions[fenKey(key)] = (0 until moves.length()).map { i ->
                    val m = moves.getJSONObject(i)
                    CourseMove(
                        san = m.optString("san"),
                        uci = m.optString("uci"),
                        toFEN = m.optString("toFEN"),
                        role = m.optString("role", "sideline"),
                        // Un commentaire sans statut « validated » n'existe
                        // pas pour l'écran : même règle qu'iOS.
                        comment = if (m.optString("commentStatus") == "validated")
                            localized(m.optJSONObject("comment")) else null,
                        eval = if (m.has("eval")) m.getDouble("eval") else null,
                        popularity = if (m.has("popularityClub")) m.getDouble("popularityClub") else null,
                        isCritical = m.optBoolean("isCritical", false),
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
            ecoNames = ecoNames,
        )
        return course
    }
}
