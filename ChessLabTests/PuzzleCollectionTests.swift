import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// L'import d'un fichier PGN de puzzles (``PuzzleCollectionImporter``) : ce qu'il
/// lit, ce qu'il refuse et pourquoi.
struct PuzzleCollectionImporterTests {
    /// Le mat en deux du couloir : Te8+ Txe8 Txe8#.
    private static let corridorFEN = "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    private func game(_ moves: String, fen: String? = corridorFEN, extra: String = "") -> String {
        var text = ""
        if let fen { text += "[SetUp \"1\"]\n[FEN \"\(fen)\"]\n" }
        return text + extra + "\n\(moves)\n"
    }

    @Test func readsTheSolutionFromTheMainLine() {
        let result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Rxe8# 1-0"))
        #expect(result.puzzles.count == 1)
        #expect(result.puzzles[0].fen == Self.corridorFEN)
        #expect(result.puzzles[0].solutionLANs == ["e3e8", "a8e8", "e1e8"])
        #expect(result.puzzles[0].themeRaw == PuzzleTheme.checkmate.rawValue)
        #expect(result.skipped.isEmpty)
    }

    @Test func aTrailingOpponentReplyIsDropped() {
        // Une solution se termine sur le coup de celui qui trouve.
        let result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8"))
        #expect(result.puzzles[0].solutionLANs == ["e3e8"])
    }

    @Test func aSingleMoveIsAValidPuzzle() {
        let result = PuzzleCollectionImporter.parse(game("1. Re8#", fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1"))
        #expect(result.puzzles.map(\.solutionLANs) == [["e1e8"]])
    }

    @Test func ignoresVariationsCommentsAnnotationsAndNAGs() {
        let moves = "1. Re8+! {the only move} (1. Rd3 Rxa2) 1... Rxe8 $1 2. Rxe8#!! 1-0"
        let result = PuzzleCollectionImporter.parse(game(moves))
        #expect(result.puzzles.map(\.solutionLANs) == [["e3e8", "a8e8", "e1e8"]])
    }

    @Test func aPromotionKeepsItsPiece() {
        let result = PuzzleCollectionImporter.parse(game("1. e8=N", fen: "8/4P2k/8/8/8/8/8/K7 w - - 0 1"))
        #expect(result.puzzles.map(\.solutionLANs) == [["e7e8n"]])
    }

    @Test func refusesAGameWithoutFENAndSaysSo() {
        let result = PuzzleCollectionImporter.parse(game("1. e4 e5 2. Nf3", fen: nil, extra: "[Event \"x\"]\n"))
        #expect(result.puzzles.isEmpty)
        #expect(result.skipped == [.init(gameNumber: 1, reason: .missingFEN)])
    }

    @Test func refusesAnUnreadableFEN() {
        let result = PuzzleCollectionImporter.parse(game("1. e4", fen: "not a fen"))
        #expect(result.skipped.map(\.reason) == [.invalidFEN])
    }

    @Test func refusesAGameWithoutMoves() {
        let result = PuzzleCollectionImporter.parse(game("*"))
        #expect(result.skipped.map(\.reason) == [.noMoves])
    }

    @Test func anIllegalMoveDiscardsTheWholeGame() {
        // Rien n'est deviné : une solution tronquée serait un autre puzzle.
        let result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Qh5"))
        #expect(result.puzzles.isEmpty)
        #expect(result.skipped.map(\.reason) == [.illegalMove("Qh5")])
    }

    @Test func oneBadGameDoesNotStopTheOthers() {
        let text = game("1. Re8+ Rxe8 2. Rxe8#") + "\n" + game("1. Kd4") + "\n" + game("1. Re8#", fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")
        let result = PuzzleCollectionImporter.parse(text)
        #expect(result.gameCount == 3)
        #expect(result.puzzles.count == 2)
        #expect(result.skipped == [.init(gameNumber: 2, reason: .illegalMove("Kd4"))])
    }

    @Test func splitsGamesWithoutEventHeaders() {
        // Un fichier de puzzles n'a souvent que [FEN] : pas de [Event] pour couper.
        let text = game("1. Re8+ Rxe8 2. Rxe8#") + game("1. Re8#", fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")
        #expect(PuzzleCollectionImporter.splitIntoGames(text).count == 2)
    }

    @Test func aCommentLineStartingWithABracketDoesNotSplitAGame() {
        let moves = "1. Re8+ {\n[%clk 0:03:00]\n} Rxe8 2. Rxe8#"
        #expect(PuzzleCollectionImporter.splitIntoGames(game(moves)).count == 1)
    }

    @Test func countsRepeatedPuzzlesOnce() {
        let one = game("1. Re8+ Rxe8 2. Rxe8#")
        let result = PuzzleCollectionImporter.parse(one + "\n" + one)
        #expect(result.puzzles.count == 1)
        #expect(result.duplicates == 1)
    }

    @Test func toleratesWindowsLineEndingsAndABOM() {
        let text = "\u{FEFF}" + game("1. Re8+ Rxe8 2. Rxe8#").replacingOccurrences(of: "\n", with: "\r\n")
        #expect(PuzzleCollectionImporter.parse(text).puzzles.count == 1)
    }

    @Test func anEmptyFileGivesNothing() {
        let result = PuzzleCollectionImporter.parse("  \n\n")
        #expect(result.gameCount == 0)
        #expect(result.puzzles.isEmpty)
    }

    /// Le fichier de Ron : environ mille puzzles, 400 Ko. Il doit se lire vite.
    @Test func aThousandPuzzlesReadQuickly() {
        let text = (0..<1000).map { index in
            // FEN distinctes : le compteur de coups change.
            game("1. Re8+ Rxe8 2. Rxe8#", fen: "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)")
        }.joined(separator: "\n")
        let started = Date()
        let result = PuzzleCollectionImporter.parse(text)
        #expect(result.puzzles.count == 1000)
        #expect(Date().timeIntervalSince(started) < 10)
    }

    /// Le programme Woodpecker d'une collection de mille puzzles voyage dans le
    /// store synchronisé : sa taille doit rester bien en deçà de la limite d'un
    /// enregistrement CloudKit (1 Mo), même après plusieurs cycles.
    @Test func aThousandPuzzleWoodpeckerPlanStaysSmall() throws {
        let items = (0..<1000).map { index in
            WoodpeckerPlan.Item(
                fen: "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)",
                solutionLANs: ["e3e8", "a8e8", "e1e8"], themeRaw: "checkmate", phaseRaw: "endgame"
            )
        }
        var generator = SystemRandomNumberGenerator()
        var plan = try #require(WoodpeckerPlan.start(items: items, using: &generator))
        // Sept cycles bouclés : la méthode en prescrit autant.
        for _ in 0..<6 {
            plan.cycles[plan.cycles.count - 1].attempts = (0..<1000).map { _ in .init(solved: true, seconds: 12.5) }
            plan.cycles.append(.init(number: plan.cycles.count + 1, order: Array(0..<1000), startedAt: Date()))
        }
        plan.cycles[plan.cycles.count - 1].attempts = (0..<1000).map { _ in .init(solved: true, seconds: 12.5) }
        let size = try JSONEncoder().encode(plan).count
        #expect(size < 800_000, "plan de \(size) octets")
    }
}

/// Les collections en base : import, doublons, séparation d'avec le tirage
/// général, renommage, suppression.
///
/// - important: UN SEUL `ModelContainer`, `.serialized` — voir ``PuzzleSessionDrawerTests``.
@MainActor
@Suite(.serialized)
struct PuzzleCollectionStoreTests {
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

    private func parsed(_ count: Int, firstIndex: Int = 0) -> PuzzleCollectionImporter.Result {
        PuzzleCollectionImporter.Result(
            puzzles: (firstIndex..<(firstIndex + count)).map { index in
                .init(
                    fen: "r5k1/5ppp/8/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)",
                    solutionLANs: ["e3e8", "a8e8", "e1e8"], themeRaw: "checkmate", phaseRaw: "endgame"
                )
            },
            gameCount: count
        )
    }

    @Test func addsPuzzlesTaggedWithTheirCollection() throws {
        let context = try makeContext()
        let report = PuzzleCollectionStore.add(parsed(3), toCollection: "  Fourchettes ", in: context)
        #expect(report.collection == "Fourchettes")
        #expect(report.added == 3)
        let puzzles = PuzzleCollectionStore.puzzles(inCollection: "Fourchettes", in: context)
        #expect(puzzles.count == 3)
        #expect(puzzles.allSatisfy { $0.source == .imported && $0.externalID == nil && $0.rating == nil })
    }

    @Test func keepsTheFileOrder() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(5), toCollection: "A", in: context)
        let fens = PuzzleCollectionStore.puzzles(inCollection: "A", in: context).compactMap(\.fen)
        #expect(fens == parsed(5).puzzles.map(\.fen))
    }

    @Test func reimportingTheSameFileAddsNothingTwice() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(4), toCollection: "A", in: context)
        let again = PuzzleCollectionStore.add(parsed(6), toCollection: "A", in: context)
        #expect(again.added == 2)
        #expect(again.alreadyThere == 4)
        #expect(PuzzleCollectionStore.puzzles(inCollection: "A", in: context).count == 6)
    }

    @Test func listsCollectionsAlphabeticallyWithTheirCounts() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(2), toCollection: "Mats", in: context)
        PuzzleCollectionStore.add(parsed(3), toCollection: "Clouages", in: context)
        let list = PuzzleCollectionStore.collections(in: context)
        #expect(list.map(\.name) == ["Clouages", "Mats"])
        #expect(list.map(\.count) == [3, 2])
    }

    @Test func countsTheMissedOnesOfACollection() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(3), toCollection: "A", in: context)
        let first = try #require(PuzzleCollectionStore.puzzles(inCollection: "A", in: context).first)
        first.lastOutcomeRaw = PuzzleOutcome.missed.rawValue
        #expect(PuzzleCollectionStore.collections(in: context).first?.missedCount == 1)
    }

    @Test func collectionsStayOutOfTheGeneralDraw() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(5), toCollection: "A", in: context)
        let library = Puzzle()
        library.sourceRaw = PuzzleSource.lichess.rawValue
        library.fen = "7k/6pp/8/8/8/8/8/RR4K1 w - - 0 1"
        library.solutionLANs = ["a1a8"]
        context.insert(library)
        // Sans critère de provenance : la bibliothèque seulement.
        #expect(PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(), in: context) == 1)
        // Par collection, ou par provenance : les puzzles importés.
        #expect(PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(collection: "A"), in: context) == 5)
        #expect(PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(source: .imported), in: context) == 5)
        #expect(PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(collection: "Autre"), in: context) == 0)
    }

    @Test func aWoodpeckerTakesTheWholeCollectionNotASample() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(120), toCollection: "A", in: context)
        let items = PuzzleCollectionStore.puzzles(inCollection: "A", in: context).map(WoodpeckerPlan.Item.init)
        #expect(items.count == 120)
    }

    @Test func renamesACollection() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(2), toCollection: "Vieux", in: context)
        #expect(PuzzleCollectionStore.rename("Vieux", to: " Neuf ", in: context))
        #expect(PuzzleCollectionStore.collections(in: context).map(\.name) == ["Neuf"])
    }

    @Test func refusesToRenameOntoAnotherCollectionOrToNothing() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)
        PuzzleCollectionStore.add(parsed(2), toCollection: "B", in: context)
        #expect(!PuzzleCollectionStore.rename("A", to: "B", in: context))
        #expect(!PuzzleCollectionStore.rename("A", to: "   ", in: context))
        #expect(PuzzleCollectionStore.collections(in: context).map(\.count) == [2, 2])
    }

    @Test func deletesOnlyThatCollection() throws {
        let context = try makeContext()
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)
        PuzzleCollectionStore.add(parsed(3), toCollection: "B", in: context)
        PuzzleCollectionStore.delete("A", in: context)
        #expect(PuzzleCollectionStore.collections(in: context).map(\.name) == ["B"])
        #expect(PuzzleCollectionStore.puzzles(inCollection: "B", in: context).count == 3)
    }

    @Test func suggestsTheFileNameWithoutItsExtension() {
        #expect(PuzzleCollectionStore.suggestedName(fromFile: URL(fileURLWithPath: "/x/Forks 2026.pgn")) == "Forks 2026")
    }
}
