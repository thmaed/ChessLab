import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// A1 (2.0) — le service d'analyse automatique, de bout en bout : une partie
/// rangée, mise en file, ressort avec son bilan chiffré. Opt-in (moteur réel).
@MainActor
@Suite(.serialized)
struct AutoAnalysisServiceTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: GameRecord.self, Puzzle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func analyzesQueuedGameAndWritesMetrics() async throws {
        let container = Self.container
        let context = container.mainContext
        let pgn = "[Event \"A1\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 7. Qf3+ Ke6 8. Nc3 Ncb4 9. O-O c6 10. d4 1-0"
        let game = try #require(PGNLoader.game(from: pgn))
        let key = try #require(AnalysisEvalStore.key(for: game))
        let record = GameRecord()
        record.pgn = pgn
        record.analysisKey = key
        context.insert(record)

        AppSettings.shared.autoAnalysisChoice = .on
        let service = AutoAnalysisService.shared
        service.enqueue(pgn: pgn, key: key, context: context)
        #expect(service.queue.count == 1)

        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline, record.analysisVersion == nil {
            try await Task.sleep(for: .milliseconds(500))
        }
        #expect(record.analysisVersion != nil)
        #expect(record.whiteAccuracy != nil)
        try await Task.sleep(for: .seconds(2))
        #expect(service.queue.isEmpty)
        AppSettings.shared.autoAnalysisChoice = .off
    }

    /// A2 : les fautes de l'utilisateur (et d'elles seules) deviennent des
    /// puzzles « Mes parties », trois au plus.
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
        context.insert(record)

        AppSettings.shared.autoAnalysisChoice = .on
        let service = AutoAnalysisService.shared
        service.acknowledgeNewPuzzles()
        service.enqueue(pgn: pgn, key: key, userColor: .white, context: context)
        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline, record.analysisVersion == nil || !service.queue.isEmpty {
            try await Task.sleep(for: .milliseconds(500))
        }
        let puzzles = try context.fetch(FetchDescriptor<Puzzle>())
        #expect(!puzzles.isEmpty)
        #expect(puzzles.count <= AutoAnalysisService.maxPuzzlesPerGame)
        #expect(puzzles.allSatisfy { $0.sourceRaw == PuzzleSource.ownGames.rawValue })
        // Aucun puzzle ne part d'une position où les Noirs avaient le trait.
        #expect(puzzles.allSatisfy { ($0.fen ?? "").contains(" w ") })
        #expect(service.newPuzzleCount == puzzles.count)
        service.acknowledgeNewPuzzles()
        AppSettings.shared.autoAnalysisChoice = .off
    }

    /// Le conflit de fin de partie : l'utilisateur ouvre l'analyse pendant que
    /// l'arrière-plan travaille. L'écran doit obtenir son moteur (le process est
    /// unique), finir sa classification, et le service reprendre ensuite.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ENGINE_INTEGRATION"] == "1"))
    func yieldsEngineToUserAnalysisThenResumes() async throws {
        let context = Self.container.mainContext
        let pgn = "[Event \"A1c\"]\n[Result \"1-0\"]\n\n1. e4 e5 2. Nf3 Nc6 3. d4 exd4 4. Nxd4 Bc5 5. Be3 Nxd4 6. Bxd4 Bxd4 7. Qxd4 Nf6 8. e5 Qe7 9. Be2 c5 10. exf6 Qxe2+ 11. Kxe2 cxd4 12. fxg7 Rg8 13. Rd1 d5 14. Rxd4 Be6 15. Nd2 Rc8 16. c3 Rxg7 17. g3 Rg5 18. Nf1 Ke7 1-0"
        let game = try #require(PGNLoader.game(from: pgn))
        let key = try #require(AnalysisEvalStore.key(for: game))
        let record = GameRecord()
        record.pgn = pgn
        record.analysisKey = key
        context.insert(record)

        AppSettings.shared.autoAnalysisChoice = .on
        let service = AutoAnalysisService.shared
        service.enqueue(pgn: pgn, key: key, context: context)
        // Laisse l'arrière-plan s'engager dans la partie.
        try await Task.sleep(for: .seconds(1))

        // L'utilisateur ouvre l'analyse d'une AUTRE position (cache vierge) : il
        // lui faut le moteur tout de suite.
        let other = "[Event \"U\"]\n[Result \"*\"]\n\n1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 *"
        let user = AnalysisViewModel(source: .pgn(other))
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline, user.moveEvaluations.count < 8, !user.isEngineUnavailable {
            try await Task.sleep(for: .milliseconds(300))
        }
        #expect(!user.isEngineUnavailable)
        #expect(user.moveEvaluations.count >= 8)
        user.handleViewDisappear()

        // Il rend le moteur : le service reprend, et termine la partie.
        let resume = Date().addingTimeInterval(240)
        while Date() < resume, record.analysisVersion == nil || !service.queue.isEmpty {
            try await Task.sleep(for: .milliseconds(500))
        }
        #expect(record.analysisVersion != nil)
        AppSettings.shared.autoAnalysisChoice = .off
    }

    @Test func refusesWhenNotAccepted() throws {
        let container = Self.container
        AppSettings.shared.autoAnalysisChoice = .undecided
        let service = AutoAnalysisService.shared
        service.enqueue(pgn: "1. e4 e5 *", key: "k-refused", context: container.mainContext)
        #expect(service.queue.isEmpty)
    }
}
