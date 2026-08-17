import Testing
@testable import ChessLab

/// La règle d'arrêt anticipé de l'affinage : conservatrice par construction —
/// rater un arrêt coûte des secondes, s'arrêter à tort coûte un verdict.
struct RefinementStopRuleTests {

    private func rule() -> RefinementStopRule {
        var r = RefinementStopRule()
        r.nodesFloor = 1_000_000
        return r
    }

    /// Contourne la limite du macro `#expect` sur les appels `mutating`.
    private func step(
        _ r: inout RefinementStopRule,
        depth: Int, nodes: Int?, winPercent: Double, lossDistance: Double
    ) -> Bool {
        r.shouldStop(depth: depth, nodes: nodes, winPercent: winPercent, lossDistance: lossDistance)
    }

    @Test func aStableClearSearchStopsAfterTwoQuietTransitions() {
        var r = rule()
        // Trois profondeurs d'accord (deux transitions calmes), plancher
        // atteint, verdict loin des frontières → stop.
        #expect(!step(&r, depth: 16, nodes: 600_000, winPercent: 62.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 17, nodes: 900_000, winPercent: 62.2, lossDistance: 4.0))
        #expect(step(&r, depth: 18, nodes: 1_200_000, winPercent: 62.1, lossDistance: 4.0))
    }

    @Test func aMovingEvalNeverStops() {
        var r = rule()
        #expect(!step(&r, depth: 16, nodes: 900_000, winPercent: 60.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 17, nodes: 1_200_000, winPercent: 63.0, lossDistance: 4.0))
        // Le saut de 3 points a remis le compteur à zéro : une seule
        // transition calme ne suffit pas.
        #expect(!step(&r, depth: 18, nodes: 1_500_000, winPercent: 63.1, lossDistance: 4.0))
        // Il en faut deux d'affilée.
        #expect(step(&r, depth: 19, nodes: 1_800_000, winPercent: 63.0, lossDistance: 4.0))
    }

    @Test func aVerdictNearTheBoundaryNeverStops() {
        var r = rule()
        #expect(!step(&r, depth: 16, nodes: 900_000, winPercent: 55.0, lossDistance: 0.4))
        #expect(!step(&r, depth: 17, nodes: 1_200_000, winPercent: 55.0, lossDistance: 0.4))
        // Stable ET plancher atteint, mais le verdict frôle la frontière :
        // c'est exactement le cas pour lequel l'affinage existe.
        #expect(!step(&r, depth: 18, nodes: 1_500_000, winPercent: 55.0, lossDistance: 0.4))
    }

    @Test func theNodesFloorIsRespected() {
        var r = rule()
        #expect(!step(&r, depth: 12, nodes: 200_000, winPercent: 70.0, lossDistance: 8.0))
        #expect(!step(&r, depth: 13, nodes: 400_000, winPercent: 70.0, lossDistance: 8.0))
        // Deux transitions calmes, loin des frontières — mais 600k nœuds :
        // trop tôt pour juger.
        #expect(!step(&r, depth: 14, nodes: 600_000, winPercent: 70.0, lossDistance: 8.0))
        #expect(step(&r, depth: 15, nodes: 1_100_000, winPercent: 70.0, lossDistance: 8.0))
    }

    @Test func repeatedDepthLinesAreIgnored() {
        var r = rule()
        #expect(!step(&r, depth: 16, nodes: 900_000, winPercent: 62.0, lossDistance: 4.0))
        // La même profondeur ré-annoncée (MultiPV, seconde ligne…) ne compte
        // pas comme une transition.
        #expect(!step(&r, depth: 16, nodes: 950_000, winPercent: 62.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 16, nodes: 990_000, winPercent: 62.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 17, nodes: 1_200_000, winPercent: 62.0, lossDistance: 4.0))
        #expect(step(&r, depth: 18, nodes: 1_500_000, winPercent: 62.0, lossDistance: 4.0))
    }

    @Test func missingNodeCountsNeverStop() {
        var r = rule()
        #expect(!step(&r, depth: 16, nodes: nil, winPercent: 62.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 17, nodes: nil, winPercent: 62.0, lossDistance: 4.0))
        #expect(!step(&r, depth: 18, nodes: nil, winPercent: 62.0, lossDistance: 4.0))
    }
}
