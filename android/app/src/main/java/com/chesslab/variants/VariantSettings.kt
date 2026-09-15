package com.chesslab.variants

import android.content.Context
import com.chesslab.play.EngineStrength
import com.chesslab.play.PlayerColorChoice
import com.chesslab.play.TimeControl
import org.json.JSONObject

/**
 * Ce qu'on règle avant une partie de variante. Pendant de
 * `FairyVariantSettings.swift` et `Chess960Settings.swift`, réunis : le
 * sous-ensemble de [com.chesslab.play.PlayGameSettings] qui a un sens ici.
 *
 * Pas de livre d'ouvertures — il n'y a pas de théorie dans ces jeux —, pas de
 * personnage Maia — son réseau est entraîné sur des parties orthodoxes, et il
 * ne sait rien de la Horde ni du canard.
 *
 * Deux champs ne servent qu'à une variante chacune, et sont ignorés par les
 * autres : [tokenInterval] au Coup Volé, [chess960Number] au Chess960. Les
 * réunir ici plutôt que de multiplier les types évite d'écrire trois fois le
 * même écran de réglages.
 */
data class VariantSettings(
    val colorChoice: PlayerColorChoice = PlayerColorChoice.white,
    /**
     * Le niveau du moteur, en Elo. Défaut ACCUEILLANT — « Débutant
     * confirmé » —, comme en partie classique : une variante est déjà
     * déroutante sans qu'on y affronte la pleine puissance.
     */
    val level: Double = 1200.0,
    val timeControlId: String = "none",
    val customMinutes: Int = 15,
    val customIncrementSeconds: Int = 0,
    val showEvalBar: Boolean = false,
    val hintsEnabled: Boolean = true,
    val blunderAlertEnabled: Boolean = true,
    /** Coup Volé SEULEMENT : le nombre de coups entre deux jetons. */
    val tokenInterval: Int = 6,
    /** Duck Chess SEULEMENT : deux humains sur le même appareil. */
    val twoPlayers: Boolean = false,
    /** Chess960 SEULEMENT : le numéro de Scharnagl, ou `null` pour un tirage. */
    val chess960Number: Int? = null,
) {
    val timeControl: TimeControl
        get() = if (timeControlId == "custom") TimeControl.custom(customMinutes, customIncrementSeconds)
        else TimeControl.byId(timeControlId)

    /** La force qui correspond au curseur — bridée pour Fairy-Stockfish. */
    val strength: EngineStrength get() = EngineStrength.of(level)
}

/**
 * Les derniers réglages, mémorisés PAR VARIANTE.
 *
 * Roi de la colline et Horde n'ont aucune raison de partager la même force ni
 * la même cadence : on ne joue pas une variante où l'on a trente-six pions
 * comme une où le roi doit atteindre le centre.
 *
 * La relecture est TOLÉRANTE à un champ absent — même raison que
 * [com.chesslab.play.PlaySettingsStore] : ajouter un réglage ne doit pas
 * faire retomber tous les autres aux valeurs d'usine.
 */
object VariantSettingsStore {

    private const val PREFS = "play"

    private fun key(variantId: String) = "lastVariantSettings.$variantId"

    fun save(context: Context, variantId: String, settings: VariantSettings) {
        val o = JSONObject()
        o.put("colorChoice", settings.colorChoice.name)
        o.put("level", settings.level)
        o.put("timeControlId", settings.timeControlId)
        o.put("customMinutes", settings.customMinutes)
        o.put("customIncrementSeconds", settings.customIncrementSeconds)
        o.put("showEvalBar", settings.showEvalBar)
        o.put("hintsEnabled", settings.hintsEnabled)
        o.put("blunderAlertEnabled", settings.blunderAlertEnabled)
        o.put("tokenInterval", settings.tokenInterval)
        o.put("twoPlayers", settings.twoPlayers)
        o.put("chess960Number", settings.chess960Number ?: JSONObject.NULL)
        prefs(context).edit().putString(key(variantId), o.toString()).apply()
    }

    fun load(context: Context, variantId: String): VariantSettings? {
        val text = prefs(context).getString(key(variantId), null) ?: return null
        return decode(text)
    }

    fun decode(text: String): VariantSettings? {
        val o = runCatching { JSONObject(text) }.getOrNull() ?: return null
        val fallback = VariantSettings()
        return VariantSettings(
            colorChoice = runCatching { PlayerColorChoice.valueOf(o.optString("colorChoice")) }
                .getOrDefault(fallback.colorChoice),
            level = o.optDouble("level", fallback.level),
            timeControlId = o.optString("timeControlId", fallback.timeControlId)
                .ifEmpty { fallback.timeControlId },
            customMinutes = o.optInt("customMinutes", fallback.customMinutes),
            customIncrementSeconds = o.optInt("customIncrementSeconds", fallback.customIncrementSeconds),
            showEvalBar = o.optBoolean("showEvalBar", fallback.showEvalBar),
            hintsEnabled = o.optBoolean("hintsEnabled", fallback.hintsEnabled),
            blunderAlertEnabled = o.optBoolean("blunderAlertEnabled", fallback.blunderAlertEnabled),
            tokenInterval = o.optInt("tokenInterval", fallback.tokenInterval),
            twoPlayers = o.optBoolean("twoPlayers", fallback.twoPlayers),
            chess960Number = if (o.has("chess960Number") && !o.isNull("chess960Number"))
                o.optInt("chess960Number") else null,
        )
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
