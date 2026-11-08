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

    // MARK: Fourchettes — retour de Ron (08/11/2026) : sur douze « fourchettes » de son
    // fichier, cinq n'en étaient pas (une pièce qui prend et vise deux pièces PROTÉGÉES).

    @Test func aForkNeedsRealTargets() {
        // Dame b7 prise : elle vise une dame et une tour, TOUTES DEUX PROTÉGÉES, et la
        // dame adverse peut la reprendre. Pas une fourchette.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "r4rk1/pbqn1ppp/1p1bp3/2p1N3/2PPQ3/6P1/PP3PBP/R1B1R1K1 w - - 0 14",
            solutionLANs: ["e4b7"]
        ) == .tactic)
        // Tour c4 : elle vise deux pièces protégées. Pas une fourchette non plus.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "b1r5/p1r3k1/1p2pq1p/6p1/1PpbPpP1/1Q1P1B1P/2R1NPK1/2R5 w - - 0 31",
            solutionLANs: ["c2c4"]
        ) == .tactic)
    }

    @Test func aForkWithUndefendedTargetsIsStillAFork() {
        // Dame b5 : elle vise un fou et une tour SANS DÉFENSE.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "4r1k1/1b3p1p/3p2pb/1p1P4/4P3/P2Q2NP/3B1PP1/3q1NK1 w - - 7 29",
            solutionLANs: ["d3b5"]
        ) == .fork)
        // Pion c5 : il attaque une dame sans défense et un cavalier.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "2r1r1k1/2p1qppp/pp1n4/8/1Q1N4/1P1RP2P/P4PP1/3R2K1 b - - 1 24",
            solutionLANs: ["c7c5"]
        ) == .fork)
    }

    @Test func theKingInCheckCountsAsATarget() {
        // Cavalier d5-c7+ : échec au roi e8 ET attaque de la tour a8.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "r3k3/8/8/3N4/8/8/8/4K3 w - - 0 1",
            solutionLANs: ["d5c7"]
        ) == .fork)
    }

    @Test func aForkerThatCanBeTakenForFreeIsNoFork() {
        // Cavalier e6 attaque dame et tour, mais le pion f7 le prend : fourchette réfutée.
        #expect(PuzzleThemeDetector.detect(
            startFEN: "3q2k1/2r2p2/8/2N5/8/8/8/4K3 w - - 0 1",
            solutionLANs: ["c5e6"]
        ) == .tactic)
    }
}
