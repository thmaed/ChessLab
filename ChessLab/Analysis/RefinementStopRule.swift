import Foundation

/// Décide quand une recherche d'AFFINAGE peut s'arrêter avant son budget :
/// « trois niveaux » obtenus à l'intérieur d'une seule recherche.
///
/// ## D'où vient cette règle
///
/// Étude du 18/08 (simulée sur 887 coups réels, quatre budgets) : une cascade de
/// recherches 300 k → 1 M → 3 M est DOMINÉE par le système actuel, parce que
/// chaque redémarrage repaie l'arbre entier (mesuré ×13, pas ×10). Mais 47 %
/// des affinages étaient déjà stables à 1 M nœuds : la même économie
/// s'obtient en laissant courir UNE recherche de 3 M et en l'arrêtant
/// (`stop` UCI) dès qu'elle a tranché — l'arbre n'est jamais repayé,
/// puisqu'on ne quitte jamais la recherche.
///
/// ## Le critère, volontairement conservateur
///
/// On ne s'arrête que si TOUT est réuni :
/// 1. au moins ``nodesFloor`` nœuds cherchés (pas d'arrêt sur une impression) ;
/// 2. l'évaluation n'a pas bougé de plus de ``stableDeltaWinPercent`` points
///    de probabilité de gain sur ``stableTransitionsRequired`` changements de
///    profondeur consécutifs — la recherche ne découvre plus rien ;
/// 3. le verdict provisoire est à plus de ``boundaryClearance`` de toute
///    frontière de signalement — même si l'éval bougeait encore d'un cheveu,
///    l'étiquette ne changerait pas.
///
/// Rater un arrêt possible coûte quelques secondes ; s'arrêter à tort coûte
/// un verdict — d'où l'asymétrie des réglages.
struct RefinementStopRule {

    var nodesFloor: Int = 1_000_000
    var stableDeltaWinPercent: Double = 0.5
    var stableTransitionsRequired: Int = 2
    var boundaryClearance: Double = 1.0

    private var lastDepth = -1
    private var lastWinPercent: Double?
    private var stableTransitions = 0

    /// À appeler à chaque ligne `info` de la PV n°1 portant un score.
    ///
    /// - Parameters:
    ///   - depth: profondeur annoncée (les répétitions d'une même profondeur
    ///     sont ignorées : seul un CHANGEMENT de profondeur atteste que la
    ///     précédente est complète).
    ///   - nodes: nœuds cherchés (absent sur certaines lignes → pas d'arrêt).
    ///   - winPercent: éval convertie en probabilité de gain (0...100),
    ///     n'importe quel point de vue tant qu'il est CONSTANT.
    ///   - lossDistance: distance du verdict provisoire à la frontière de
    ///     signalement la plus proche (points de %).
    /// - Returns: `true` = la recherche peut être arrêtée sans risque.
    mutating func shouldStop(
        depth: Int, nodes: Int?, winPercent: Double, lossDistance: Double
    ) -> Bool {
        guard depth > lastDepth else { return false }
        lastDepth = depth

        if let previous = lastWinPercent {
            if abs(winPercent - previous) <= stableDeltaWinPercent {
                stableTransitions += 1
            } else {
                stableTransitions = 0
            }
        }
        lastWinPercent = winPercent

        guard let nodes, nodes >= nodesFloor else { return false }
        return stableTransitions >= stableTransitionsRequired
            && lossDistance > boundaryClearance
    }
}
