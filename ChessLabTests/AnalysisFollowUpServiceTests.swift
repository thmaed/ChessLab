import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Les suites d'une analyse terminée (A2, A3) : les puzzles de vos erreurs et la sortie de répertoire,
/// une seule fois par partie. L'analyse automatique en arrière-plan a été retirée le 27/10/2026.
@MainActor
@Suite(.serialized)
struct AnalysisFollowUpServiceTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: GameRecord.self, Puzzle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    @Test func aGameIsProcessedOnlyOnce() {
        let name = "AnalysisFollowUpServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(!AnalysisFollowUpService.hasProcessed("k1", defaults: defaults))
        AnalysisFollowUpService.markProcessed("k1", defaults: defaults)
        AnalysisFollowUpService.markProcessed("k1", defaults: defaults)
        #expect(AnalysisFollowUpService.hasProcessed("k1", defaults: defaults))
        #expect(!AnalysisFollowUpService.hasProcessed("k2", defaults: defaults))
        // La mémoire reste bornée.
        for i in 0..<400 { AnalysisFollowUpService.markProcessed("g\(i)", defaults: defaults) }
        #expect((defaults.stringArray(forKey: "analysisFollowUp.done") ?? []).count == 300)
        #expect(AnalysisFollowUpService.hasProcessed("g399", defaults: defaults))
        #expect(!AnalysisFollowUpService.hasProcessed("g0", defaults: defaults))
    }

    @Test func aGameThatIsNotAnEngineGameHasNoFollowUp() async throws {
        let context = Self.container.mainContext
        let pgn = "[Event \"x\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 1-0"
        let game = try #require(PGNLoader.game(from: pgn))
        let key = try #require(AnalysisEvalStore.key(for: game))
        let record = GameRecord()
        record.pgn = pgn
        record.analysisKey = key
        record.modeRaw = GameRecordMode.imported.rawValue
        context.insert(record)
        let viewModel = AnalysisViewModel(source: .pgn(pgn))
        #expect(viewModel.userColorInRecordedGame(in: context) == nil)
    }

    /// A2 : les fautes de l'utilisateur (et d'elles seules) deviennent des puzzles « Mes parties »,
    /// trois au plus. Opt-in (moteur réel).
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func createsOwnPuzzlesFromUserMistakes() async throws {
        let context = Self.container.mainContext
        try context.delete(model: Puzzle.self)
        // Les Blancs (l'utilisateur) ratent Dxf7# au coup 4 : un mat manqué.
        let pgn = "[Event \"A2\"]\n[Result \"0-1\"]\n\n1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. d3 Nxh5 5. Bxf7+ Ke7 6. Nc3 Nf4 0-1"
        let game = try #require(PGNLoader.game(from: pgn))
        let key = try #require(AnalysisEvalStore.key(for: game))
        let record = GameRecord()
        record.pgn = pgn
        record.analysisKey = key
        record.modeRaw = GameRecordMode.vsEngine.rawValue
        record.engineColorRaw = Piece.Color.black.rawValue
        context.insert(record)

        let service = AnalysisFollowUpService.shared
        service.acknowledgeNewPuzzles()
        let viewModel = AnalysisViewModel(source: .pgn(pgn))
        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline, viewModel.analysisMetrics == nil {
            try await Task.sleep(for: .milliseconds(500))
        }
        await service.followUp(after: viewModel, context: context)
        let puzzles = try context.fetch(FetchDescriptor<Puzzle>())
        #expect(!puzzles.isEmpty)
        #expect(puzzles.count <= AnalysisFollowUpService.maxPuzzlesPerGame)
        #expect(puzzles.allSatisfy { $0.sourceRaw == PuzzleSource.ownGames.rawValue })
        #expect(puzzles.allSatisfy { ($0.fen ?? "").contains(" w ") })
        #expect(service.newPuzzleCount == puzzles.count)
        service.acknowledgeNewPuzzles()
        viewModel.handleViewDisappear()
    }
}
