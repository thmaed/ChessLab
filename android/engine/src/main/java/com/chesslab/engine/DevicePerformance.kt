package com.chesslab.engine

import android.app.ActivityManager
import android.content.Context

/**
 * Ce que l'appareil peut donner, pour dimensionner le moteur au plus juste.
 * Pendant de `DevicePerformance.swift`.
 *
 * L'analyse va CHERCHER plus de profondeur sur les appareils modernes, qui
 * l'encaissent dans le temps imparti, et reste sobre en bas de gamme. Un
 * budget unique servirait mal les deux : trop lourd d'un côté, trop timide de
 * l'autre.
 *
 * Le palier s'indexe sur la mémoire, bon indicateur de génération. Lu une
 * fois : il ne change pas pendant la session.
 */
object DevicePerformance {

    enum class Tier { low, mid, high }

    @Volatile private var cached: Tier? = null

    fun tier(context: Context): Tier = cached ?: run {
        val am = context.applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val info = ActivityManager.MemoryInfo().also { am?.getMemoryInfo(it) }
        val gigabytes = info.totalMem / 1_073_741_824.0
        val value = when {
            gigabytes >= 7.5 -> Tier.high
            gigabytes >= 5.5 -> Tier.mid
            else -> Tier.low
        }
        cached = value
        value
    }

    /**
     * Le budget de NŒUDS d'une position de classification, hors ouverture.
     *
     * Volontairement MODÉRÉ, orienté VITESSE : la revue d'une partie doit
     * passer tous les coups en quelques dizaines de secondes puis s'arrêter.
     * On ne cherche PAS la profondeur maximale — au-delà, ça consomme sans
     * rien apporter à la classification.
     */
    fun classificationNodes(context: Context): Long = when (tier(context)) {
        Tier.low -> 180_000
        Tier.mid -> 240_000
        Tier.high -> 300_000
    }

    /**
     * Le plafond de TEMPS par position : un filet de sécurité pour quand une
     * position est dure et que le débit chute. Serré, pour garder la passe
     * rapide.
     */
    fun classificationCapMs(context: Context): Int = when (tier(context)) {
        Tier.low -> 1_200
        Tier.mid -> 1_400
        Tier.high -> 1_600
    }

    /**
     * Le plafond de la recherche d'AFFINAGE. Plus large que celui de la passe
     * de base : appliquer le même tronquerait la recherche approfondie au
     * point de la rendre inutile — on paierait l'attente sans gagner la
     * précision.
     */
    fun refinementCapMs(context: Context): Int = classificationCapMs(context) * 4

    /**
     * La profondeur cible de l'analyse EN CONTINU — exploration d'une position
     * seulement, jamais en revue de partie. Modérée, pour ne pas faire
     * chauffer inutilement.
     */
    fun liveDepth(context: Context): Int = when (tier(context)) {
        Tier.low -> 18
        Tier.mid -> 20
        Tier.high -> 22
    }
}
