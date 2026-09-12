package com.chesslab.analysis

import android.content.res.AssetManager
import org.json.JSONArray

/**
 * Une ouverture nommée de la base ECO : code, nom, et la ligne principale
 * (SAN) qui l'identifie. Pendant de `EcoOpening.swift`.
 *
 * Le nom existe en DEUX langues, là où iOS n'en connaît qu'une : sa base est
 * française, ce qui se voit dès qu'on passe l'app en anglais. Le catalogue
 * Android est produit par `tools/android-eco/make_eco.py` depuis le fichier
 * iOS, avec la colonne anglaise en plus.
 */
data class EcoOpening(
    val eco: String,
    val name: String,
    val nameEn: String,
    val moves: List<String>,
) {
    /** Le nom dans la langue active. */
    fun displayName(french: Boolean): String = if (french) name else nameEn
}

/**
 * Recherche l'ouverture nommée pour une ligne jouée, et reconnaît les coups
 * de théorie. Pendant de `EcoOpeningLookup`.
 */
object EcoOpeningLookup {

    /**
     * Par plus long préfixe : parmi toutes les entrées dont [EcoOpening.moves]
     * est un préfixe exact de [sanPath], celle dont la ligne est la plus
     * longue — c'est la classification ECO la plus précise que la ligne jouée
     * confirme.
     */
    fun openingName(sanPath: List<String>, database: List<EcoOpening>): EcoOpening? =
        database
            .filter { it.moves.size <= sanPath.size && sanPath.subList(0, it.moves.size) == it.moves }
            .maxByOrNull { it.moves.size }

    /**
     * Vrai tant que la ligne jouée est un préfixe d'une ligne de théorie
     * connue — sens INVERSE de [openingName] : ici c'est la base qui doit
     * prolonger la partie, pas la partie qui prolonge la base. C'est le
     * critère « coup de théorie » de la classification.
     */
    fun isInBook(sanPath: List<String>, database: List<EcoOpening>): Boolean {
        if (sanPath.isEmpty()) return false
        return database.any {
            it.moves.size >= sanPath.size && it.moves.subList(0, sanPath.size) == sanPath
        }
    }
}

/** Charge la base ECO embarquée. Pendant d'`EcoOpeningLoader`. */
object EcoOpeningLoader {

    private var cached: List<EcoOpening>? = null
    private var cachedBook: List<EcoOpening>? = null

    /**
     * Base ECO « nommée » : 76 entrées avec code, mais COURTES (médiane
     * 2 coups). Sert à NOMMER l'ouverture, pas à mesurer la profondeur de
     * théorie — voir [bookLines].
     *
     * Base vide en cas de fichier manquant ou corrompu : l'en-tête d'ouverture
     * s'affiche simplement vide, jamais de plantage.
     */
    @Synchronized
    fun standard(assets: AssetManager): List<EcoOpening> = cached ?: runCatching {
        val text = assets.open("eco_openings.json").bufferedReader().use { it.readText() }
        val array = JSONArray(text)
        (0 until array.length()).map { i ->
            val o = array.getJSONObject(i)
            val moves = o.getJSONArray("moves")
            EcoOpening(
                eco = o.getString("eco"),
                name = o.getString("name"),
                nameEn = o.optString("name_en", o.getString("name")),
                moves = (0 until moves.length()).map { moves.getString(it) },
            )
        }
    }.getOrDefault(emptyList()).also { cached = it }

    /**
     * Base ÉTENDUE pour la détection « coup de théorie » : la base ECO courte
     * COMPLÉTÉE par les 149 familles d'`opening_library.json` (≈ 11 coups
     * chacune). Sans elles, la théorie s'arrêtait au premier échange
     * (2 coups) ; avec, un coup reste « Théorie » tant qu'il suit une ligne
     * principale connue, bien plus profondément.
     */
    @Synchronized
    fun bookLines(assets: AssetManager): List<EcoOpening> = cachedBook ?: run {
        val library = runCatching {
            val text = assets.open("opening_library.json").bufferedReader().use { it.readText() }
            val array = JSONArray(text)
            (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                val family = o.optString("family")
                // `eco` vide : ces lignes servent la PROFONDEUR, pas le nom,
                // que la base courte fournit avec son code.
                EcoOpening("", family, family, sanMoves(o.optString("pgn")))
            }
        }.getOrDefault(emptyList())
        (standard(assets) + library).also { cachedBook = it }
    }

    /**
     * Extrait la séquence SAN d'un PGN de la bibliothèque : on jette les
     * jetons de numérotation (`1.`, `1...`) — les seuls à contenir un point —
     * et l'on garde les coups.
     */
    fun sanMoves(pgn: String): List<String> =
        pgn.split(" ").filter { it.isNotEmpty() && !it.contains(".") }
}
