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
            for: GameRecord.self,
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

    @Test func refusesWhenNotAccepted() throws {
        let container = Self.container
        AppSettings.shared.autoAnalysisChoice = .undecided
        let service = AutoAnalysisService.shared
        service.enqueue(pgn: "1. e4 e5 *", key: "k-refused", context: container.mainContext)
        #expect(service.queue.isEmpty)
    }
}
