import Foundation
import Testing
import ChessKit
@testable import ChessLab

/// Sonde : le coup de mat reçoit-il un verdict ? Sans lui, le bilan chiffré ne se complète jamais.
@MainActor
struct TerminalPositionClassificationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func theMatingMoveIsClassified() async throws {
        let pgn = "[Event \"x\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7# 1-0"
        let viewModel = AnalysisViewModel(source: .pgn(pgn))
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline, viewModel.analysisMetrics == nil, !viewModel.isEngineUnavailable {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        print("PROBE|classés \(viewModel.moveEvaluations.count)/7|metrics \(viewModel.analysisMetrics != nil)|indispo \(viewModel.isEngineUnavailable)")
        viewModel.handleViewDisappear()
        #expect(viewModel.analysisMetrics != nil)
    }
}

struct TerminalStateTests {
    @Test @MainActor func aMatedPositionIsCheckmateForTheSideToMove() throws {
        // Mat du berger : les Noirs sont au trait et maté.
        let mated = try #require(Position(fen: "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"))
        guard case let .checkmate(color) = AnalysisViewModel.terminalState(of: mated) else {
            Issue.record("mat non reconnu"); return
        }
        #expect(color == .black)
    }

    @Test @MainActor func stalemateAndOrdinaryPositionsAreNotMate() throws {
        let pat = try #require(Position(fen: "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))
        guard case .draw = AnalysisViewModel.terminalState(of: pat) else { Issue.record("pat non reconnu"); return }
        let start = Position.standard
        if case .checkmate = AnalysisViewModel.terminalState(of: start) { Issue.record("départ pris pour un mat") }
        let check = try #require(Position(fen: "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1"))
        if case .checkmate = AnalysisViewModel.terminalState(of: check) { Issue.record("échec simple pris pour un mat") }
    }
}
