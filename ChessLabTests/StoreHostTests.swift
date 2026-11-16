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

    // MARK: L'échange

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func reopen_replacesTheBase_savesFirst_andKeepsTheData() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let host = StoreHost()
        host.install(try makeContainer(at: directory), open: { try! self.makeContainer(at: directory) })
        var releases = 0, openings = 0
        host.willRelease = { releases += 1 }
        host.didOpen = { _ in openings += 1 }
        do {
            let record = GameRecord()
            record.whiteName = "Pas encore enregistrée"   // l'échange enregistre d'abord
            host.container?.mainContext.insert(record)
        }
        weak var first = host.container

        #expect(await host.reopen(towardCloud: true, releaseTimeout: .seconds(2)))
        #expect(first == nil, "l'ancienne base doit être libérée avant d'ouvrir la nouvelle")
        #expect(host.switching == nil)
        #expect((releases, openings) == (1, 1))
        let records = try #require(host.container).mainContext.fetch(FetchDescriptor<GameRecord>())
        #expect(records.map(\.whiteName) == ["Pas encore enregistrée"])
    }

    /// Le filet : quelque chose tient encore l'ancienne base (un import, une autre fenêtre…) — on n'en
    /// ouvre PAS une seconde sur les mêmes fichiers, on garde l'ancienne.
    @Test func reopen_keepsTheOldBase_whenSomethingStillHoldsIt() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let host = StoreHost()
        var openedAgain = false
        host.install(try makeContainer(at: directory), open: {
            openedAgain = true
            return try! self.makeContainer(at: directory)
        })
        let holder = host.container

        #expect(await host.reopen(towardCloud: true, releaseTimeout: .milliseconds(300)) == false)
        #expect(host.container === holder)
        #expect(!openedAgain, "aucune seconde base ne doit avoir été ouverte")
        #expect(host.switching == nil)
    }
}
