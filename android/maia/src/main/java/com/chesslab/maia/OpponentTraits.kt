package com.chesslab.maia

import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Les quatre CARACTÉRISTIQUES d'un personnage, de 1 à 5, montrées en jauges (17/11/2026). Pendant de
 * `OpponentTraits.swift` : Attaque, Solidité, Échanges, Imprévisible.
 *
 * Rien d'inventé : chaque note se lit dans les réglages qui FONT jouer le personnage — les poids de son style
 * ([StyleProfile]) et sa température de tirage. Maia, sans style, est au milieu partout : c'est l'étalon.
 */
data class OpponentTraits(
    /** Cherche le roi adverse : échecs, pièces vers le roi, pions lancés, sacrifices. */
    val attack: Int,
    /** Roque, développe, évite les pions faibles et les sacrifices. */
    val solidity: Int,
    /** Aime échanger — les dames surtout — et ramasser le matériel ; 1 = évite les échanges. */
    val trades: Int,
    /** S'écarte du coup le plus humain : la température du tirage. */
    val unpredictability: Int,
) {
    private data class Raw(val attack: Double, val solidity: Double, val trades: Double)

    companion object {
        fun of(profile: OpponentProfile): OpponentTraits {
            val raw = raw(profile)
            return OpponentTraits(
                attack = centered(raw.attack, scale.attack),
                solidity = centered(raw.solidity, scale.solidity),
                trades = centered(raw.trades, scale.trades),
                unpredictability = when {
                    profile.temperature < 0.85 -> 1
                    profile.temperature < 0.95 -> 2
                    profile.temperature < 1.05 -> 3
                    profile.temperature < 1.3 -> 4
                    else -> 5
                },
            )
        }

        private fun raw(profile: OpponentProfile): Raw {
            fun weight(trait: StyleTrait) = profile.style.weights[trait] ?: 0.0
            return Raw(
                attack = weight(StyleTrait.check) + weight(StyleTrait.towardKing) + weight(StyleTrait.pawnStorm) +
                    weight(StyleTrait.sacrifice),
                solidity = weight(StyleTrait.castle) + weight(StyleTrait.development) - weight(StyleTrait.weakPawn) -
                    0.5 * weight(StyleTrait.sacrifice),
                trades = weight(StyleTrait.equalTrade) + weight(StyleTrait.queenTrade) + 0.5 * weight(StyleTrait.materialGain),
            )
        }

        /** Le plus grand écart de toute la galerie, par caractéristique : les notes se lisent les unes par rapport aux autres. */
        private val scale: Raw by lazy {
            val all = OpponentGallery.all.map(::raw)
            Raw(all.maxOf { abs(it.attack) }, all.maxOf { abs(it.solidity) }, all.maxOf { abs(it.trades) })
        }

        /** 3 = neutre ; ±2 au plus loin observé dans la galerie. Arrondi « au plus loin de zéro », comme Swift. */
        private fun centered(raw: Double, maxAbs: Double): Int {
            if (maxAbs <= 0) return 3
            val x = 3 + 2 * raw / maxAbs
            val rounded = if (x >= 0) kotlin.math.floor(x + 0.5) else -kotlin.math.floor(-x + 0.5)
            return rounded.roundToInt().coerceIn(1, 5)
        }
    }
}
