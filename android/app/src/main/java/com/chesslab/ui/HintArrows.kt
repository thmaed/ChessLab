package com.chesslab.ui

import androidx.compose.ui.graphics.Color
import chesskit.Square
import kotlin.math.max
import kotlin.math.min

/**
 * Les flèches d'indice, construites depuis les lignes MultiPV du moteur.
 * Pendant de `HintMoveBuilder` (`HintMove.swift`).
 *
 * **UNE À TROIS flèches, et leur teinte dit leur force.** Un indice qui ne
 * montrerait que le meilleur coup donne la solution ; trois flèches de même
 * poids ne disent pas laquelle vaut mieux. iOS a tranché ainsi : les trois
 * premiers choix du moteur, mais seulement tant qu'ils restent PROCHES du
 * meilleur — une position sans vraie alternative n'affiche donc qu'une ou deux
 * flèches — et chacune est d'autant plus sombre, opaque et épaisse qu'elle est
 * forte.
 */
object HintArrowBuilder {

    /**
     * Écart maximal (en centipions) toléré par rapport au meilleur coup pour
     * qu'une ligne secondaire mérite encore sa flèche. Au-delà, le coup est
     * jugé nettement inférieur et n'est pas suggéré.
     */
    const val MAX_GAP_CP = 120.0

    /**
     * Réduction de force minimale entre deux rangs consécutifs, même à
     * évaluation rigoureusement égale : deux flèches ne sont jamais rendues
     * identiques.
     */
    const val RANK_STRENGTH_STEP = 0.16

    /**
     * Réduction ADDITIONNELLE, proportionnelle à l'écart d'évaluation avec le
     * meilleur coup : des coups très proches n'ont qu'une petite variation de
     * taille, des coups nettement différents se distinguent bien.
     */
    const val GAP_STRENGTH_RANGE = 0.55

    /**
     * Le score d'une ligne, ramené en centipions comparables — mat compris, et
     * un mat en 1 bat un mat en 3. Même convention qu'iOS.
     */
    fun score(cp: Int?, mate: Int?): Double? = when {
        mate != null -> if (mate > 0) 10_000.0 - mate else -10_000.0 - mate
        cp != null -> cp.toDouble()
        else -> null
    }

    /**
     * Les flèches, du meilleur coup au troisième choix.
     *
     * [lanByRank] et [scoreByRank] sont indexés par le `multipv` du moteur (1
     * pour le meilleur), et les scores sont tous DU MÊME POINT DE VUE — celui
     * du camp au trait — puisqu'ils viennent de la même position.
     */
    fun build(lanByRank: Map<Int, String>, scoreByRank: Map<Int, Double>): List<BoardArrow> {
        val bestScore = scoreByRank[1] ?: return emptyList()
        val bestLan = lanByRank[1] ?: return emptyList()
        if (bestLan.length < 4) return emptyList()

        return (1..3).mapNotNull { rank ->
            val lan = lanByRank[rank] ?: return@mapNotNull null
            if (lan.length < 4) return@mapNotNull null
            val score = scoreByRank[rank] ?: return@mapNotNull null

            val gap = bestScore - score
            if (gap > MAX_GAP_CP) return@mapNotNull null

            val gapFactor = min(1.0, max(0.0, gap / MAX_GAP_CP))
            val strength = max(
                0.12,
                1 - RANK_STRENGTH_STEP * (rank - 1) - GAP_STRENGTH_RANGE * gapFactor,
            )
            BoardArrow(
                from = Square(lan.substring(0, 2)),
                to = Square(lan.substring(2, 4)),
                tint = tint(strength),
                strength = strength.toFloat(),
            )
        }
    }

    /**
     * La teinte d'une flèche d'indice : un gris d'autant plus SOMBRE que le
     * coup est fort (`Color(white:)` chez iOS). L'opacité, elle, est ajoutée
     * par [ArrowOverlay] à partir de la même force — iOS la calcule dans la
     * couleur, le résultat est le même à deux centièmes près.
     *
     * Le gris n'est pas un défaut de coloriste : les couleurs de sens sont
     * déjà prises — ambre pour le dernier coup, rouge pour l'échec et la
     * menace, vert pour l'accent, violet pour la rétrospective. Un indice
     * neutre ne se confond avec aucune d'elles, sur aucun thème de plateau.
     */
    fun tint(strength: Double): Color {
        val shade = (0.12 + (1 - strength) * 0.5).toFloat()
        return Color(shade, shade, shade)
    }
}
