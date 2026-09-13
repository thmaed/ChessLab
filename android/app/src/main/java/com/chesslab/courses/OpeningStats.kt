package com.chesslab.courses

import android.content.res.AssetManager
import org.json.JSONObject

/**
 * Le SIDECAR d'un cours d'ouverture : pour chaque position, ce que jouent les
 * MAÎTRES et ce que dit STOCKFISH. Pendant d'`OpeningStats.swift`.
 *
 * À côté du cours et non dedans, pour les mêmes raisons qu'iOS : le fichier de
 * cours est la donnée de production, y ajouter des champs ferait porter un
 * risque de décodage à toutes les finales pour une donnée que seules les
 * ouvertures affichent ; les coups de maîtres ne sont pas ceux du répertoire
 * (l'écran veut TOUS les coups joués, pas seulement ceux que l'auteur retient) ;
 * et un seul sidecar reste en mémoire, celui de l'ouverture ouverte.
 *
 * Indexé par clé FEN normalisée, comme le graphe : les transpositions partagent
 * leur entrée.
 *
 * Décodage DÉFENSIF : un fichier absent, partiel ou corrompu donne « pas de
 * donnée » — jamais un plantage, et jamais un écran vide.
 */
data class OpeningStatsSidecar(
    val id: String,
    /** La profondeur du moteur — une évaluation sans elle ne veut pas dire grand-chose. */
    val engineDepth: Int?,
    val positions: Map<String, OpeningPositionStats>,
) {
    fun data(at: String): OpeningPositionStats? = positions[at]

    companion object {
        fun empty(id: String) = OpeningStatsSidecar(id, null, emptyMap())

        /** Décode depuis le texte brut — pour les tests, sans les assets. */
        fun decode(text: String): OpeningStatsSidecar {
            val o = JSONObject(text)
            val positions = HashMap<String, OpeningPositionStats>()
            o.optJSONObject("positions")?.let { all ->
                for (key in all.keys()) {
                    val node = all.optJSONObject(key) ?: continue
                    positions[CourseRepository.fenKey(key)] = OpeningPositionStats.from(node)
                }
            }
            return OpeningStatsSidecar(
                id = o.optString("id"),
                engineDepth = if (o.has("engineDepth")) o.getInt("engineDepth") else null,
                positions = positions,
            )
        }
    }
}

/**
 * Ce que Labs sait d'une position. Les deux champs sont indépendamment
 * facultatifs : le moteur couvre tout, les maîtres non — une position de
 * profondeur 20 dans une sous-variante n'a jamais été jouée en tournoi.
 */
data class OpeningPositionStats(
    val masters: OpeningMasterStats?,
    /**
     * Les meilleurs coups du moteur, au plus TROIS — borné ici et pas seulement
     * à la génération, pour qu'un fichier plus bavard ne déborde pas l'écran.
     */
    val engine: List<OpeningEngineLine>,
) {
    val isEmpty: Boolean get() = masters == null && engine.isEmpty()

    companion object {
        fun from(node: JSONObject): OpeningPositionStats {
            val engine = node.optJSONArray("engine")?.let { array ->
                (0 until array.length()).mapNotNull { i ->
                    val line = array.optJSONObject(i) ?: return@mapNotNull null
                    OpeningEngineLine(
                        san = line.optString("san"),
                        uci = line.optString("uci"),
                        cp = if (line.has("cp")) line.getInt("cp") else null,
                        mate = if (line.has("mate")) line.getInt("mate") else null,
                    )
                }.take(3)
            }.orEmpty()
            val masters = node.optJSONObject("masters")?.let { OpeningMasterStats.from(it) }
            return OpeningPositionStats(masters, engine)
        }
    }
}

/**
 * Une ligne du moteur, calculée d'AVANCE (le rang est l'ordre du tableau).
 *
 * Évaluation TOUJOURS du point de vue des BLANCS, comme le champ `eval` des
 * cours et comme la barre — une seule convention dans toute l'app, ce qui
 * évite l'inversion de signe la plus classique du domaine.
 */
data class OpeningEngineLine(
    val san: String,
    val uci: String,
    /** Centipions, point de vue blanc. Absent si la ligne est un mat. */
    val cp: Int?,
    /** Mat en N (positif = les Blancs matent). Absent sinon. */
    val mate: Int?,
)

/** Un coup joué par des maîtres dans une position, avec son bilan. */
data class OpeningMasterMove(
    val san: String,
    val uci: String,
    val games: Int,
    val whiteWins: Int,
    val draws: Int,
    val blackWins: Int,
    /** L'Elo moyen des parties, quand il est connu. */
    val averageRating: Int?,
    /** Le code ECO atteint par ce coup, quand Lichess le nomme. */
    val eco: String?,
    /** Le nom de la variante atteinte (« Sicilian Defense »). */
    val name: String?,
) {
    /** Le score des BLANCS sur ce coup (nulle = ½), dans 0…1 — `null` sans partie. */
    val whiteScore: Double?
        get() = if (games > 0) (whiteWins + draws / 2.0) / games else null
}

/**
 * Le bilan MAÎTRES d'une position : combien de parties y sont passées, et par
 * quels coups elles en sont sorties.
 */
data class OpeningMasterStats(
    val whiteWins: Int,
    val draws: Int,
    val blackWins: Int,
    val moves: List<OpeningMasterMove>,
) {
    /** Les parties de maîtres ayant atteint cette position. */
    val totalGames: Int get() = whiteWins + draws + blackWins

    /**
     * La part d'un coup parmi les parties de la position (0…1).
     *
     * Rapportée au TOTAL de la position, pas à la somme des coups retenus : le
     * générateur écarte la queue statistique (coups sous 0,5 %), et
     * renormaliser sur les seuls survivants gonflerait leurs parts jusqu'à
     * afficher 100 % là où il en manque cinq.
     */
    fun share(of: OpeningMasterMove): Double =
        if (totalGames > 0) of.games.toDouble() / totalGames else 0.0

    companion object {
        fun from(o: JSONObject): OpeningMasterStats {
            val moves = o.optJSONArray("moves")?.let { array ->
                (0 until array.length()).mapNotNull { i ->
                    val m = array.optJSONObject(i) ?: return@mapNotNull null
                    OpeningMasterMove(
                        san = m.optString("san"),
                        uci = m.optString("uci"),
                        games = m.optInt("g", 0),
                        whiteWins = m.optInt("w", 0),
                        draws = m.optInt("d", 0),
                        blackWins = m.optInt("b", 0),
                        averageRating = if (m.has("elo")) m.getInt("elo") else null,
                        eco = m.optString("eco").ifEmpty { null },
                        name = m.optString("name").ifEmpty { null },
                    )
                }
            }.orEmpty()
            return OpeningMasterStats(
                whiteWins = o.optInt("w", 0), draws = o.optInt("d", 0), blackWins = o.optInt("b", 0),
                moves = moves,
            )
        }
    }
}

/**
 * Charge les sidecars — un fichier par cours, à la demande.
 *
 * Un cours sans sidecar (finale, répertoire importé, ouverture ajoutée depuis
 * la dernière génération) donne un sidecar VIDE plutôt que `null` : l'écran
 * s'affiche normalement, seules les sections statistiques disent qu'elles
 * n'ont rien. La donnée manquante ne retire jamais une fonctionnalité.
 */
object OpeningStatsLoader {

    private const val DIR = "openings_stats"

    /**
     * Un seul sidecar gardé en mémoire : le lecteur en ouvre un à la fois, et
     * les garder tous ferait grossir la mémoire au fil de la navigation
     * (~40 Ko par ouverture, cinquante-huit ouvertures).
     */
    @Volatile private var cached: Pair<String, OpeningStatsSidecar>? = null

    fun sidecar(assets: AssetManager, id: String): OpeningStatsSidecar {
        cached?.let { if (it.first == id) return it.second }
        // Le nom porte « .stats » pour ne pas entrer en collision avec le
        // cours du même identifiant si un dossier se retrouvait aplati.
        val loaded = runCatching {
            assets.open("$DIR/$id.stats.json").bufferedReader().use { it.readText() }
        }.mapCatching { OpeningStatsSidecar.decode(it) }.getOrNull()
            ?: OpeningStatsSidecar.empty(id)
        cached = id to loaded
        return loaded
    }

    /** Vide le cache (tests). */
    fun flush() { cached = null }
}
