package com.chesslab.analysis

import android.content.Context
import chesskit.Board
import chesskit.Square
import com.chesslab.R
import com.chesslab.maia.MaiaCandidate
import com.chesslab.play.PlaySettingsStore

/**
 * Ce que jouent les humains du niveau du joueur dans la position d'un coup,
 * et ce que cela dit du coup joué. Pendant de `HumanMoveInsight` /
 * `HumanMoveCoach` (`HumanMoveCoach.swift`) — B1, le « Coach ».
 *
 * Maia ne CALCULE pas : ses probabilités disent ce que les humains jouent, pas
 * ce qui est bon. Le Coach ne contredit donc jamais le moteur : il ajoute une
 * ligne — « erreur typique » ou « accident » — à un verdict déjà rendu par
 * Stockfish.
 */
data class HumanMoveInsight(
    /** Niveau (échelle Maia/Lichess) auquel Maia a été interrogée. */
    val level: Int,
    /** Part des joueurs de ce niveau qui jouent le coup joué (0...1). */
    val playedProbability: Double,
    /** Le coup le plus courant à ce niveau, en SAN brut (l'écran le convertit). */
    val topMoveSan: String,
    val topProbability: Double,
    /** Le coup joué EST le plus courant : inutile de le répéter. */
    val playedIsTop: Boolean,
) {
    enum class Kind {
        /** Faute que beaucoup de joueurs de ce niveau commettent : une leçon. */
        TypicalMistake,
        /** Faute que presque personne ne commet à ce niveau : fatigue, clic. */
        Accident,
        /** Bon coup que peu de joueurs de ce niveau trouvent. */
        RareFind,
    }

    /**
     * La qualification dépend du verdict du moteur, qui peut arriver APRÈS la
     * réponse de Maia : elle se lit donc à l'affichage, pas au calcul.
     */
    fun kind(isFault: Boolean): Kind? = HumanMoveCoach.classify(playedProbability, isFault)
}

object HumanMoveCoach {
    /**
     * Seuils de qualification, en part de joueurs : une faute jouée par au
     * moins un joueur sur douze est « typique » ; sous un sur trente, c'est un
     * « accident » ; entre les deux, on donne le chiffre sans étiquette.
     */
    const val TYPICAL_THRESHOLD = 0.08
    const val ACCIDENT_THRESHOLD = 0.03

    /** Un bon coup joué par moins d'un joueur sur vingt-cinq est « rare ». */
    const val RARE_FIND_THRESHOLD = 0.04

    /** Bornes de l'échelle du Coach : celle sur laquelle Maia a été mesurée. */
    val levelRange = 600..2600

    fun classify(probability: Double, isFault: Boolean): HumanMoveInsight.Kind? {
        if (isFault) {
            if (probability >= TYPICAL_THRESHOLD) return HumanMoveInsight.Kind.TypicalMistake
            if (probability < ACCIDENT_THRESHOLD) return HumanMoveInsight.Kind.Accident
            return null
        }
        return if (probability < RARE_FIND_THRESHOLD) HumanMoveInsight.Kind.RareFind else null
    }

    /**
     * Le niveau du joueur tant qu'aucune estimation fiable n'existe : celui
     * choisi à la création de la dernière partie, sinon 1200.
     */
    fun defaultLevel(context: Context): Int {
        val chosen = PlaySettingsStore.load(context)?.level ?: 1200.0
        return Math.round(chosen).toInt().coerceIn(levelRange)
    }

    /**
     * Lit la distribution de Maia sur la position PARENT du coup.
     * Un coup absent de la distribution a une probabilité nulle pour Maia.
     */
    fun insight(
        distribution: List<MaiaCandidate>,
        playedLan: String,
        parent: Board,
        level: Int,
    ): HumanMoveInsight? {
        val top = distribution.firstOrNull() ?: return null
        val probability = distribution.firstOrNull { it.move.uci == playedLan }?.probability ?: 0.0
        return HumanMoveInsight(
            level = level,
            playedProbability = probability,
            topMoveSan = san(top.move.uci, parent),
            topProbability = top.probability,
            playedIsTop = top.move.uci == playedLan,
        )
    }

    /**
     * La notation SAN d'un coup UCI sur [board], sans le toucher. Une
     * promotion retombe sur l'UCI : la SAN d'une promotion dépend de la pièce
     * choisie, et ce n'est pas ici qu'on la complète.
     */
    fun san(uci: String, board: Board): String {
        if (uci.length != 4) return uci
        val scratch = Board(board.position.copy())
        val made = scratch.move(Square(uci.substring(0, 2)), Square(uci.substring(2, 4))) ?: return uci
        return made.san
    }

    /** « 12 % », ou « moins de 1 % » : un coup presque impossible ne s'écrit pas « 0 % ». */
    fun percentText(context: Context, probability: Double): String {
        val percent = Math.round(probability * 100).toInt()
        return if (percent < 1) context.getString(R.string.coach_less_than_one) else "$percent %"
    }

    /**
     * La ligne du Coach, ou `null` s'il n'y a rien à en dire. [topSan] est le
     * coup le plus courant déjà converti à la notation de l'écran.
     */
    fun sentence(context: Context, insight: HumanMoveInsight, isFault: Boolean, topSan: String): String? {
        val played = percentText(context, insight.playedProbability)
        val level = insight.level
        val common = if (insight.playedIsTop) ""
        else " " + context.getString(
            R.string.coach_most_common, topSan, percentText(context, insight.topProbability),
        )
        return when (insight.kind(isFault)) {
            HumanMoveInsight.Kind.TypicalMistake ->
                context.getString(R.string.coach_typical, played, level) + common
            HumanMoveInsight.Kind.Accident ->
                context.getString(R.string.coach_accident, played, level) + common
            HumanMoveInsight.Kind.RareFind ->
                context.getString(R.string.coach_rare, played, level)
            null ->
                if (!isFault) null
                else context.getString(R.string.coach_plain, played, level) + common
        }
    }
}
