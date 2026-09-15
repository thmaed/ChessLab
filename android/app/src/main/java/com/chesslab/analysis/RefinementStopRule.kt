package com.chesslab.analysis

/**
 * Décide quand une recherche d'AFFINAGE peut s'arrêter avant son budget :
 * « trois niveaux » obtenus à l'intérieur d'une seule recherche. Pendant de
 * `RefinementStopRule.swift`.
 *
 * ## D'où vient cette règle
 *
 * Étude du 18/08 (887 coups réels, quatre budgets) : une cascade de
 * recherches 300 k → 1 M → 3 M est DOMINÉE par le système actuel, parce que
 * chaque redémarrage repaie l'arbre entier (mesuré ×13, pas ×10). Mais 47 %
 * des affinages étaient déjà stables à 1 M nœuds : la même économie
 * s'obtient en laissant courir UNE recherche de 3 M et en l'arrêtant dès
 * qu'elle a tranché — l'arbre n'est jamais repayé, puisqu'on ne quitte
 * jamais la recherche.
 *
 * ## Le critère, volontairement conservateur
 *
 * On ne s'arrête que si TOUT est réuni :
 * 1. au moins [nodesFloor] nœuds cherchés (pas d'arrêt sur une impression) ;
 * 2. l'évaluation n'a pas bougé de plus de [stableDeltaWinPercent] points de
 *    probabilité de gain sur [stableTransitionsRequired] changements de
 *    profondeur consécutifs — la recherche ne découvre plus rien ;
 * 3. le verdict provisoire est à plus de [boundaryClearance] de toute
 *    frontière de signalement — même si l'éval bougeait encore d'un cheveu,
 *    l'étiquette ne changerait pas.
 *
 * Rater un arrêt possible coûte quelques secondes ; s'arrêter à tort coûte un
 * VERDICT — d'où l'asymétrie des réglages.
 */
class RefinementStopRule(
    var nodesFloor: Long = 1_000_000,
    val stableDeltaWinPercent: Double = 0.5,
    val stableTransitionsRequired: Int = 2,
    val boundaryClearance: Double = 1.0,
) {
    private var lastDepth = -1
    private var lastWinPercent: Double? = null
    private var stableTransitions = 0

    /**
     * À appeler à chaque ligne `info` de la PV n°1 portant un score.
     *
     * @param depth la profondeur annoncée. Les répétitions d'une même
     *   profondeur sont ignorées : seul un CHANGEMENT de profondeur atteste
     *   que la précédente est complète.
     * @param nodes les nœuds cherchés ; absent sur certaines lignes, et alors
     *   pas d'arrêt.
     * @param winPercent l'éval en probabilité de gain (0…100), de n'importe
     *   quel point de vue tant qu'il est CONSTANT.
     * @param lossDistance la distance du verdict provisoire à la frontière de
     *   signalement la plus proche, en points de %.
     * @return vrai quand la recherche peut être arrêtée sans risque.
     */
    fun shouldStop(depth: Int, nodes: Long?, winPercent: Double, lossDistance: Double): Boolean {
        if (depth <= lastDepth) return false
        lastDepth = depth

        val previous = lastWinPercent
        if (previous != null) {
            if (kotlin.math.abs(winPercent - previous) <= stableDeltaWinPercent) stableTransitions += 1
            else stableTransitions = 0
        }
        lastWinPercent = winPercent

        if (nodes == null || nodes < nodesFloor) return false
        return stableTransitions >= stableTransitionsRequired && lossDistance > boundaryClearance
    }
}
