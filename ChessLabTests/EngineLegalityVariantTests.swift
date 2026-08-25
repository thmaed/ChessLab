import ChessKit
import Testing
@testable import ChessLab

/// Tests PURS de ``EngineLegalityVariant/outcome(afterFEN:legalMovesForNextMover:inCheck:)``
/// — aucun moteur : FEN et listes de coups légaux construits à la main, en
/// miroir de ce que ``FairyEngineController`` renverrait dans chaque cas.
@Suite
struct EngineLegalityVariantTests {

    // MARK: Course des rois

    @Test("Course des rois : un seul roi en 8e rangée, victoire immédiate")
    func racingKingsSingleWinner() {
        let fen = "K7/8/8/8/8/8/8/k7 b - - 0 1"
        let outcome = EngineLegalityVariant.racingKings.outcome(afterFEN: fen, legalMovesForNextMover: [], inCheck: false)
        #expect(outcome == GameOutcome(winner: .white, reason: .racingKingsGoal))
    }

    @Test("Course des rois : les deux rois en 8e rangée, nulle")
    func racingKingsBothArrive() {
        let fen = "K6k/8/8/8/8/8/8/8 b - - 0 1"
        let outcome = EngineLegalityVariant.racingKings.outcome(afterFEN: fen, legalMovesForNextMover: [], inCheck: false)
        #expect(outcome == GameOutcome(winner: nil, reason: .racingKingsDraw))
    }

    @Test("Course des rois : coups encore possibles, la partie continue")
    func racingKingsOngoing() {
        let fen = "8/1K6/8/8/8/8/8/k7 b - - 0 1"
        let outcome = EngineLegalityVariant.racingKings.outcome(
            afterFEN: fen, legalMovesForNextMover: ["a1a2"], inCheck: false
        )
        #expect(outcome == nil)
    }

    // MARK: Antéchecs

    @Test("Antéchecs : plus aucun coup, le camp bloqué GAGNE")
    func antichessStuckWins() {
        let fen = "8/8/8/8/8/8/8/k6K b - - 0 1"
        let outcome = EngineLegalityVariant.antichess.outcome(afterFEN: fen, legalMovesForNextMover: [], inCheck: false)
        #expect(outcome == GameOutcome(winner: .black, reason: .antichessStuck))
    }

    @Test("Antéchecs : coups disponibles, la partie continue")
    func antichessOngoing() {
        let fen = "8/8/8/8/8/8/8/k6K b - - 0 1"
        let outcome = EngineLegalityVariant.antichess.outcome(
            afterFEN: fen, legalMovesForNextMover: ["a1a2"], inCheck: false
        )
        #expect(outcome == nil)
    }

    // MARK: Atomique

    @Test("Atomique : un roi manquant, victoire immédiate — même si des coups restent")
    func atomicExplodedKingWinsImmediately() {
        let fen = "8/8/8/8/8/8/8/k7 b - - 0 1" // roi blanc absent
        let outcome = EngineLegalityVariant.atomic.outcome(
            afterFEN: fen, legalMovesForNextMover: ["a1a2"], inCheck: false
        )
        #expect(outcome == GameOutcome(winner: .black, reason: .atomicKingExploded))
    }

    @Test("Atomique : plus de coup, en échec — mat classique")
    func atomicCheckmate() {
        let fen = "8/8/8/8/8/8/8/kK6 b - - 0 1"
        let outcome = EngineLegalityVariant.atomic.outcome(afterFEN: fen, legalMovesForNextMover: [], inCheck: true)
        #expect(outcome == GameOutcome(winner: .white, reason: .checkmate))
    }

    @Test("Atomique : plus de coup, pas en échec — pat")
    func atomicStalemate() {
        let fen = "8/8/8/8/8/8/8/kK6 b - - 0 1"
        let outcome = EngineLegalityVariant.atomic.outcome(afterFEN: fen, legalMovesForNextMover: [], inCheck: false)
        #expect(outcome == GameOutcome(winner: nil, reason: .draw(.stalemate)))
    }

    @Test("Atomique : coups disponibles, deux rois intacts — la partie continue")
    func atomicOngoing() {
        let fen = "8/8/8/8/8/8/8/kK6 b - - 0 1"
        let outcome = EngineLegalityVariant.atomic.outcome(
            afterFEN: fen, legalMovesForNextMover: ["a1a2"], inCheck: false
        )
        #expect(outcome == nil)
    }
}
