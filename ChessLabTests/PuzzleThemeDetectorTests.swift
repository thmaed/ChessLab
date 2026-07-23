import Testing
@testable import ChessLab

struct PuzzleThemeDetectorTests {

    @Test func detectsCheckmate() {
        // Dame d1 vers d8 : mat du couloir, roi noir bloqué par ses
        // propres pions f7/g7/h7.
        let theme = PuzzleThemeDetector.detect(
            startFEN: "6k1/5ppp/8/8/8/8/8/3QK3 w - - 0 1",
            solutionLANs: ["d1d8"]
        )
        #expect(theme == .checkmate)
    }

    @Test func detectsHangingPieceCapture() {
        // Dame a1 capture un cavalier h8 non défendu (roi noir loin, en b8).
        let theme = PuzzleThemeDetector.detect(
            startFEN: "1k5n/8/8/8/8/8/8/Q3K3 w - - 0 1",
            solutionLANs: ["a1h8"]
        )
        #expect(theme == .hangingPiece)
    }

    @Test func detectsFork() {
        // Cavalier c5 vers e6 (coup calme, sans capture) : attaque à la
        // fois la dame d8 et la tour c7.
        let theme = PuzzleThemeDetector.detect(
            startFEN: "3q2k1/2r5/8/2N5/8/8/8/4K3 w - - 0 1",
            solutionLANs: ["c5e6"]
        )
        #expect(theme == .fork)
    }

    @Test func fallsBackToGenericTacticOtherwise() {
        let theme = PuzzleThemeDetector.detect(
            startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            solutionLANs: ["e2e4"]
        )
        #expect(theme == .tactic)
    }

    @Test func returnsTacticForInvalidFEN() {
        let theme = PuzzleThemeDetector.detect(startFEN: "not a fen", solutionLANs: ["e2e4"])
        #expect(theme == .tactic)
    }

    @Test func returnsTacticForEmptySolution() {
        let theme = PuzzleThemeDetector.detect(
            startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            solutionLANs: []
        )
        #expect(theme == .tactic)
    }
}
