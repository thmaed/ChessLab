package com.chesslab.courses

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Les répertoires APPORTÉS par l'utilisateur : importés d'un PGN, reçus d'un
 * ami, écrits ailleurs puis versés ici. Pendant d'`UserOpeningStore.swift`.
 *
 * Stockés en JSON dans `files/UserOpenings/`, au format EXACT des cours
 * embarqués. C'est ce qui rend le partage gratuit : un cours est déjà un
 * fichier autonome, l'exporter c'est le donner tel quel, et l'importer c'est
 * le même décodeur qu'au démarrage. Aucun serveur, aucun compte.
 *
 * La PROGRESSION n'est pas ici : elle est indexée par FEN, et un cours importé
 * hérite donc de ce que l'utilisateur sait déjà des positions qu'il contient —
 * y compris apprises dans un cours embarqué.
 *
 * iOS range désormais ces cours dans sa base synchronisée par iCloud ; ici,
 * hors périmètre, le fichier reste la vérité — et le transfert entre appareils
 * Android les emporte comme le reste.
 */
object UserOpeningStore {

    /** Distingue un cours utilisateur d'un cours embarqué d'un coup d'œil. */
    const val PREFIX = "user-"

    fun isUserCourse(id: String): Boolean = id.startsWith(PREFIX)

    fun newIdentifier(): String = PREFIX + UUID.randomUUID().toString().lowercase()

    private var directory: File? = null
    private val cache = HashMap<String, Course>()
    private var entries: List<CatalogEntry> = emptyList()

    /** Change à chaque écriture : les écrans qui l'observent se relisent. */
    private val _version = MutableStateFlow(0)
    val version: StateFlow<Int> get() = _version

    /** À appeler une fois au démarrage : le dossier des répertoires. */
    fun attach(context: Context) {
        directory = File(context.filesDir, "UserOpenings").also { it.mkdirs() }
        reload()
    }

    /** Pour les tests : un dossier quelconque. */
    fun attach(dir: File) {
        directory = dir.also { it.mkdirs() }
        reload()
    }

    fun catalog(): List<CatalogEntry> = entries

    fun course(id: String): Course? {
        cache[id]?.let { return it }
        val file = fileFor(id) ?: return null
        val course = runCatching { CourseRepository.parse(file.readText()) }.getOrNull() ?: return null
        cache[id] = course
        return course
    }

    /** Relit l'index depuis le disque. Un fichier illisible est IGNORÉ, jamais fatal. */
    fun reload() {
        cache.clear()
        val dir = directory
        entries = dir?.listFiles { f -> f.name.endsWith(".json") }.orEmpty()
            .mapNotNull { file ->
                val course = runCatching { CourseRepository.parse(file.readText()) }.getOrNull() ?: return@mapNotNull null
                cache[course.id] = course
                entry(course)
            }
            .sortedBy { it.name.lowercase() }
        _version.value++
    }

    class StoreException(message: String, val issues: List<String> = emptyList()) : Exception(message)

    /**
     * Enregistre un cours. Il passe D'ABORD le même validateur que les cours
     * embarqués : un graphe incohérent ne doit pas pouvoir entrer par la porte
     * utilisateur alors qu'il est interdit par la porte des assets.
     */
    fun save(course: Course): CatalogEntry {
        val issues = OpeningCourseValidator.validate(course)
        if (issues.isNotEmpty()) throw StoreException("invalid", issues.map { it.toString() })
        val file = fileFor(course.id) ?: throw StoreException("no storage")
        runCatching { file.writeText(CourseJson.encode(course)) }
            .getOrElse { throw StoreException(it.message ?: "write failed") }
        cache[course.id] = course
        val entry = entry(course)
        entries = (entries.filterNot { it.id == course.id } + entry).sortedBy { it.name.lowercase() }
        _version.value++
        return entry
    }

    /**
     * Supprime le cours. La PROGRESSION reste : indexée par position, elle
     * resurgit si l'utilisateur réimporte le même répertoire.
     */
    fun delete(id: String) {
        fileFor(id)?.delete()
        cache.remove(id)
        entries = entries.filterNot { it.id == id }
        _version.value++
    }

    /** Le fichier à PARTAGER : le cours tel quel, au format d'échange. */
    fun exportJson(id: String): String? = course(id)?.let { CourseJson.encode(it) }

    /**
     * Importe le texte d'un fichier de cours reçu de l'extérieur. Ré-identifie
     * le cours pour ne jamais écraser un import existant et garder le préfixe
     * utilisateur, quel que soit ce que contenait le fichier.
     */
    fun importCourseFile(text: String): CatalogEntry {
        val decoded = runCatching { CourseRepository.parse(text) }
            .getOrElse { throw StoreException("unreadable") }
        return save(rekeyed(decoded, newIdentifier()))
    }

    /** Recopie un cours sous un nouvel identifiant — le graphe, lui, ne bouge pas. */
    fun rekeyed(course: Course, id: String, name: String? = null): Course =
        course.copy(id = id, name = name ?: course.name)

    private fun fileFor(id: String): File? {
        if (!isUserCourse(id)) return null
        val dir = directory ?: return null
        return File(dir, "$id.json")
    }

    /** L'entrée de catalogue d'un cours utilisateur : niveau « club » par défaut, jamais une finale. */
    fun entry(course: Course) = CatalogEntry(
        id = course.id, name = course.name, eco = emptyList(), side = course.side, level = "club",
        summary = course.summary, positionCount = course.positions.size, isEndgame = false,
        family = null, maxDepth = depth(course),
    )

    /**
     * La profondeur en demi-coups depuis la racine, en LARGEUR : le graphe
     * peut contenir des cycles par transposition, un parcours naïf en
     * profondeur ne terminerait pas.
     */
    fun depth(course: Course): Int {
        val root = CourseRepository.fenKey(course.rootFEN)
        val seen = hashSetOf(root)
        var frontier = listOf(root)
        var depth = 0
        while (frontier.isNotEmpty()) {
            val next = ArrayList<String>()
            for (fen in frontier) for (edge in course.moves(fen)) {
                val to = CourseRepository.fenKey(edge.toFEN)
                if (seen.add(to)) next += to
            }
            if (next.isEmpty()) break
            depth++
            frontier = next
        }
        return depth
    }
}

/**
 * Écrit un cours au format des cours embarqués — celui que [CourseRepository.parse]
 * relit, et que l'app iOS lit aussi. Le commentaire et le titre d'un chapitre
 * sont écrits dans les DEUX langues : ils viennent de l'utilisateur, dans la
 * sienne, et le lecteur se rabat de toute façon sur l'autre quand l'une manque.
 */
object CourseJson {

    fun encode(course: Course): String {
        val root = JSONObject()
        root.put("schemaVersion", 1)
        root.put("id", course.id)
        root.put("name", course.name)
        root.put("side", course.side)
        root.put("level", "club")
        root.put("summary", both(course.summary))
        root.put("kind", "opening")
        root.put("rootFEN", course.rootFEN)
        root.put("chapters", JSONArray().apply {
            course.chapters.forEach { chapter ->
                put(JSONObject().apply {
                    put("id", chapter.id)
                    put("title", both(chapter.title))
                    put("positionFENs", JSONArray(chapter.positionFENs))
                })
            }
        })
        val positions = JSONObject()
        for ((key, moves) in course.positions) {
            val node = JSONObject()
            node.put("fen", key)
            course.ecoNames[key]?.let { node.put("ecoName", it) }
            node.put("moves", JSONArray().apply {
                moves.forEach { m ->
                    put(JSONObject().apply {
                        put("san", m.san); put("uci", m.uci); put("toFEN", m.toFEN); put("role", m.role)
                        m.comment?.let { put("comment", both(it)); put("commentStatus", "validated") }
                        m.eval?.let { put("eval", it) }
                        m.popularity?.let { put("popularityClub", it) }
                        if (m.isCritical) put("isCritical", true)
                    })
                }
            })
            positions.put(key, node)
        }
        root.put("positions", positions)
        return root.toString(2)
    }

    private fun both(text: String) = JSONObject().put("fr", text).put("en", text)
}
