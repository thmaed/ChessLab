package com.chesslab.play

import android.content.res.AssetManager
import org.json.JSONArray
import org.json.JSONObject
import kotlin.random.Random

/**
 * Un coup du livre d'ouvertures, et ses suites. Pendant d'`OpeningBookNode`.
 *
 * L'arbre est relatif : chaque nœud porte un SAN valable depuis la position de
 * son parent, jamais une position complète. Le même arbre sert que le moteur
 * joue les Blancs ou les Noirs — la recherche est purement positionnelle.
 */
data class BookNode(
    val san: String,
    val weight: Int,
    /** Faux pour une ligne secondaire. Absent du JSON = ligne principale. */
    val isMainLine: Boolean,
    val children: List<BookNode>,
)

/** Largeur du livre : lignes principales seules, ou variantes comprises. */
enum class BookWidth { mainLinesOnly, includeSidelines }

/**
 * Les livres d'ouvertures embarqués, et le tirage dedans.
 *
 * **Deux livres, deux rôles.** `opening_book.json` est le livre GÉNÉRAL, que
 * l'utilisateur peut couper ; `opponent_books.json` donne à chaque personnage
 * SON répertoire — c'est son caractère, pas un réglage, et il ne se coupe donc
 * pas. Un personnage sans répertoire propre retombe sur le livre général.
 *
 * Sans livre, un réseau entraîné sur des parties humaines rejoue les ouvertures
 * qu'il a vues — souvent les mêmes, et sans le style qu'on lui prête. C'est
 * exactement ce que faisait l'app Android : le fichier était embarqué depuis
 * septembre, et personne ne le lisait.
 */
object OpeningBookStore {

    private var general: List<BookNode>? = null
    private val byOpponent = HashMap<String, List<BookNode>?>()

    /** Le livre général, ou vide s'il manque. */
    @Synchronized
    fun general(assets: AssetManager): List<BookNode> = general ?: runCatching {
        val text = assets.open("opening_book.json").bufferedReader().use { it.readText() }
        parseRoots(JSONObject(text))
    }.getOrDefault(emptyList()).also { general = it }

    /** Le répertoire d'un personnage, ou `null` s'il n'en a pas. */
    @Synchronized
    fun forOpponent(assets: AssetManager, id: String): List<BookNode>? =
        byOpponent.getOrPut(id) {
            runCatching {
                val text = assets.open("opponent_books.json").bufferedReader().use { it.readText() }
                val all = JSONObject(text)
                if (!all.has(id)) null else parseRoots(all.getJSONObject(id))
            }.getOrNull()
        }

    /** Le contenu d'un livre, depuis son JSON. Public pour être testable. */
    fun parse(json: String): List<BookNode> = parseRoots(JSONObject(json))

    /** Les répertoires de tous les personnages, depuis le JSON du fichier. */
    fun parseOpponents(json: String): Map<String, List<BookNode>> {
        val all = JSONObject(json)
        return all.keys().asSequence().associateWith { parseRoots(all.getJSONObject(it)) }
    }

    private fun parseRoots(o: JSONObject): List<BookNode> = nodes(o.optJSONArray("roots"))

    private fun nodes(array: JSONArray?): List<BookNode> {
        if (array == null) return emptyList()
        return (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            BookNode(
                san = o.getString("san"),
                weight = o.optInt("weight", 1),
                // Absent = ligne principale : le fichier ne précise ce champ
                // que pour les lignes secondaires.
                isMainLine = o.optBoolean("isMainLine", true),
                children = nodes(o.optJSONArray("children")),
            )
        }
    }
}

/**
 * Le tirage dans le livre. Pur : ni plateau, ni moteur, ni contexte — donc
 * vérifiable tel quel. Pendant d'`OpeningBookEngine`.
 */
object OpeningBookPicker {

    /**
     * Le prochain coup à jouer, en SAN, ou `null` si la position est sortie de
     * l'arbre connu — il faut alors basculer sur le calcul du moteur.
     *
     * @param sanPath les coups déjà joués, en SAN, depuis le début.
     */
    fun pick(
        roots: List<BookNode>,
        sanPath: List<String>,
        width: BookWidth,
        random: Random = Random.Default,
    ): String? {
        var candidates = roots
        for (played in sanPath) {
            val match = candidates.firstOrNull { it.san == played } ?: return null
            candidates = match.children
        }
        val eligible =
            if (width == BookWidth.mainLinesOnly) candidates.filter { it.isMainLine } else candidates
        if (eligible.isEmpty()) return null
        return weighted(eligible, random)
    }

    /** Tirage PONDÉRÉ : un coup populaire sort plus souvent, sans jamais être seul. */
    private fun weighted(nodes: List<BookNode>, random: Random): String? {
        val total = nodes.sumOf { it.weight }
        if (total <= 0) return nodes.firstOrNull()?.san
        var roll = random.nextInt(total)
        for (node in nodes) {
            if (roll < node.weight) return node.san
            roll -= node.weight
        }
        return nodes.lastOrNull()?.san
    }
}
