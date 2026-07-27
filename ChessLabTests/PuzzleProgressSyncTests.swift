import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// - important: UN SEUL `ModelContainer` pour tout le suite, `.serialized`.
///   Créer PLUSIEURS `ModelContainer` en mémoire dans le même process fait
///   trapper SwiftData (SIGTRAP dans son runtime) — chaque opération passe
///   pourtant seule, et un test isolé (un container par process) passe aussi ;
///   c'est la Nᵉ création de container qui casse. On partage donc un container
///   statique et on purge le store au début de chaque test (le suite est
///   sérialisé, donc pas d'entrelacement). Rien de tout ceci ne touche au code
///   applicatif — l'app ne crée qu'un container.
@MainActor
@Suite(.serialized)
struct PuzzleProgressSyncTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: Puzzle.self, PuzzleProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        // Repartir vierge : le container est partagé entre tests.
        try context.delete(model: Puzzle.self)
        try context.delete(model: PuzzleProgress.self)
        try context.save()
        return context
    }

    private func makeLichessPuzzle(externalID: String) -> Puzzle {
        let puzzle = Puzzle()
        puzzle.externalID = externalID
        return puzzle
    }

    @Test func mirrorCreatesASyncedRecordFromALichessPuzzle() throws {
        let context = try makeContext()
        let puzzle = makeLichessPuzzle(externalID: "abc12")
        puzzle.successCount = 3
        puzzle.failureCount = 1
        puzzle.repetitions = 2
        puzzle.easinessFactor = 2.6
        puzzle.intervalDays = 6
        context.insert(puzzle)
        try context.save()

        PuzzleProgressSync.mirror(puzzle, in: context)

        let records = try context.fetch(FetchDescriptor<PuzzleProgress>())
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.externalID == "abc12")
        #expect(record.successCount == 3)
        #expect(record.failureCount == 1)
        #expect(record.repetitions == 2)
        #expect(record.easinessFactor == 2.6)
        #expect(record.intervalDays == 6)
    }

    @Test func mirrorIgnoresOwnGamePuzzles() throws {
        let context = try makeContext()
        // Puzzle issu d'une partie de l'utilisateur : pas d'externalID.
        let puzzle = Puzzle()
        puzzle.successCount = 5
        context.insert(puzzle)
        try context.save()

        PuzzleProgressSync.mirror(puzzle, in: context)

        #expect(try context.fetchCount(FetchDescriptor<PuzzleProgress>()) == 0)
    }

    @Test func reconcileMergesSyncedProgressIntoTheLocalPuzzle() throws {
        let context = try makeContext()
        // Local en retard, progression synchronisée (autre appareil) en avance.
        let puzzle = makeLichessPuzzle(externalID: "abc12")
        puzzle.successCount = 1
        puzzle.failureCount = 0
        puzzle.repetitions = 0
        context.insert(puzzle)

        let progress = PuzzleProgress(externalID: "abc12")
        progress.successCount = 4
        progress.failureCount = 2
        progress.repetitions = 3
        progress.easinessFactor = 2.7
        progress.intervalDays = 15
        progress.dueDate = Date(timeIntervalSince1970: 2_000_000)
        context.insert(progress)
        try context.save()

        PuzzleProgressSync.reconcile(in: context)

        #expect(puzzle.successCount == 4)
        #expect(puzzle.failureCount == 2)
        #expect(puzzle.repetitions == 3)
        #expect(puzzle.easinessFactor == 2.7)
        #expect(puzzle.intervalDays == 15)
    }

    @Test func reconcileKeepsTheLocalWhenItIsAheadAndPushesTheMirror() throws {
        let context = try makeContext()
        // Local en AVANCE : reconcile ne doit pas régresser le puzzle, et doit
        // remonter le miroir au max pour que les autres appareils convergent.
        let puzzle = makeLichessPuzzle(externalID: "abc12")
        puzzle.successCount = 6
        puzzle.failureCount = 3
        context.insert(puzzle)

        let progress = PuzzleProgress(externalID: "abc12")
        progress.successCount = 2
        progress.failureCount = 1
        context.insert(progress)
        try context.save()

        PuzzleProgressSync.reconcile(in: context)

        #expect(puzzle.successCount == 6)
        #expect(puzzle.failureCount == 3)
        // Le miroir a été remonté au max local.
        let record = try #require(try context.fetch(FetchDescriptor<PuzzleProgress>()).first)
        #expect(record.successCount == 6)
        #expect(record.failureCount == 3)
    }
}
