import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Le tirage d'une série (filtres « Provenance » et « Ratés ») et la
/// tolérance aux mats alternatifs de l'écran de résolution.
///
/// - important: UN SEUL `ModelContainer` pour tout le suite, `.serialized` —
///   même raison que ``PuzzleProgressSyncTests`` (plusieurs containers en
///   mémoire dans le même process font trapper SwiftData).
@MainActor
@Suite(.serialized)
struct PuzzleSessionDrawerTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: Puzzle.self, PuzzleProgress.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: Puzzle.self)
        try context.delete(model: PuzzleProgress.self)
        try context.save()
        return context
    }

    @discardableResult
    private func insertPuzzle(
        in context: ModelContext,
        source: PuzzleSource? = .lichess,
        failures: Int = 0,
        repetitions: Int = 0,
        dueInDays: Int = 0,
        fen: String = "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1",
        solution: [String] = ["a1a8"]
    ) -> Puzzle {
        let puzzle = Puzzle()
        puzzle.sourceRaw = source?.rawValue
        puzzle.failureCount = failures
        puzzle.repetitions = repetitions
        puzzle.dueDate = Calendar.current.date(byAdding: .day, value: dueInDays, to: Date())
        puzzle.fen = fen
        puzzle.solutionLANs = solution
        context.insert(puzzle)
        return puzzle
    }

    /// Tire autant de fois qu'il le faut pour couvrir un petit ensemble au
    /// hasard (le tirage est aléatoire par offset).
    private func drawnIDs(_ filter: PuzzleSessionFilter, in context: ModelContext) -> Set<UUID> {
        Set((0..<60).compactMap { _ in PuzzleSessionDrawer.drawNext(matching: filter, in: context)?.id })
    }

    // MARK: Ratés

    @Test func missedOnlyKeepsPuzzlesWhoseLastAttemptFailed() throws {
        let context = try makeContext()
        // Raté hier, révision demain : DOIT sortir quand même.
        let missed = insertPuzzle(in: context, failures: 1, repetitions: 0, dueInDays: 1)
        // Raté puis réussi : sorti de la liste.
        insertPuzzle(in: context, failures: 2, repetitions: 1, dueInDays: 1)
        // Jamais tenté.
        insertPuzzle(in: context)
        try context.save()

        #expect(drawnIDs(PuzzleSessionFilter(missedOnly: true), in: context) == [missed.id])
    }

    @Test func withoutMissedOnlyANotYetDuePuzzleStaysOut() throws {
        let context = try makeContext()
        insertPuzzle(in: context, failures: 1, repetitions: 0, dueInDays: 1)
        try context.save()

        #expect(PuzzleSessionDrawer.drawNext(matching: PuzzleSessionFilter(), in: context) == nil)
    }

    @Test func aMissedPuzzleLeavesTheListOnceSolved() throws {
        let context = try makeContext()
        let puzzle = insertPuzzle(in: context, failures: 1, repetitions: 0, dueInDays: 1)
        try context.save()

        let filter = PuzzleSessionFilter(missedOnly: true)
        let viewModel = try #require(PuzzleSolveViewModel(filter: filter, modelContext: context))
        viewModel.attemptMove(from: Square("a1"), to: Square("a8"))

        #expect(viewModel.isSolved)
        #expect(puzzle.repetitions == 1)
        #expect(PuzzleSessionDrawer.drawNext(matching: filter, in: context) == nil)
    }

    // MARK: Provenance

    @Test func sourceFilterSeparatesOwnGamesFromTheLibrary() throws {
        let context = try makeContext()
        let own = insertPuzzle(in: context, source: .ownGames)
        // Puzzle maison d'avant le champ `sourceRaw`.
        let legacyOwn = insertPuzzle(in: context, source: nil)
        let library = insertPuzzle(in: context, source: .lichess)
        try context.save()

        #expect(drawnIDs(PuzzleSessionFilter(source: .ownGames), in: context) == [own.id, legacyOwn.id])
        #expect(drawnIDs(PuzzleSessionFilter(source: .lichess), in: context) == [library.id])
        #expect(drawnIDs(PuzzleSessionFilter(), in: context) == [own.id, legacyOwn.id, library.id])
    }

    @Test func hasAnyPuzzleIgnoresTheDueDate() throws {
        let context = try makeContext()
        insertPuzzle(in: context, source: .ownGames, dueInDays: 6)
        try context.save()

        #expect(PuzzleSessionDrawer.hasAnyPuzzle(from: .ownGames, in: context))
        #expect(!PuzzleSessionDrawer.hasAnyPuzzle(from: .lichess, in: context))
    }

    @Test func hasOwnPuzzleMatchesOnlyOwnGamesAtThatPosition() throws {
        let context = try makeContext()
        let fen = "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1"
        insertPuzzle(in: context, source: .lichess, fen: fen)
        try context.save()
        #expect(!PuzzleSessionDrawer.hasOwnPuzzle(fen: fen, in: context))

        // Pas encore sauvegardé : compte quand même (génération en cours).
        insertPuzzle(in: context, source: .ownGames, fen: fen)
        #expect(PuzzleSessionDrawer.hasOwnPuzzle(fen: fen, in: context))
        #expect(!PuzzleSessionDrawer.hasOwnPuzzle(fen: "8/8/8/8/8/8/8/K6k w - - 0 1", in: context))
    }

    // MARK: Mat alternatif

    @Test func anotherCheckmatingMoveSolvesThePuzzle() throws {
        let context = try makeContext()
        // Deux mats du couloir : Ta8# (la solution enregistrée) et Tb8#.
        insertPuzzle(in: context)
        try context.save()

        let viewModel = try #require(PuzzleSolveViewModel(filter: PuzzleSessionFilter(), modelContext: context))
        viewModel.attemptMove(from: Square("b1"), to: Square("b8"))

        #expect(viewModel.isSolved)
        #expect(viewModel.rejectedMove == nil)
    }

    @Test func aMateEndsThePuzzleEvenBeforeTheEndOfTheStoredLine() throws {
        let context = try makeContext()
        // La ligne enregistrée prend un détour ; le mat immédiat clôt tout.
        insertPuzzle(in: context, solution: ["g1f2", "h7h6", "a1a8"])
        try context.save()

        let viewModel = try #require(PuzzleSolveViewModel(filter: PuzzleSessionFilter(), modelContext: context))
        viewModel.attemptMove(from: Square("a1"), to: Square("a8"))

        #expect(viewModel.isSolved)
    }

    @Test func aNonMatingWrongMoveIsStillRejected() throws {
        let context = try makeContext()
        insertPuzzle(in: context)
        try context.save()

        let viewModel = try #require(PuzzleSolveViewModel(filter: PuzzleSessionFilter(), modelContext: context))
        viewModel.attemptMove(from: Square("b1"), to: Square("b7"))

        #expect(!viewModel.isSolved)
        #expect(viewModel.rejectedMove != nil)
    }
}
