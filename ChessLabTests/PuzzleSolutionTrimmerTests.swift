import Testing
@testable import ChessLab

struct PuzzleSolutionTrimmerTests {

    /// Un gain de pièce en un coup : la PV est tronquée au seul coup du
    /// résolveur, la queue (errance du roi adverse) est jetée.
    @Test func trimsToSingleWinningMove() {
        // Dame a1 capture le cavalier h8 non défendu (roi noir en b8, loin).
        let trimmed = PuzzleSolutionTrimmer.trim(
            pv: ["a1h8", "b8b7", "h8h7", "b7b6"],
            startFEN: "1k5n/8/8/8/8/8/8/Q3K3 w - - 0 1"
        )
        #expect(trimmed == ["a1h8"])
    }

    /// Le gain n'arrive qu'au 3e demi-coup (Ta8+ ... Rb7, Txh8) : la
    /// solution garde bien les trois demi-coups.
    @Test func keepsSequenceUntilMaterialWon() {
        let trimmed = PuzzleSolutionTrimmer.trim(
            pv: ["a1a8", "b8b7", "a8h8"],
            startFEN: "1k5n/8/8/8/8/8/8/R3K3 w - - 0 1"
        )
        #expect(trimmed == ["a1a8", "b8b7", "a8h8"])
    }

    /// Un mat coupe la solution même sans gain matériel décisif.
    @Test func trimsAtCheckmate() {
        // Mat du couloir Dd1-d8, roi noir bloqué par ses pions.
        let trimmed = PuzzleSolutionTrimmer.trim(
            pv: ["d1d8", "g8h7"],
            startFEN: "6k1/5ppp/8/8/8/8/8/3QK3 w - - 0 1"
        )
        #expect(trimmed == ["d1d8"])
    }

    /// Aucune tactique nette : plafond respecté ET la solution se termine
    /// sur un coup du résolveur (longueur impaire).
    @Test func capsAndEndsOnSolverMove() {
        let trimmed = PuzzleSolutionTrimmer.trim(
            pv: ["h1h2", "e8e7", "h2h3", "e7e6", "h3h4", "e6e5"],
            startFEN: "4k3/8/8/8/8/8/8/4K2R w K - 0 1"
        )
        #expect(trimmed.count == 5)
        #expect(trimmed == ["h1h2", "e8e7", "h2h3", "e7e6", "h3h4"])
    }
}
