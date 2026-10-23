import Testing
@testable import ChessLab

/// Les règles pures de la recherche des mats manqués — sans moteur.
struct MissedMateDetectorTests {

    /// Mat en deux du couloir, tours doublées : 1.Te8+ Txe8 2.Txe8#.
    private let doubledRooks = "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    @Test func keepsTheWholeLineUpToTheMate() {
        let line = MissedMateDetector.solution(pv: ["e3e8", "a8e8", "e1e8"], startFEN: doubledRooks)
        #expect(line == ["e3e8", "a8e8", "e1e8"])
    }

    @Test func cutsAtTheMateWhenTheEngineLineGoesOn() {
        let line = MissedMateDetector.solution(pv: ["a1a8", "g8h8", "a8b8"], startFEN: "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1")
        #expect(line == ["a1a8"])
    }

    @Test func rejectsALineThatDoesNotMate() {
        #expect(MissedMateDetector.solution(pv: ["e3e7", "a8a1"], startFEN: doubledRooks) == nil)
    }

    @Test func rejectsAnIllegalLine() {
        #expect(MissedMateDetector.solution(pv: ["e3e9"], startFEN: doubledRooks) == nil)
        #expect(MissedMateDetector.solution(pv: ["a8a1"], startFEN: doubledRooks) == nil)
    }

    /// Le mauvais camp au trait : refusé même si la suite matait.
    @Test func rejectsALineThatPlaysTheWrongSide() {
        #expect(MissedMateDetector.solution(pv: ["a1a8"], startFEN: "6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1") == nil)
    }

    /// Plus de ``MissedMateDetector/maxMateMoves`` coups du résolveur : la
    /// ligne est coupée avant le mat, donc refusée.
    @Test func rejectsAMateBeyondTheLimit() {
        // Rois et tours qui tournent sans mater : 9 demi-coups, aucun mat.
        let shuffle = ["e3e4", "a8a7", "e4e3", "a7a8", "e3e4", "a8a7", "e4e3", "a7a8", "e3e8", "a8e8", "e1e8"]
        #expect(MissedMateDetector.solution(pv: shuffle, startFEN: doubledRooks) == nil)
    }

    @Test func onlyDecisivePositionsAreSearched() {
        #expect(MissedMateDetector.mightHoldMate(winPercentForMover: 99.9))
        #expect(MissedMateDetector.mightHoldMate(winPercentForMover: 97))
        #expect(!MissedMateDetector.mightHoldMate(winPercentForMover: 90))
    }

    @Test func readsTheMoveNumberFromTheFEN() {
        #expect(MissedMateDetector.moveNumber(fen: doubledRooks) == 23)
        #expect(MissedMateDetector.moveNumber(fen: "8/8/8/8") == 1)
    }
}
