package com.chesslab.twoplayer

import android.content.Context
import chesskit.Position
import com.chesslab.play.TimeControl
import org.json.JSONObject

/**
 * Ce qu'on règle avant une partie à deux. Pendant de
 * `TwoPlayerGameSettings.swift`.
 *
 * Les NOMS sont le point qui surprend le plus : on joue à deux autour d'un
 * téléphone, et « Blancs » / « Noirs » ne dit pas qui perd. Une partie rangée
 * dans la bibliothèque sous « Thierry — Camille » se retrouve, une partie
 * rangée sous « Blancs — Noirs » se confond avec toutes les autres.
 */
data class TwoPlayerSettings(
    val whiteName: String = "",
    val blackName: String = "",
    val rotation: RotationMode = RotationMode.faceToFace,
    val timeControlId: String = "none",
    /** Utilisés seulement quand [timeControlId] vaut « custom ». */
    val customMinutes: Int = 15,
    val customIncrementSeconds: Int = 0,
    /** Position de départ imposée, venue d'un autre mode. */
    val startFen: String? = null,
) {
    val timeControl: TimeControl
        get() = if (timeControlId == "custom") TimeControl.custom(customMinutes, customIncrementSeconds)
        else TimeControl.byId(timeControlId)

    /** La position d'où la partie part — standard, sauf reprise d'ailleurs. */
    val startingPosition: Position
        get() = startFen?.let { Position.fromFen(it) } ?: Position.standard

    /** Comment le plateau se présente aux deux joueurs. */
    enum class RotationMode {
        /** Le plateau pivote à 180° après chaque coup : on est assis face à face. */
        faceToFace,

        /** Orientation fixe : on est côte à côte. */
        fixed,

        /**
         * Plateau fixe, mais la ligne du joueur DU HAUT est retournée à 180° :
         * chacun lit ses propres informations à l'endroit depuis son côté de
         * la table, et personne n'a besoin de faire tourner l'appareil.
         */
        tabletop,
    }
}

/**
 * Les derniers réglages d'une partie à deux, mémorisés pour préremplir
 * l'écran de configuration. Pendant de `TwoPlayerSettingsStore`.
 *
 * Contrairement au mode Jouer, les NOMS sont persistés : deux joueurs
 * récurrents — un club, une famille — rejouent sous les mêmes noms, et les
 * retaper à chaque partie est le genre de friction qui fait sauter l'écran
 * de réglages. La position de départ, elle, n'est PAS mémorisée : c'est un
 * choix ponctuel, pas une préférence durable.
 *
 * La lecture est TOLÉRANTE à un champ absent — même raison que
 * [com.chesslab.play.PlaySettingsStore] : ajouter un réglage ne doit pas
 * faire retomber tous les autres aux valeurs d'usine.
 */
object TwoPlayerSettingsStore {

    private const val PREFS = "play"
    private const val KEY = "lastTwoPlayerGameSettings"

    fun save(context: Context, settings: TwoPlayerSettings) {
        val o = JSONObject()
        o.put("whiteName", settings.whiteName)
        o.put("blackName", settings.blackName)
        o.put("rotation", settings.rotation.name)
        o.put("timeControlId", settings.timeControlId)
        o.put("customMinutes", settings.customMinutes)
        o.put("customIncrementSeconds", settings.customIncrementSeconds)
        // `startFen` reste dehors : voir la documentation de tête.
        prefs(context).edit().putString(KEY, o.toString()).apply()
    }

    fun load(context: Context): TwoPlayerSettings? {
        val text = prefs(context).getString(KEY, null) ?: return null
        return decode(text)
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY).apply()
    }

    /** Le JSON rangé dans l'autosauvegarde : les noms survivent à la reprise. */
    fun encode(settings: TwoPlayerSettings): String = JSONObject().apply {
        put("whiteName", settings.whiteName)
        put("blackName", settings.blackName)
        put("rotation", settings.rotation.name)
        put("timeControlId", settings.timeControlId)
        put("customMinutes", settings.customMinutes)
        put("customIncrementSeconds", settings.customIncrementSeconds)
    }.toString()

    fun decode(text: String): TwoPlayerSettings? {
        val o = runCatching { JSONObject(text) }.getOrNull() ?: return null
        val fallback = TwoPlayerSettings()
        return TwoPlayerSettings(
            whiteName = o.optString("whiteName", fallback.whiteName),
            blackName = o.optString("blackName", fallback.blackName),
            rotation = runCatching { TwoPlayerSettings.RotationMode.valueOf(o.optString("rotation")) }
                .getOrDefault(fallback.rotation),
            timeControlId = o.optString("timeControlId", fallback.timeControlId)
                .ifEmpty { fallback.timeControlId },
            customMinutes = o.optInt("customMinutes", fallback.customMinutes),
            customIncrementSeconds = o.optInt("customIncrementSeconds", fallback.customIncrementSeconds),
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
