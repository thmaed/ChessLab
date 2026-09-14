package com.chesslab.play

import android.content.Context
import org.json.JSONObject

/**
 * Les derniers réglages d'une partie, mémorisés pour préremplir l'écran
 * Nouvelle partie. Pendant de `PlaySettingsStore` (`PlayGameSettings.swift`).
 *
 * La position de départ n'est volontairement PAS mémorisée : une position
 * personnalisée est un choix ponctuel, pas une préférence durable.
 *
 * La lecture est TOLÉRANTE à un champ absent — chacun retombe sur son défaut.
 * Sans cela, ajouter un réglage ferait échouer la relecture de TOUS les
 * autres, et l'écran repartirait aux valeurs d'usine sans que rien ne
 * l'explique : le défaut a été payé côté iOS, on ne le repaie pas ici.
 */
object PlaySettingsStore {

    private const val PREFS = "play"
    private const val KEY = "lastPlayGameSettings"

    fun save(context: Context, settings: PlayGameSettings) {
        val o = JSONObject()
        o.put("colorChoice", settings.colorChoice.name)
        o.put("opponentId", settings.opponentId ?: JSONObject.NULL)
        o.put("level", settings.level)
        o.put("timeControlId", settings.timeControlId)
        o.put("customMinutes", settings.customMinutes)
        o.put("customIncrementSeconds", settings.customIncrementSeconds)
        o.put("hintsEnabled", settings.hintsEnabled)
        o.put("showEvalBar", settings.showEvalBar)
        o.put("engineResigns", settings.engineResigns)
        o.put("blunderAlertEnabled", settings.blunderAlertEnabled)
        o.put("bookEnabled", settings.bookEnabled)
        o.put("bookWidth", settings.bookWidth.name)
        // `startFen` reste dehors : voir la documentation de tête.
        prefs(context).edit().putString(KEY, o.toString()).apply()
    }

    fun load(context: Context): PlayGameSettings? {
        val text = prefs(context).getString(KEY, null) ?: return null
        val o = runCatching { JSONObject(text) }.getOrNull() ?: return null
        val fallback = PlayGameSettings()
        return PlayGameSettings(
            colorChoice = runCatching { PlayerColorChoice.valueOf(o.optString("colorChoice")) }
                .getOrDefault(fallback.colorChoice),
            // Une clé absente veut dire « réglage d'avant les personnages » :
            // on garde alors Stockfish plutôt que d'imposer un adversaire.
            opponentId = if (o.has("opponentId") && !o.isNull("opponentId")) o.optString("opponentId") else null,
            level = o.optDouble("level", fallback.level),
            timeControlId = o.optString("timeControlId", fallback.timeControlId).ifEmpty { fallback.timeControlId },
            customMinutes = o.optInt("customMinutes", fallback.customMinutes),
            customIncrementSeconds = o.optInt("customIncrementSeconds", fallback.customIncrementSeconds),
            hintsEnabled = o.optBoolean("hintsEnabled", fallback.hintsEnabled),
            showEvalBar = o.optBoolean("showEvalBar", fallback.showEvalBar),
            engineResigns = o.optBoolean("engineResigns", fallback.engineResigns),
            blunderAlertEnabled = o.optBoolean("blunderAlertEnabled", fallback.blunderAlertEnabled),
            bookEnabled = o.optBoolean("bookEnabled", fallback.bookEnabled),
            bookWidth = runCatching { BookWidth.valueOf(o.optString("bookWidth")) }
                .getOrDefault(fallback.bookWidth),
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/**
 * Le dernier niveau choisi POUR CHAQUE personnage, mémorisé à part : on joue
 * Pablo à 1 000 et Nadia à 1 800, et l'écran doit s'en souvenir par
 * personnage, pas d'un seul curseur pour tous. Pendant d'`OpponentLevelStore`.
 */
object OpponentLevelStore {

    private const val PREFS = "play"
    private const val KEY = "opponentLevels.v1"

    fun level(context: Context, profileId: String): Double? {
        val text = prefs(context).getString(KEY, null) ?: return null
        val o = runCatching { JSONObject(text) }.getOrNull() ?: return null
        if (!o.has(profileId)) return null
        return o.optDouble(profileId).takeIf { !it.isNaN() }
    }

    fun save(context: Context, level: Double, profileId: String) {
        val text = prefs(context).getString(KEY, null)
        val o = runCatching { JSONObject(text ?: "{}") }.getOrNull() ?: JSONObject()
        o.put(profileId, level)
        prefs(context).edit().putString(KEY, o.toString()).apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
