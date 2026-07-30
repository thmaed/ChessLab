import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// - important: UN SEUL `ModelContainer` partagé + `.serialized` — créer
///   plusieurs conteneurs en mémoire dans le même process fait trapper
///   SwiftData. Voir `PuzzleProgressSyncTests` pour le détail.
@MainActor
@Suite(.serialized)
struct GameLibraryImportTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: GameRecord.self)
        try context.save()
        return context
    }

    private let twoGames = """
    [Event "Test A"]
    [White "Alice"]
    [Black "Bob"]
    [Result "1-0"]
    [Date "2024.05.01"]

    1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0

    [Event "Test B"]
    [White "Carol"]
    [Black "Dave"]
    [Result "1/2-1/2"]

    1. d4 d5 2. c4 e6 1/2-1/2
    """

    @Test func importsEveryGameWithItsHeaders() throws {
        let context = try makeContext()
        let outcome = GameLibraryService.importPGNCollection(text: twoGames, in: context)

        #expect(outcome.imported == 2)
        #expect(outcome.skipped == 0)

        let records = try context.fetch(
            FetchDescriptor<GameRecord>(sortBy: [SortDescriptor(\.whiteName)])
        )
        #expect(records.count == 2)
        let alice = try #require(records.first { $0.whiteName == "Alice" })
        #expect(alice.blackName == "Bob")
        #expect(alice.resultRaw == "1-0")
        #expect(alice.mode == .imported)
        #expect((alice.moveCount ?? 0) == 6)
    }

    @Test func skipsUnreadableBlocksButImportsTheRest() throws {
        let context = try makeContext()
        // Bloc bidon = son propre en-tête [Event ...] (clé de découpage) + un
        // mouvement illisible, pour qu'il forme un bloc distinct et échoue seul.
        let mixed = twoGames + "\n\n[Event \"Bad\"]\n\n1. zz9 not-a-move 42\n"
        let outcome = GameLibraryService.importPGNCollection(text: mixed, in: context)

        // Les deux parties valides passent ; le bloc bidon est compté à part.
        #expect(outcome.imported == 2)
        #expect(outcome.skipped >= 1)
        #expect(try context.fetchCount(FetchDescriptor<GameRecord>()) == 2)
    }

    @Test func resultStarBecomesNoResult() throws {
        let context = try makeContext()
        let ongoing = """
        [White "P1"]
        [Black "P2"]
        [Result "*"]

        1. e4 e5 *
        """
        _ = GameLibraryService.importPGNCollection(text: ongoing, in: context)
        let record = try #require(try context.fetch(FetchDescriptor<GameRecord>()).first)
        #expect(record.resultRaw == nil)
    }
}
