import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// La recherche des mats manqués de bout en bout, avec le VRAI moteur.
///
/// ⚠️ **Opt-in** (`ENGINE_INTEGRATION=1`), comme
/// ``AnalysisEngineIntegrationTests`` : un seul Stockfish par process.
/// `TEST_RUNNER_ENGINE_INTEGRATION=1 xcodebuild test … -only-testing:ChessLabTests/MissedMateScanIntegrationTests`
@MainActor
struct MissedMateScanIntegrationTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func findsTheMateTheWhitePlayerLetSlip() async throws {
        // Les Blancs ont 1.Te8+ Txe8 2.Txe8#, et jouent 1.Ta3 : la tour
        // d'e3 quitte la colonne, le mat s'évanouit.
        let start = try #require(Position(fen: "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23"))
        var game = Game(startingWith: start)
        var index = game.startingIndex
        for san in ["Ra3", "Rxa3"] {
            index = game.make(move: san, from: index)
        }
        let pgn = PGNExport.pgn(for: game)

        let container = try ModelContainer(
            for: Puzzle.self, PuzzleProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let viewModel = AnalysisViewModel(source: .pgn(pgn))

        let mates = await viewModel.findMissedMates(in: context)

        #expect(!viewModel.isEngineUnavailable)
        #expect(mates.count == 1, "un seul mat manqué attendu : \(mates)")
        let mate = try #require(mates.first)
        #expect(mate.mover == .white)
        #expect(mate.mateIn == 2)
        #expect(mate.moveNumber == 23)
        #expect(mate.playedMoveSAN == "Ra3")
        #expect(mate.solutionLANs.first == "e3e8")
        #expect(mate.solutionLANs.count == 3)

        // Proposé, puis accepté : un puzzle « Mat » de vos parties, une fois.
        #expect(viewModel.saveMissedMates(mates, in: context) == 1)
        #expect(viewModel.saveMissedMates(mates, in: context) == 0, "pas de doublon")
        let saved = try context.fetch(FetchDescriptor<Puzzle>())
        #expect(saved.count == 1)
        #expect(saved.first?.theme == .checkmate)
        #expect(saved.first?.source == .ownGames)

        // Déjà dans vos puzzles : la recherche ne le repropose plus.
        #expect(await viewModel.findMissedMates(in: context).isEmpty)

        viewModel.handleViewDisappear()
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
