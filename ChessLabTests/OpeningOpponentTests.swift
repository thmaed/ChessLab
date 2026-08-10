import Testing
@testable import ChessLab

/// Générateur déterministe pour rendre le tirage pondéré reproductible.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

struct OpeningOpponentTests {

    private func edge(_ san: String, club: Double?) -> MoveEdge {
        MoveEdge(san: san, uci: "a1a2", toFEN: "x", role: .sideline, popularityClub: club)
    }

    @Test func alwaysPicksTheOnlyWeightedMove() {
        // Poids [1.0, 0, 0] : le tirage tombe toujours sur le premier.
        let node = PositionNode(fen: "n", moves: [edge("A", club: 1.0), edge("B", club: 0), edge("C", club: 0)])
        for seed in UInt64(0)..<20 {
            var rng = SeededRNG(seed: seed)
            #expect(OpeningOpponent.weightedReply(from: node, using: &rng)?.san == "A")
        }
    }

    @Test func fallsBackToUniformWhenNoWeights() {
        let node = PositionNode(fen: "n", moves: [edge("A", club: nil), edge("B", club: nil)])
        var rng = SeededRNG(seed: 3)
        #expect(OpeningOpponent.weightedReply(from: node, using: &rng) != nil)
    }

    @Test func emptyNodeReturnsNil() {
        var rng = SeededRNG(seed: 1)
        #expect(OpeningOpponent.weightedReply(from: PositionNode(fen: "n"), using: &rng) == nil)
    }

    @Test func favoursTheMorePopularMoveOverManyDraws() {
        let node = PositionNode(fen: "n", moves: [edge("A", club: 0.8), edge("B", club: 0.2)])
        var rng = SeededRNG(seed: 42)
        var a = 0
        let n = 4000
        for _ in 0..<n {
            if OpeningOpponent.weightedReply(from: node, using: &rng)?.san == "A" { a += 1 }
        }
        let ratio = Double(a) / Double(n)
        #expect(ratio > 0.74 && ratio < 0.86)   // ~0,8, avec marge
    }
}
