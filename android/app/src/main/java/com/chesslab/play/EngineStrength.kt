package com.chesslab.play

import androidx.annotation.StringRes
import com.chesslab.R
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Le réglage de la FORCE du moteur. Pendant de `EngineStrength.swift`.
 *
 * Stockfish ne sait limiter `UCI_Elo` qu'entre 1320 et 3190. En dessous, on
 * simule un niveau plus faible autrement : `UCI_LimitStrength` désactivé, un
 * `Skill Level` bas, et une PROFONDEUR plafonnée — sans quoi un « débutant »
 * à qui l'on donne un dixième de seconde reste un joueur redoutable sur un
 * plateau à trente-deux pièces.
 */
sealed class EngineStrength {

    /** Force plafonnée par `UCI_LimitStrength` + `UCI_Elo` (1320…3190). */
    data class Limited(val elo: Int) : EngineStrength()

    /** Sous 1320 : `Skill Level` bas et profondeur limitée. */
    data class BelowMinimum(val approximateElo: Int, val skillLevel: Int, val depth: Int) : EngineStrength()

    /** Aucune limite : la pleine puissance du moteur. */
    data object Maximum : EngineStrength()

    /** La valeur à montrer sur le curseur pour ce réglage. */
    val sliderValue: Double
        get() = when (this) {
            is Limited -> elo.toDouble()
            is BelowMinimum -> approximateElo.toDouble()
            Maximum -> sliderRange.endInclusive
        }

    /** Les `setoption` à envoyer au moteur pour appliquer ce réglage. */
    val setupCommands: List<String>
        get() = when (this) {
            is Limited -> listOf(
                "setoption name UCI_LimitStrength value true",
                "setoption name UCI_Elo value $elo",
                "setoption name Skill Level value 20",
            )
            is BelowMinimum -> listOf(
                "setoption name UCI_LimitStrength value false",
                "setoption name Skill Level value $skillLevel",
            )
            Maximum -> listOf(
                "setoption name UCI_LimitStrength value false",
                "setoption name Skill Level value 20",
            )
        }

    /**
     * Les mêmes commandes pour Fairy-Stockfish, dont les bornes d'`UCI_Elo`
     * sont 500…2850 et non 1320…3190. Une valeur hors bornes y est REJETÉE EN
     * SILENCE, le bridage restant actif à l'Elo par défaut : un curseur à 3000
     * donnait un adversaire à 1350 sans le dire.
     */
    val fairySetupCommands: List<String>
        get() {
            if (this !is Limited) return setupCommands
            if (elo > fairyRatedRange.last) return Maximum.setupCommands
            return Limited(max(elo, fairyRatedRange.first)).setupCommands
        }

    /** La profondeur maximale de `go depth`, quand il y en a une. */
    val maxDepth: Int?
        get() = (this as? BelowMinimum)?.depth

    /** « Elo 1400 », « Elo ~1000 » sous la borne, ou « Maximum ». */
    @get:StringRes
    val labelRes: Int
        get() = when (this) {
            is Limited -> R.string.strength_elo
            is BelowMinimum -> R.string.strength_elo_approx
            Maximum -> R.string.strength_maximum
        }

    companion object {
        /** La plage complète, jusqu'à la pleine puissance. */
        val sliderRange = 800.0..3190.0

        /**
         * La plage du mode Jouer : la MÊME. On laisse monter aussi haut qu'on
         * veut, quitte à se faire écraser.
         */
        val playSliderRange = 800.0..3190.0

        const val ratedMinimum = 1320

        val fairyRatedRange = 500..2850

        /** Le réglage correspondant à une position de curseur. */
        fun of(sliderValue: Double): EngineStrength {
            val elo = sliderValue.roundToInt()
            return when {
                elo >= 3190 -> Maximum
                elo >= ratedMinimum -> Limited(elo)
                else -> {
                    // Skill Level (0…5) et profondeur (1…6) interpolés sur
                    // 800…1319 pour approcher un niveau très faible.
                    val t = (elo - 800).toDouble() / (ratedMinimum - 1 - 800).toDouble()
                    BelowMinimum(
                        approximateElo = elo,
                        skillLevel = max(0, (t * 5).roundToInt()),
                        depth = max(1, (1 + t * 5).roundToInt()),
                    )
                }
            }
        }
    }
}

/**
 * Les paliers NOMMÉS du curseur. Ils s'arrêtent à « Grand Maître » : au-delà,
 * le curseur monte jusqu'au maximum, mais sans nom — ces niveaux ne se jouent
 * pas, ils se subissent. Les marches du bas resserrent l'écart là où l'on
 * progresse vraiment.
 */
data class EnginePreset(val id: String, @StringRes val label: Int, val strength: EngineStrength) {
    companion object {
        val all = listOf(
            EnginePreset("e800", R.string.preset_absolute_beginner, EngineStrength.of(800.0)),
            EnginePreset("e1000", R.string.preset_beginner, EngineStrength.of(1000.0)),
            EnginePreset("e1200", R.string.preset_improving, EngineStrength.of(1200.0)),
            EnginePreset("e1400", R.string.preset_intermediate, EngineStrength.Limited(1400)),
            EnginePreset("e1600", R.string.preset_strong_intermediate, EngineStrength.Limited(1600)),
            EnginePreset("e2000", R.string.preset_advanced, EngineStrength.Limited(2000)),
            EnginePreset("e2300", R.string.preset_national_master, EngineStrength.Limited(2300)),
            EnginePreset("e2500", R.string.preset_grandmaster, EngineStrength.Limited(2500)),
        )

        /**
         * Le palier dont le nom décrit une valeur du curseur : le plus proche,
         * l'égalité allant au plus bas (900 est encore « Grand débutant », 950
         * déjà « Débutant »). Au maximum, aucun palier — c'est « Maximum », et
         * le libellé du chiffre le dit.
         */
        fun nearest(sliderValue: Double): EnginePreset? {
            if (sliderValue >= EngineStrength.playSliderRange.endInclusive) return null
            return all.minByOrNull { abs(it.strength.sliderValue - sliderValue) }
        }
    }
}
