package com.chesslab.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/** Les préférences de l'app. Pendant réduit d'`AppSettings.swift`. */
data class AppSettings(
    val boardThemeId: String = "classic",
    val pieceSetId: String = "classic",
    /** Temps de réflexion du moteur, en millisecondes, pour une partie. */
    val engineMoveTimeMs: Int = 400,
    val autoFlipTwoPlayer: Boolean = true,
    /**
     * Essais accordés par puzzle. UN SEUL par défaut, comme sur iOS : trois
     * invitent à tenter un coup « pour voir », l'inverse de ce qu'un puzzle
     * entraîne.
     */
    val puzzleAttempts: Int = 1,
    val soundsEnabled: Boolean = true,
    /** Le plateau vibre-t-il ? Coup, prise, échec, fin, coup refusé. */
    val hapticsEnabled: Boolean = true,
    /**
     * La langue de la NOTATION des coups : « Cf3 » ou « Nf3 ».
     *
     * Française par défaut, comme iOS. Elle ne touche JAMAIS le PGN stocké ou
     * exporté — le standard est en lettres anglaises, et un PGN français ne
     * serait lu par personne.
     */
    val pieceNotation: PieceNotation = PieceNotation.french,
    /** Les flèches du moteur en analyse — le réglage SURVIT à la fermeture. */
    val analysisArrowMode: String = "best",
)

/** La langue dans laquelle un coup s'écrit. Pendant de `PieceNotation`. */
enum class PieceNotation { french, english }

private val Context.dataStore by preferencesDataStore("settings")

/**
 * Les réglages, lus une fois et tenus en mémoire.
 *
 * Un `StateFlow` plutôt qu'un `Flow` brut : l'interface lit une valeur
 * immédiate, sans état « pas encore chargé » à traiter dans chaque écran.
 */
object SettingsStore {

    private val keyBoardTheme = stringPreferencesKey("boardThemeId")
    private val keyPieceSet = stringPreferencesKey("pieceSetId")
    private val keyMoveTime = intPreferencesKey("engineMoveTimeMs")
    private val keyAutoFlip = booleanPreferencesKey("autoFlipTwoPlayer")
    private val keyAttempts = intPreferencesKey("puzzleAttempts")
    private val keySounds = booleanPreferencesKey("soundsEnabled")
    private val keyHaptics = booleanPreferencesKey("hapticsEnabled")
    private val keyNotation = stringPreferencesKey("pieceNotation")
    private val keyArrowMode = stringPreferencesKey("analysisArrowMode")

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val _state = MutableStateFlow(AppSettings())
    val state: StateFlow<AppSettings> = _state

    fun start(context: Context) {
        val store = context.applicationContext.dataStore
        scope.launch {
            store.data.map { prefs ->
                AppSettings(
                    boardThemeId = prefs[keyBoardTheme] ?: "classic",
                    pieceSetId = prefs[keyPieceSet] ?: "classic",
                    engineMoveTimeMs = prefs[keyMoveTime] ?: 400,
                    autoFlipTwoPlayer = prefs[keyAutoFlip] ?: true,
                    puzzleAttempts = prefs[keyAttempts] ?: 1,
                    soundsEnabled = prefs[keySounds] ?: true,
                    hapticsEnabled = prefs[keyHaptics] ?: true,
                    pieceNotation = if (prefs[keyNotation] == "english") PieceNotation.english
                    else PieceNotation.french,
                    analysisArrowMode = prefs[keyArrowMode] ?: "best",
                )
            }.collect { _state.value = it }
        }
    }

    private fun update(context: Context, block: (androidx.datastore.preferences.core.MutablePreferences) -> Unit) {
        val store = context.applicationContext.dataStore
        scope.launch { store.edit(block) }
    }

    fun setBoardTheme(context: Context, id: String) = update(context) { it[keyBoardTheme] = id }
    fun setPieceSet(context: Context, id: String) = update(context) { it[keyPieceSet] = id }
    fun setMoveTime(context: Context, ms: Int) = update(context) { it[keyMoveTime] = ms }
    fun setAutoFlip(context: Context, on: Boolean) = update(context) { it[keyAutoFlip] = on }
    fun setPuzzleAttempts(context: Context, n: Int) = update(context) { it[keyAttempts] = n }
    fun setSounds(context: Context, on: Boolean) = update(context) { it[keySounds] = on }
    fun setHaptics(context: Context, on: Boolean) = update(context) { it[keyHaptics] = on }
    fun setPieceNotation(context: Context, notation: PieceNotation) =
        update(context) { it[keyNotation] = notation.name }
    fun setArrowMode(context: Context, mode: String) = update(context) { it[keyArrowMode] = mode }
}
