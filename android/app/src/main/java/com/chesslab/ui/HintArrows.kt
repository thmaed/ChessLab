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
     * menace, vert pour l'accent et pour la rétrospective. Un indice neutre
     * ne se confond avec aucune d'elles, sur aucun thème de plateau.
     */
    fun tint(strength: Double): Color {
        val shade = (0.12 + (1 - strength) * 0.5).toFloat()
        return Color(shade, shade, shade)
    }

    /**
     * La force d'une flèche de rang [rank], compte tenu de l'écart au meilleur
     * coup — ou `null` quand l'écart la disqualifie.
     *
     * Sortie du corps de [build] pour que l'analyse s'en serve sans passer par
     * les flèches : elle publie ses candidats avec leur force, et l'écran ne
     * dessine que ceux qui en ont une. C'est ainsi qu'iOS tient la promesse
     * « une position sans vraie alternative n'affiche qu'une ou deux flèches ».
     */
    fun strength(rank: Int, score: Double, bestScore: Double): Double? {
        val gap = bestScore - score
        if (gap > MAX_GAP_CP) return null
        val gapFactor = min(1.0, max(0.0, gap / MAX_GAP_CP))
        return max(0.12, 1 - RANK_STRENGTH_STEP * (rank - 1) - GAP_STRENGTH_RANGE * gapFactor)
    }

    /**
     * « Il fallait jouer ça » : la seule flèche qui porte sur la position
     * PRÉCÉDENTE. Vive et pleinement opaque — c'est l'information la plus
     * utile de l'écran quand elle apparaît.
     */
    val betterTint: Color get() = Palette.accent.copy(alpha = 0.9f)

    /**
     * Ce que l'ADVERSAIRE ferait si on lui laissait la main. Rouge TRANSLUCIDE :
     * elle ne se confond pas avec les flèches de coups à jouer, et ne prétend
     * pas non plus être une suggestion.
     */
    val threatTint: Color get() = Palette.danger.copy(alpha = 0.55f)

    /**
     * Le meilleur coup en REVUE d'une partie terminée : vert — et non le gris
     * de l'analyse en direct d'une position — gradué par la force, de sorte
     * que deux coups qui se valent donnent deux verts voisins.
     */
    fun reviewBestTint(strength: Double): Color =
        Palette.accent.copy(alpha = (0.5 + strength * 0.45).toFloat())
}
