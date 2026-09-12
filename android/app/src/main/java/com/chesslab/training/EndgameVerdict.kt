package com.chesslab.training

import androidx.annotation.StringRes
import com.chesslab.R

/**
 * Le verdict théorique d'une position, DU POINT DE VUE DU CAMP AU TRAIT.
 * Pendant d'`EndgameVerdict`.
 */
enum class EndgameVerdict(@StringRes val labelRes: Int) {
    win(R.string.verdict_win),
    draw(R.string.verdict_draw),
    loss(R.string.verdict_loss);

    /** Le même verdict, vu de l'autre camp. */
    val flipped: EndgameVerdict
        get() = when (this) {
            win -> loss
            draw -> draw
            loss -> win
        }

    /** Pour comparer : perdant < nulle < gagnant. */
    val rank: Int get() = when (this) { loss -> 0; draw -> 1; win -> 2 }
}

/** Ce que l'arbitre sait dire d'une position : son verdict, et le meilleur coup. */
data class EndgameAssessment(val verdict: EndgameVerdict, val bestLan: String?)

/**
 * L'arbitre de l'entraînement libre. Pendant d'`EndgameVerdictJudging`.
 *
 * **Le seuil est le même qu'iOS : 250 centipions.** Ce n'est pas un verdict
 * PROUVÉ — une table de finales le prouverait, le moteur ne fait que vérifier,
 * et il est faillible aux frontières. L'app dit donc « vérifié au moteur » et
 * non « démontré ». Un fournisseur exact (tables Syzygy) se brancherait ici
 * sans toucher au reste ; c'est pour ça que c'est une interface.
 */
interface EndgameJudge {
    suspend fun assess(fen: String): EndgameAssessment?

    /** Le coup de la DÉFENSE dans cette position. */
    suspend fun reply(fen: String): String?
}

object EndgameVerdictRule {
    /** Au-delà, la position est tenue pour gagnée. En deçà de son opposé, perdue. */
    const val WIN_THRESHOLD_CP = 250

    fun verdict(cp: Int): EndgameVerdict = when {
        cp >= WIN_THRESHOLD_CP -> EndgameVerdict.win
        cp <= -WIN_THRESHOLD_CP -> EndgameVerdict.loss
        else -> EndgameVerdict.draw
    }

    /**
     * Le coup a-t-il LÂCHÉ quelque chose ?
     *
     * C'est toute la différence avec le mode guidé : on ne demande pas « est-ce
     * LE coup de la leçon ? » mais « ce coup préserve-t-il le verdict ? ». Tout
     * coup qui garde le gain est accepté, même s'il n'est pas le plus rapide.
     */
    fun isDegradation(before: EndgameVerdict, after: EndgameVerdict): Boolean =
        after.rank < before.rank
}
