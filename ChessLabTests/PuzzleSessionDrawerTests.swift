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
            for: Puzzle.self, PuzzleProgress.self, WoodpeckerProgram.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: Puzzle.self)
        try context.delete(model: PuzzleProgress.self)
        try context.delete(model: WoodpeckerProgram.self)
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

    // MARK: Woodpecker

    @Test func aWoodpeckerSampleIsDistinctAndIgnoresTheDueDate() throws {
        let context = try makeContext()
        for _ in 0..<5 { insertPuzzle(in: context, dueInDays: 6) }
        insertPuzzle(in: context, source: .ownGames)
        try context.save()

        let sample = PuzzleSessionDrawer.sample(matching: PuzzleSessionFilter(source: .lichess), count: 4, in: context)
        #expect(sample.count == 4)
        #expect(Set(sample.map(\.id)).count == 4)
        #expect(sample.allSatisfy { $0.source == .lichess })
        // Plus demandé que disponible : tout ce qui correspond, pas plus.
        #expect(PuzzleSessionDrawer.sample(matching: PuzzleSessionFilter(), count: 50, in: context).count == 6)
    }

    /// Un cycle complet joué à l'écran : les réponses vont au PROGRAMME, la
    /// bibliothèque n'est pas touchée (aucune échéance, aucun compteur), puis
    /// le cycle suivant repart sur le même lot.
    @Test func aWoodpeckerCycleIsRecordedInTheProgramOnly() throws {
        let context = try makeContext()
        let library = insertPuzzle(in: context)
        try context.save()

        let item = WoodpeckerPlan.Item(library)
        let plan = try #require(WoodpeckerPlan.start(items: [item, item]))
        let program = WoodpeckerProgram()
        program.plan = plan
        context.insert(program)
        try context.save()

        let viewModel = try #require(PuzzleSolveViewModel(woodpecker: program, modelContext: context))
        #expect(viewModel.isWoodpecker)
        #expect(viewModel.sessionProgressText?.contains("1/2") == true)

        viewModel.attemptMove(from: Square("a1"), to: Square("a8"))
        #expect(viewModel.isSolved)
        #expect(!viewModel.isCycleComplete)
        viewModel.loadNextPuzzle()
        viewModel.attemptMove(from: Square("b1"), to: Square("b8"))   // l'autre mat : juste aussi

        #expect(viewModel.isCycleComplete)
        let saved = try #require(program.plan)
        #expect(saved.currentCycle.isComplete)
        #expect(saved.currentCycle.solvedCount == 2)
        // La bibliothèque n'a rien vu passer.
        #expect(library.successCount == 0)
        #expect(library.repetitions == 0)
        #expect(library.firstOpenedAt == nil)
        #expect(try context.fetchCount(FetchDescriptor<Puzzle>()) == 1, "aucun puzzle transitoire inséré")

        viewModel.startNextCycle()
        #expect(program.plan?.currentCycle.number == 2)
        #expect(!viewModel.isFinished)
        #expect(viewModel.sessionProgressText?.contains("Cycle 2") == true)
    }

    /// Un cycle bouclé puis laissé là : rouvrir le programme, c'est vouloir
    /// continuer — le cycle suivant démarre.
    @Test func reopeningAFinishedCycleStartsTheNextOne() throws {
        let context = try makeContext()
        var plan = try #require(WoodpeckerPlan.start(items: [WoodpeckerPlan.Item(fen: "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1", solutionLANs: ["a1a8"])]))
        plan.record(solved: false, seconds: 3)
        let program = WoodpeckerProgram()
        program.plan = plan
        context.insert(program)

        let viewModel = try #require(PuzzleSolveViewModel(woodpecker: program, modelContext: context))
        #expect(program.plan?.currentCycle.number == 2)
        #expect(!viewModel.isFinished)
    }

    // MARK: À mon niveau

    @Test func aRatingWindowKeepsOnlyPuzzlesAroundThePlayer() throws {
        let context = try makeContext()
        for rating in [1000, 1400, 1500, 1600, 2000] {
            let puzzle = insertPuzzle(in: context)
            puzzle.rating = rating
        }
        try context.save()
        let drawn = Set((0..<80).compactMap {
            _ in PuzzleSessionDrawer.drawNext(matching: PuzzleSessionFilter(ratingWindow: 1400...1600), in: context)?.rating
        })
        #expect(drawn == [1400, 1500, 1600])
    }

    /// Un puzzle de la bibliothèque, réussi, nourrit la cote ; un puzzle de vos
    /// parties (sans cote) ne la touche pas.
    @Test func onlyRatedPuzzlesFeedThePlayerRating() throws {
        let defaults = UserDefaults.standard
        let before = PuzzleRatingStore.load(from: defaults)
        defer { PuzzleRatingStore.save(before, to: defaults) }
        PuzzleRatingStore.save(.initial, to: defaults)

        let context = try makeContext()
        let rated = insertPuzzle(in: context)
        rated.rating = 1500
        let own = insertPuzzle(in: context, source: .ownGames, fen: "k7/8/8/8/8/8/6RR/K7 w - - 0 1", solution: ["h2h8"])
        try context.save()

        let first = try #require(PuzzleSolveViewModel(filter: PuzzleSessionFilter(source: .lichess), modelContext: context))
        first.attemptMove(from: Square("a1"), to: Square("a8"))
        #expect(PuzzleRatingStore.load(from: defaults).count == 1)

        _ = own
        let second = try #require(PuzzleSolveViewModel(filter: PuzzleSessionFilter(source: .ownGames), modelContext: context))
        second.attemptMove(from: Square("h2"), to: Square("h8"))
        #expect(PuzzleRatingStore.load(from: defaults).count == 1, "pas de cote, pas de mise à jour")
    }
}

