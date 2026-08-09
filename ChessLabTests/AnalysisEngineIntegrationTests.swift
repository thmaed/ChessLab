import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Vérifie de bout en bout, avec le VRAI moteur vendorisé, que l'analyse d'une
/// partie jouée **classe tous les coups et remplit le cache** (revue), sans
/// jamais partir en analyse profonde continue.
///
/// ⚠️ **Opt-in** (`ENGINE_INTEGRATION=1`) : un seul Stockfish par process, et
/// d'autres tests en démarrent un. Lancer isolément :
/// `TEST_RUNNER_ENGINE_INTEGRATION=1 xcodebuild test … -only-testing:ChessLabTests/AnalysisEngineIntegrationTests`
@MainActor
struct AnalysisEngineIntegrationTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func classifyingAPlayedGameFillsTheCacheAndStaysInReview() async throws {
        var game = Game()
        var idx = game.startingIndex
        for san in ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O", "Be7"] {
            idx = game.make(move: san, from: idx)
        }
        let pgn = PGNExport.pgn(for: game)

        let viewModel = AnalysisViewModel(source: .pgn(pgn))
        #expect(viewModel.isGameReview, "partie jouée → REVUE")

        // Laisse la classification tourner, bornée à 90 s.
        let deadline = Date().addingTimeInterval(90)
        while viewModel.moveEvaluations.count < 10, !viewModel.isEngineUnavailable, Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        #expect(!viewModel.isEngineUnavailable, "le moteur doit rester disponible")
        #expect(viewModel.moveEvaluations.count >= 8,
                "la classification doit remplir le cache — \(viewModel.moveEvaluations.count)/10")
        #expect(!viewModel.isLiveAnalyzing, "une revue ne doit JAMAIS être en analyse profonde continue")

        viewModel.handleViewDisappear()
        // Laisse la libération du moteur se faire avant la fin du test.
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
