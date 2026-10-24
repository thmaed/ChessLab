package com.chesslab.analysis

import com.chesslab.puzzles.GamePhase
import java.util.Locale

/**
 * Points de probabilité de gain perdus sur une phase, et nombre de coups
 * comptés (hors théorie). Pendant de `PhaseLoss` (`GameProfile.swift`, A4).
 */
data class PhaseLoss(val total: Double = 0.0, val count: Int = 0) {
    val average: Double? get() = if (count == 0) null else total / count
}

/** Le code court d'une phase dans la chaîne stockée avec la partie. */
val GamePhase.code: String
    get() = when (this) {
        GamePhase.opening -> "o"
        GamePhase.middlegame -> "m"
        GamePhase.endgame -> "e"
    }

/**
 * Ce qu'une partie dit des faiblesses de CE joueur, rangé dans la partie
 * enregistrée (A4) : la perte par phase et les motifs tactiques manqués. Deux
 * chaînes courtes par camp, relues sans recalcul ni réanalyse. Même format
 * qu'iOS (`GameProfileCodec`).
 */
object GameProfileCodec {
    /** « o:12.50:6,m:30.00:9,e:4.00:2 » — phase : perte totale : coups. */
    fun encodePhases(phases: Map<GamePhase, PhaseLoss>): String =
        GamePhase.entries.joinToString(",") { phase ->
            val loss = phases[phase] ?: PhaseLoss()
            "${phase.code}:${String.format(Locale.ROOT, "%.2f", loss.total)}:${loss.count}"
        }

    fun decodePhases(text: String?): Map<GamePhase, PhaseLoss> {
        val result = HashMap<GamePhase, PhaseLoss>()
        for (part in (text ?: "").split(",")) {
            val fields = part.split(":")
            if (fields.size != 3) continue
            val phase = GamePhase.entries.firstOrNull { it.code == fields[0] } ?: continue
            val total = fields[1].toDoubleOrNull() ?: continue
            val count = fields[2].toIntOrNull() ?: continue
            result[phase] = PhaseLoss(total, count)
        }
        return result
    }

    /** « fork:2,pin:1 » — motif : fautes, triés par nom pour qu'une même partie donne la même chaîne. */
    fun encodeThemes(themes: Map<String, Int>): String =
        themes.filterValues { it > 0 }.toSortedMap().entries.joinToString(",") { "${it.key}:${it.value}" }

    fun decodeThemes(text: String?): Map<String, Int> {
        val result = HashMap<String, Int>()
        for (part in (text ?: "").split(",")) {
            val fields = part.split(":")
            if (fields.size == 2) fields[1].toIntOrNull()?.let { result[fields[0]] = it }
        }
        return result
    }
}

/** Le thème stocké dans le profil d'une partie. `other` (aucun motif nommable) est ajouté par l'appelant. */
val TacticalMotif.profileTheme: String
    get() = when (this) {
        is TacticalMotif.Checkmate -> "mate"
        is TacticalMotif.HangingPiece -> "hanging"
        is TacticalMotif.Fork -> "fork"
        is TacticalMotif.DiscoveredCheck -> "discovery"
        is TacticalMotif.Pin -> "pin"
    }
