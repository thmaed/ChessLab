import Testing
@testable import ChessLab

struct GamePhaseAndDifficultyTests {

    @Test func classifiesEarlyPositionAsOpening() {
        // Après 1.e4 : tout le matériel encore présent, coup n°1.
        let phase = GamePhaseClassifier.classify(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
        #expect(phase == .opening)
    }

    @Test func classifiesQueenAndMinorsPositionAsMiddlegame() {
        let phase = GamePhaseClassifier.classify(
            fen: "r2q1rk1/pb2ppbp/1pn3p1/2p1n3/Q7/2P2NP1/PP1N1PBP/R1B1R1K1 w - - 0 14"
        )
        #expect(phase == .middlegame)
    }

    @Test func classifiesQueenlessSparsePositionAsEndgame() {
        let phase = GamePhaseClassifier.classify(fen: "8/p1k5/1p2p3/PPK1Pp1p/8/6P1/7P/8 w - - 0 33")
        #expect(phase == .endgame)
    }

    @Test func classifiesRookEndgameAsEndgame() {
        // Dames absentes, une tour de chaque côté : peu de pièces
        // majeures/mineures restantes malgré la présence de tours.
        let phase = GamePhaseClassifier.classify(fen: "8/4R3/1p2P3/p4r2/P6p/1P3Pk1/4K3/8 w - - 1 64")
        #expect(phase == .endgame)
    }

    @Test func fallsBackToMiddlegameForInvalidFEN() {
        #expect(GamePhaseClassifier.classify(fen: "not a fen") == .middlegame)
    }

    @Test func mapsRatingsToExpectedTiers() {
        #expect(DifficultyTier.tier(forRating: 600) == .beginner)
        #expect(DifficultyTier.tier(forRating: 1199) == .beginner)
        #expect(DifficultyTier.tier(forRating: 1200) == .intermediate)
        #expect(DifficultyTier.tier(forRating: 1599) == .intermediate)
        #expect(DifficultyTier.tier(forRating: 1600) == .advanced)
        #expect(DifficultyTier.tier(forRating: 1999) == .advanced)
        #expect(DifficultyTier.tier(forRating: 2000) == .expert)
        #expect(DifficultyTier.tier(forRating: 2400) == .expert)
    }

    @Test func returnsNilTierForNilRating() {
        #expect(DifficultyTier.tier(forRating: nil) == nil)
    }
}
