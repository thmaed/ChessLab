package com.chesslab.play

/**
 * Les réglages d'une partie, choisis sur l'écran Nouvelle partie et portés
 * jusqu'au plateau. Pendant de `PlayGameSettings.swift`.
 *
 * Ils ne vivent QUE le temps d'une partie : les réglages durables (thème,
 * jeu de pièces, langue) sont ailleurs, dans [com.chesslab.settings].
 */
enum class PlayerColorChoice { white, black, random }

/** Une cadence : temps de départ et incrément, en secondes. */
data class TimeControl(
    val id: String,
    val category: String,
    val label: String,
    val initialSeconds: Int,
    val incrementSeconds: Int,
) {
    val hasClock: Boolean get() = initialSeconds > 0

    companion object {
        val none = TimeControl("none", "none", "—", 0, 0)
        val presets = listOf(
            none,
            TimeControl("bullet_1_0", "bullet", "1+0", 60, 0),
            TimeControl("bullet_2_1", "bullet", "2+1", 120, 1),
            TimeControl("blitz_3_0", "blitz", "3+0", 180, 0),
            TimeControl("blitz_3_2", "blitz", "3+2", 180, 2),
            TimeControl("blitz_5_0", "blitz", "5+0", 300, 0),
            TimeControl("rapid_10_0", "rapid", "10+0", 600, 0),
            TimeControl("rapid_15_10", "rapid", "15+10", 900, 10),
            TimeControl("rapid_30_0", "rapid", "30+0", 1800, 0),
            TimeControl("classical_30_30", "classical", "30+30", 1800, 30),
            TimeControl("classical_90_30", "classical", "90+30", 5400, 30),
        )
        val categories = listOf("none", "bullet", "blitz", "rapid", "classical")
        fun byId(id: String): TimeControl = presets.firstOrNull { it.id == id } ?: none
    }
}

data class PlayGameSettings(
    val colorChoice: PlayerColorChoice = PlayerColorChoice.white,
    /** `null` = Stockfish bridé à [level] ; sinon le personnage joué par Maia. */
    val opponentId: String? = "maia",
    val level: Double = 1500.0,
    val timeControlId: String = "none",
    val hintsEnabled: Boolean = true,
    val showEvalBar: Boolean = false,
    val engineResigns: Boolean = true,
    /**
     * Prévenir quand le coup qu'on vient de jouer coûte cher, et proposer de
     * le reprendre. Sans effet avec une pendule : on ne reprend pas du temps.
     */
    val blunderAlertEnabled: Boolean = true,
    /** Position de départ imposée, ou `null` pour la position initiale. */
    val startFen: String? = null,
) {
    val timeControl: TimeControl get() = TimeControl.byId(timeControlId)
}
