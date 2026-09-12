package com.chesslab.maia

import android.content.Context
import androidx.annotation.StringRes
import kotlin.math.roundToInt

/**
 * Traduction Kotlin de `OpponentProfile.swift` (structures) — la galerie des
 * neuf personnages est générée à part, dans `OpponentGallery.kt`.
 */

/**
 * Ce que le filet Stockfish s'autorise à corriger derrière Maia, et à partir
 * de quel niveau affiché. `null` = jamais pour ce personnage.
 *
 * Les seuils par défaut viennent de l'étude du 05/09/2026 : un joueur de club
 * trouve un mat en deux et sait finir une finale simple ; Maia, qui ne calcule
 * pas, non. En dessous, rater un mat fait PARTIE du personnage.
 */
data class SafetyNetPolicy(
    val mateFromLevel: Int? = 1400,
    val endgameFromLevel: Int? = 1600,
    val endgamePieceLimit: Int = 7,
    /** Un humain qui gagne ne répète pas trois fois, quel que soit son niveau. */
    val avoidsRepetitionWhenWinning: Boolean = true,
)

/**
 * Tout ce qui n'est pas le choix du coup : rythme, abandon, nulle, et la
 * façon dont le personnage change quand la partie tourne.
 */
data class Temperament(
    /** Multiplie le délai de rythme humain (0,5 = vite, 1,5 = lent). */
    val pace: Double = 1.0,
    val resignThresholdCp: Int = -800,
    val resignPatience: Int = 3,
    val offersDraws: Boolean = true,
    val drawOfferMaxCp: Int = 30,
    val temperatureWhenWinning: Double? = null,
    val temperatureWhenLosing: Double? = null,
    val styleWhenWinning: Map<StyleTrait, Double> = emptyMap(),
    val styleWhenLosing: Map<StyleTrait, Double> = emptyMap(),
) {
    companion object { const val WINNING_THRESHOLD_CP = 200 }
}

@Suppress("EnumEntryName")
enum class OpponentTint { maiaBlue, red, deepBlue, green, purple, orange, cyan, slate, yellow }

/**
 * Un adversaire du mode Jouer : un caractère posé sur Maia-3.
 *
 * Le NIVEAU n'est pas ici — c'est le curseur de la partie, mémorisé par
 * personnage. Ce qui est ici ne change pas d'une partie à l'autre : identité,
 * constance, style, tempérament, filet, répertoire.
 */
data class OpponentProfile(
    val id: String,
    /** Le prénom ne se traduit pas : Lena reste Lena. */
    val firstName: String,
    /**
     * Le surnom, l'accroche et les étiquettes sont des RESSOURCES, pas des
     * chaînes : ce sont les seuls textes du modèle que l'utilisateur lit, et
     * ils existent dans les deux langues.
     */
    @StringRes val nicknameRes: Int,
    @StringRes val taglineRes: Int,
    val tagRes: List<Int>,
    val tint: OpponentTint,
    /** 0 = le coup le plus probable, 1 = fidèle aux humains, au-delà = erratique. */
    val temperature: Double,
    val topP: Double,
    val recommendedLevels: IntRange,
    val safetyNet: SafetyNetPolicy,
    val style: StyleProfile,
    val temperament: Temperament,
    val bookId: String?,
) {
    fun nickname(context: Context): String = context.getString(nicknameRes)
    fun tagline(context: Context): String = context.getString(taglineRes)
    fun tags(context: Context): List<String> = tagRes.map(context::getString)

    /** « Lena « Tornade » » — le prénom, puis le surnom traduit. */
    fun displayName(context: Context): String =
        context.getString(R.string.opponent_display_name, firstName, nickname(context))

    /**
     * La plage du curseur : sa plage crédible, et rien d'autre — un Pablo à
     * 2 400 n'est plus Pablo.
     */
    fun clampedLevel(level: Double): Double =
        level.coerceIn(recommendedLevels.first.toDouble(), recommendedLevels.last.toDouble())

    /** Le milieu de la plage conseillée, arrondi à 50. */
    val defaultLevel: Double
        get() {
            val middle = (recommendedLevels.first + recommendedLevels.last) / 2.0
            return (middle / 50).roundToInt() * 50.0
        }

    /** Le personnage tel qu'il joue MAINTENANT, selon le score de la partie. */
    data class Mood(val temperature: Double, val style: StyleProfile)

    fun mood(lastMoverCp: Int?): Mood {
        val cp = lastMoverCp ?: return Mood(temperature, style)
        return when {
            cp >= Temperament.WINNING_THRESHOLD_CP -> Mood(
                temperament.temperatureWhenWinning ?: temperature,
                style.adding(temperament.styleWhenWinning),
            )
            cp <= -Temperament.WINNING_THRESHOLD_CP -> Mood(
                temperament.temperatureWhenLosing ?: temperature,
                style.adding(temperament.styleWhenLosing),
            )
            else -> Mood(temperature, style)
        }
    }
}

/**
 * Traduction Kotlin de `SafetyNet.swift` : QUATRE cas bornés, et rien
 * d'autre. Décisions pures ; l'exécution des recherches vit dans le modèle
 * de vue.
 */
object SafetyNet {
    const val WINNING_THRESHOLD_CP = 200

    /** Un mat en un ou deux, si le personnage est censé le voir. */
    fun overridesForMate(policy: SafetyNetPolicy, level: Int, mateInMoves: Int?): Boolean {
        val mate = mateInMoves ?: return false
        val from = policy.mateFromLevel ?: return false
        return mate in 1..2 && level >= from
    }

    /** Finale technique : Stockfish bridé remplace Maia dès le niveau prévu. */
    fun overridesEndgame(policy: SafetyNetPolicy, level: Int, pieceCount: Int): Boolean {
        val from = policy.endgameFromLevel ?: return false
        return level >= from && pieceCount <= policy.endgamePieceLimit
    }

    /** Répéter ou laisser filer les cinquante coups en position nettement gagnée. */
    fun overridesRepetition(
        policy: SafetyNetPolicy,
        stateAfterMove: chesskit.Board.State,
        moverCp: Int?,
    ): Boolean {
        if (!policy.avoidsRepetitionWhenWinning) return false
        val cp = moverCp ?: return false
        if (cp < WINNING_THRESHOLD_CP) return false
        val draw = stateAfterMove as? chesskit.Board.State.Draw ?: return false
        return draw.reason == chesskit.Board.State.DrawReason.repetition ||
            draw.reason == chesskit.Board.State.DrawReason.fiftyMoves
    }
}
