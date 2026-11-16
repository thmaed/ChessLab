import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Le relancement INTÉRIEUR repose sur une hypothèse qu'il faut prouver avant tout : une base SwiftData
/// dont plus personne ne tient de référence est réellement LIBÉRÉE (sinon, en ouvrir une seconde sur les
/// mêmes fichiers ferait cohabiter deux piles — exactement ce qu'on s'interdit).
@MainActor
struct StoreHostTests {

    private func makeContainer(at directory: URL) throws -> ModelContainer {
        let config = ModelConfiguration(
            "Games", schema: Schema([GameRecord.self]),
            url: directory.appendingPathComponent("Games.store"), cloudKitDatabase: .none)
        return try ModelContainer(for: Schema([GameRecord.self]), configurations: [config])
    }

    @Test func aContainerNobodyHolds_isReleased_andItsDataReopens() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        weak var released: ModelContainer?
        do {
            let container = try makeContainer(at: directory)
            released = container
            let record = GameRecord()
            record.whiteName = "Avant l'échange"
            container.mainContext.insert(record)
            try container.mainContext.save()
            // Une lecture, comme le ferait un écran.
            _ = try container.mainContext.fetch(FetchDescriptor<GameRecord>())
        }
        for _ in 0..<30 where released != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(released == nil, "SwiftData doit relâcher une base que plus personne ne tient")

        let reopened = try makeContainer(at: directory)
        let records = try reopened.mainContext.fetch(FetchDescriptor<GameRecord>())
        #expect(records.map(\.whiteName) == ["Avant l'échange"])
    }
}
