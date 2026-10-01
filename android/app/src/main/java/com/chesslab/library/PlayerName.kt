package com.chesslab.library

import android.content.Context
import com.chesslab.R
import com.chesslab.settings.SettingsStore

/**
 * Le nom d'un joueur, tel qu'il s'AFFICHE. Pendant de `PlayerName.swift`.
 *
 * Deux choses passent par ici, et c'est exprès qu'elles n'en font qu'une :
 *
 * - **la traduction.** La bibliothèque range le nom du joueur dans la langue
 *   du moment (« Vous » ou « You »), et ce nom sert aussi de repère pour
 *   savoir de quel côté on jouait ([com.chesslab.progression.ProgressionSummary]).
 *   L'accueil le retraduisait déjà, avec sa propre fonction privée ; la
 *   bibliothèque, elle, l'affichait tel quel — une partie jouée en français
 *   restait « Vous » une fois l'app passée en anglais. C'est le défaut
 *   qu'un testeur a remonté côté iOS le 27/09/2026, et Android l'avait aussi ;
 * - **le nom choisi.** Le réglage « Votre nom » remplace « Vous » partout dès
 *   qu'il est renseigné — y compris dans les parties déjà rangées, qui portent
 *   la sentinelle.
 *
 * Les deux langues sont reconnues : c'est la langue DU JOUR qui décide, pas
 * celle du jour de la partie. Le prix de cette symétrie : un joueur importé
 * qui s'appellerait littéralement « White » s'afficherait « Blancs ». Le cas
 * est théorique ; l'inverse se voyait tous les jours.
 */
object PlayerName {

    /** Le nom de l'utilisateur : le sien s'il s'en est donné un, sinon « Vous ». */
    fun you(context: Context): String {
        val chosen = SettingsStore.state.value.playerName.trim()
        return chosen.ifEmpty { context.getString(R.string.you) }
    }

    fun white(context: Context): String = context.getString(R.string.color_white_side)
    fun black(context: Context): String = context.getString(R.string.color_black_side)
    fun computer(context: Context): String = context.getString(R.string.play_computer)

    /**
     * Traduit les noms « spéciaux » rangés en clair ; laisse intact un vrai
     * nom saisi ou venu d'un PGN importé. `null` pour une valeur absente,
     * vide ou « ? » : c'est à l'appelant de choisir son repli.
     */
    fun display(context: Context, stored: String?): String? {
        val trimmed = stored?.trim().orEmpty()
        if (trimmed.isEmpty() || trimmed == "?") return null
        return when (trimmed) {
            "Vous", "You" -> you(context)
            "Blancs", "White" -> white(context)
            "Noirs", "Black" -> black(context)
            // « Stockfish » : nom rangé par les parties d'avant le renommage,
            // affiché « Ordinateur » comme les nouvelles.
            "Ordinateur", "Computer", "Stockfish" -> computer(context)
            else -> trimmed
        }
    }

    /** Même chose, avec un repli quand rien n'est rangé. */
    fun display(context: Context, stored: String?, fallback: String): String =
        display(context, stored) ?: fallback
}
