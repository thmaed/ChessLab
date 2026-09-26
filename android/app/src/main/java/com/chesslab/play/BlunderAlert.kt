package com.chesslab.play

import com.chesslab.analysis.EvalConversion

/**
 * L'alerte avant… non : APRÈS un coup risqué. Pendant de
 * `PendingBlunderWarning` et `blunderSeverity` (`PlayViewModel.swift`).
 *
 * **Rétroactive, et c'est voulu.** Prévenir AVANT de valider obligerait à
 * faire attendre le joueur à chaque coup, le temps d'interroger le moteur.
 * L'alerte arrive donc juste après, et propose de REPRENDRE — ce qui suppose
 * que reprendre soit possible, d'où le lien avec [PlayViewModel.canTakeback].
 */
sealed class BlunderSeverity {
    /** Le coup laisse passer un mat forcé qu'on avait. */
    data object MissedMate : BlunderSeverity()

    /** Le coup concède un mat forcé à l'adversaire. */
    data object AllowsMate : BlunderSeverity()

    /** Perte d'évaluation en centipions — le cas courant. */
    data class Centipawns(val drop: Int) : BlunderSeverity()
}

/**
 * La décision, isolée du moteur pour être vérifiable telle quelle.
 *
 * Le barème est celui d'iOS, et il tient en deux couches :
 *
 * **A — ce que le coup coûte**, mesuré en PROBABILITÉ DE GAIN et non en
 * centipions bruts : perdre deux pions à +8 ne change presque rien, à
 * l'équilibre c'est décisif. C'est la même échelle que la classification
 * d'après-partie, si bien que ce qui prévient PENDANT est ce qui sera étiqueté
 * « gaffe » APRÈS.
 *
 * **B — si la partie se joue encore.** Sous 25 % avant le coup, elle était déjà
 * largement compromise : un pas de plus vers le fond n'est pas une alerte
 * utile. Au-dessus de 75 % après, elle reste clairement gagnée : inutile de
 * proposer de reprendre.
 */
object BlunderAlert {

    /**
     * Ce que vaut un MAT en centipions. Pendant d'`EngineScore.mateCentipawns`
     * (iOS), et même valeur.
     *
     * Le moteur annonce « score mate N » OU « score cp N », jamais les deux :
     * sur un mat, le champ `cp` est simplement ABSENT. Le ramener à zéro — ce
     * que faisaient les trois modes de variante — place la position à 50 % de
     * probabilité de gain, c'est-à-dire à l'égalité, alors qu'elle est gagnée
     * ou perdue. L'alerte prévenait alors sur le MEILLEUR coup de la position :
     * celui qui force le mat, et celui qui sort d'un mat subi.
     */
    const val MATE_CENTIPAWNS = 10_000

    /**
     * L'éval d'une sonde ramenée en centipions, mat compris.
     *
     * À employer par tout appelant de [severity] : c'est le seul endroit où la
     * convention est écrite, et la seule façon de ne pas la retrouver recopiée
     * de travers dans un quatrième mode.
     */
    fun centipawns(cp: Int?, mate: Int?): Int? =
        cp ?: mate?.let { if (it > 0) MATE_CENTIPAWNS else -MATE_CENTIPAWNS }

    /** Seuil de perte de probabilité de gain, en points de pourcentage. */
    const val RISKY_MOVE_WIN_LOSS_THRESHOLD = 15.0

    /** Sous cette probabilité AVANT le coup, la partie était déjà perdue. */
    const val CONTESTED_FLOOR = 25.0

    /** Au-dessus de cette probabilité APRÈS le coup, elle reste gagnée. */
    const val CONTESTED_CEILING = 75.0

    /**
     * @param beforeCp éval de la position AVANT le coup, POV de celui qui joue.
     * @param afterCp éval de la position APRÈS, POV de l'ADVERSAIRE (nouveau
     *   trait) — d'où l'inversion de signe plus bas.
     *
     * `beforeCp` est déjà l'éval du MEILLEUR coup, puisque le score d'une
     * position est sa valeur sous le meilleur jeu : la perte se mesure donc
     * d'emblée par rapport à l'optimum.
     */
    fun severity(
        beforeCp: Int, beforeMate: Int?,
        afterCp: Int, afterMate: Int?,
    ): BlunderSeverity? {
        if (afterMate != null && afterMate > 0) {
            // Sauf si l'adversaire avait DÉJÀ un mat forcé avant le coup :
            // aucun coup ne pouvait l'éviter, et l'alerte se redéclencherait
            // à chaque coup d'une position perdue avec mat annoncé.
            if (beforeMate != null && beforeMate < 0) return null
            return BlunderSeverity.AllowsMate
        }
        if (beforeMate != null && beforeMate > 0) {
            // On AVAIT un mat forcé : s'il tient encore (l'adversaire est au
            // trait en train de se faire mater), pas d'alerte.
            if (afterMate != null && afterMate < 0) return null
            return BlunderSeverity.MissedMate
        }

        val winBefore = EvalConversion.fromCentipawns(beforeCp)
        val winAfter = EvalConversion.fromCentipawns(-afterCp)
        val loss = winBefore - winAfter

        if (winBefore <= CONTESTED_FLOOR || winAfter >= CONTESTED_CEILING) return null
        if (loss < RISKY_MOVE_WIN_LOSS_THRESHOLD) return null

        // Le MESSAGE reste en pions — plus parlant qu'un pourcentage de
        // probabilité de gain — et c'est la perte réelle par rapport au
        // meilleur coup.
        return BlunderSeverity.Centipawns(beforeCp - (-afterCp))
    }
}
