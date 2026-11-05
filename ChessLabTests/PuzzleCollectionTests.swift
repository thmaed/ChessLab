import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// L'import d'un fichier PGN de puzzles (``PuzzleCollectionImporter``) : ce qu'il
/// lit, ce qu'il refuse et pourquoi.
struct PuzzleCollectionImporterTests {
    /// Le mat en deux du couloir (Te8+ Txe8 Txe8#), précédé de sa PRÉPARATION : le
    /// coup adverse a6, joué d'avance. Le FEN du fichier est la position AVANT ce
    /// coup ; celle du puzzle est ``corridorFEN``, APRÈS lui.
    private static let corridorBefore = "r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22"
    private static let corridorFEN = "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 23"
    /// Un mat en un : sa préparation (a6), puis Te8#.
    private static let shortBefore = "6k1/p4ppp/8/8/8/8/5PPP/4R1K1 b - - 0 1"

    private func game(
        _ moves: String, fen: String? = corridorBefore, extra: String = "", setup: String = "22...a6"
    ) -> String {
        var text = ""
        if let fen { text += "[SetUp \"1\"]\n[FEN \"\(fen)\"]\n" }
        return text + extra + "\n\(setup) \(moves)\n"
    }

    @Test func readsTheSolutionFromTheMainLine() {
        let result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Rxe8# 1-0"))
        #expect(result.puzzles.count == 1)
        // Le puzzle commence APRÈS la préparation, qui est gardée à part pour être montrée.
        #expect(result.puzzles[0].fen == Self.corridorFEN)
        #expect(result.puzzles[0].setupLAN == "a7a6")
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
        let result = PuzzleCollectionImporter.parse(game("1. Re8#", fen: Self.shortBefore))
        #expect(result.puzzles.map(\.solutionLANs) == [["e1e8"]])
    }

    @Test func ignoresVariationsCommentsAnnotationsAndNAGs() {
        let moves = "1. Re8+! {the only move} (1. Rd3 Rxa2) 1... Rxe8 $1 2. Rxe8#!! 1-0"
        let result = PuzzleCollectionImporter.parse(game(moves))
        #expect(result.puzzles.map(\.solutionLANs) == [["e3e8", "a8e8", "e1e8"]])
    }

    @Test func aPromotionKeepsItsPiece() {
        let result = PuzzleCollectionImporter.parse(game("1. e8=N", fen: "8/4P3/7k/8/8/8/8/K7 b - - 0 1", setup: "1...Kh7"))
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
        let result = PuzzleCollectionImporter.parse(game("*", setup: ""))
        #expect(result.skipped.map(\.reason) == [.noMoves])
    }

    @Test func anIllegalMoveDiscardsTheWholeGame() {
        // Rien n'est deviné : une solution tronquée serait un autre puzzle.
        let result = PuzzleCollectionImporter.parse(game("1. Re8+ Rxe8 2. Qh5"))
        #expect(result.puzzles.isEmpty)
        #expect(result.skipped.map(\.reason) == [.illegalMove("Qh5")])
    }

    @Test func oneBadGameDoesNotStopTheOthers() {
        let text = game("1. Re8+ Rxe8 2. Rxe8#") + "\n" + game("1. Kd4") + "\n" + game("1. Re8#", fen: Self.shortBefore)
        let result = PuzzleCollectionImporter.parse(text)
        #expect(result.gameCount == 3)
        #expect(result.puzzles.count == 2)
        #expect(result.skipped == [.init(gameNumber: 2, reason: .illegalMove("Kd4"))])
    }

    @Test func splitsGamesWithoutEventHeaders() {
        // Un fichier de puzzles n'a souvent que [FEN] : pas de [Event] pour couper.
        let text = game("1. Re8+ Rxe8 2. Rxe8#") + game("1. Re8#", fen: Self.shortBefore)
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

    @Test func aGameWithOnlyItsSetupMoveHasNoSolution() {
        let result = PuzzleCollectionImporter.parse(game("", setup: "22...a6"))
        #expect(result.puzzles.isEmpty)
        #expect(result.skipped.map(\.reason) == [.noSolution])
    }

    /// Le fichier RÉEL de Ron (sept puzzles), tel quel. Son « premier coup » est la
    /// préparation : le coup de l'adversaire, joué d'avance — le puzzle commence après.
    /// Le sixième n'a que sa préparation (PlyCount 1) : il est écarté, et le dit.
    @Test func readsRonsFile() {
        func entry(_ n: Int, _ fen: String, _ moves: String) -> String {
            "[Event \"?\"]\n[Site \"ThePuzzle\"]\n[Round \"?\"]\n[White \"\(n)\"]\n[Result \"*\"]\n"
                + "[FEN \"\(fen)\"]\n[SetUp \"1\"]\n\n\(moves) *\n\n"
        }
        let text = entry(1, "rr4k1/p1R2p1p/4pnpn/R2pN3/3P1P2/1q3N2/1P2QPP1/6K1 b - - 0 1", "1...Qxb2 2.Rc8+ Rxc8 3.Qxb2")
            + entry(2, "8/5R2/1p2B1pk/1p1P4/4nP1p/1P2q2P/P5P1/2R4K w - - 0 1", "1.Rg1 Nf2+ 2.Kh2 Qg3#")
            + entry(3, "4Bk2/2r2pp1/1nRqp2p/p6P/P2P4/2P2Q2/5PP1/6K1 b - - 0 1", "1...Rxc6 2.Qxf7#")
            + entry(4, "r4k1Q/p3p3/2p1bbB1/3pp3/1PP5/4q3/P5PP/5R1K b - - 0 1", "1...Bg8 2.Rxf6+ exf6 3.Qxf6+ Bf7 4.Qxf7#")
            + entry(5, "Q7/5pkp/3rn1p1/2qR4/2P4P/6P1/p4P2/6K1 w - - 0 1", "1.Rxc5 Rd1+ 2.Kh2 a1=Q")
            + entry(6, "r1bqk1nr/1ppp1ppp/p1n5/2b1p1N1/2B1P3/3P4/PPP2PPP/RNBQK2R b KQkq - 0 1", "1...Bb4+")
            + entry(7, "r4rk1/1p4b1/3q2B1/p5Bn/P2P2nN/8/1P1Q4/R3R1K1 w - - 0 1", "1.Re4 Rf2 2.Qxf2 Nxf2")
        let result = PuzzleCollectionImporter.parse(text)
        #expect(result.gameCount == 7)
        #expect(result.skipped == [.init(gameNumber: 6, reason: .noSolution)])
        // Les préparations : le coup adverse de chaque énoncé.
        #expect(result.puzzles.map(\.setupLAN) == ["b3b2", "c1g1", "c7c6", "e6g8", "d5c5", "e1e4"])
        // Chaque solution se termine sur un coup de CELUI QUI TROUVE, la riposte comprise au milieu.
        #expect(result.puzzles[0].solutionLANs == ["c7c8", "b8c8", "e2b2"])
        #expect(result.puzzles[2].solutionLANs == ["f3f7"])
        #expect(result.puzzles[3].solutionLANs == ["f1f6", "e7f6", "h8f6", "g8f7", "f6f7"])
        #expect(result.puzzles[4].solutionLANs == ["d6d1", "g1h2", "a2a1q"])
        // À l'ouverture du puzzle, le trait est à CELUI QUI TROUVE : l'inverse du FEN du fichier.
        #expect(result.puzzles[0].fen.contains(" w "))
        #expect(result.puzzles[1].fen.contains(" b "))
    }

    /// Le fichier de Ron : environ mille puzzles, 400 Ko. Il doit se lire vite.
    @Test func aThousandPuzzlesReadQuickly() {
        let text = (0..<1000).map { index in
            // FEN distinctes : le compteur de coups change.
            game("1. Re8+ Rxe8 2. Rxe8#", fen: "r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 \(index + 1)")
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
                    fen: "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)", setupLAN: "a7a6",
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

/// « 1 puzzle » contre « 5 puzzles » : les comptes de l'import et des collections
/// s'accordent. (Le 0, singulier en français seulement, dépend de la langue
/// active : on ne la change pas ici, elle est globale.)
struct CountedWordingTests {
    @Test func oneIsSingularAndManyArePlural() {
        #expect(LocalizationController.isSingular(1))
        #expect(!LocalizationController.isSingular(2))
        #expect(!LocalizationController.isSingular(947))
    }

    @Test func theRightFormIsPickedAndFilled() {
        let one = LocalizationController.counted(1, one: "%lld puzzle", other: "%lld puzzles")
        let many = LocalizationController.counted(5, one: "%lld puzzle", other: "%lld puzzles")
        #expect(one == "1 puzzle")
        #expect(many == "5 puzzles")
    }
}

/// La PRÉPARATION d'un puzzle importé est montrée sur le plateau : les deux cases
/// du coup adverse déjà joué. Sans préparation, rien n'est surligné.
@MainActor
struct PuzzleSetupHighlightTests {
    /// Le puzzle 3 de Ron, APRÈS sa préparation `…Txc6` (la tour noire est en c6).
    private let fen = "4Bk2/5pp1/1nrqp2p/p6P/P2P4/2P2Q2/5PP1/6K1 w - - 0 2"

    @Test func theSetupMoveIsHighlighted() throws {
        let puzzle = Puzzle()
        puzzle.fen = fen
        puzzle.setupLAN = "c7c6"
        let board = Board(position: try #require(Position(fen: fen)))
        let move = try #require(PuzzleSolveViewModel.setupMove(of: puzzle, on: board))
        #expect(move.start.notation == "c7")
        #expect(move.end.notation == "c6")
    }

    @Test func aPuzzleWithoutSetupHighlightsNothing() throws {
        let puzzle = Puzzle()
        puzzle.fen = fen
        let board = Board(position: try #require(Position(fen: fen)))
        #expect(PuzzleSolveViewModel.setupMove(of: puzzle, on: board) == nil)
    }

    @Test func theSetupTravelsInTheWoodpeckerPlan() {
        let puzzle = Puzzle()
        puzzle.fen = fen
        puzzle.solutionLANs = ["f3f7"]
        puzzle.setupLAN = "c7c6"
        let item = WoodpeckerPlan.Item(puzzle)
        #expect(item.setupLAN == "c7c6")
        #expect(item.makePuzzle().setupLAN == "c7c6")
    }
}

/// L'export d'une collection (``PuzzleCollectionExporter``) : ce qu'il écrit, et
/// que l'import le relit à l'identique.
struct PuzzleCollectionExporterTests {
    private static let corridorFEN = "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 23"

    private func entry(
        fen: String = corridorFEN, setup: String? = "a7a6", solution: [String] = ["e3e8", "a8e8", "e1e8"]
    ) -> PuzzleCollectionExporter.Entry {
        .init(fen: fen, setupLAN: setup, solutionLANs: solution)
    }

    @Test func writesTheSolutionInSANWithItsHeaders() {
        let pgn = PuzzleCollectionExporter.pgn(collection: "Couloirs", entries: [entry()])
        #expect(pgn.contains("[Event \"Couloirs\"]"))
        #expect(pgn.contains("[FEN \"\(Self.corridorFEN)\"]"))
        #expect(pgn.contains("[PuzzleSetup \"a7a6\"]"))
        #expect(pgn.contains("23. Re8+ Rxe8 24. Rxe8# *"))
    }

    @Test func numbersABlackFirstMoveWithEllipsis() {
        // Le trait est aux Noirs : « 1... », puis les coups suivants sans numéro avant le Blanc.
        let pgn = PuzzleCollectionExporter.pgn(
            collection: "N", entries: [entry(fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 b - - 0 7", setup: nil, solution: ["g8f8", "e1e8", "f8e8"])]
        )
        #expect(pgn.contains("7... Kf8 8. Re8+ Kxe8 *"))
        #expect(pgn.contains("[PuzzleSetup \"-\"]"))
    }

    @Test func aPromotionIsWrittenWithItsPiece() {
        let pgn = PuzzleCollectionExporter.pgn(
            collection: "P", entries: [entry(fen: "8/4P3/7k/8/8/8/8/K7 w - - 0 1", setup: nil, solution: ["e7e8n"])]
        )
        #expect(pgn.contains("1. e8=N"))
    }

    @Test func importingTheExportGivesBackTheSamePuzzles() {
        let entries = [
            entry(),
            entry(fen: "6k1/5ppp/8/8/8/8/5PPP/4R1K1 b - - 0 7", setup: "h2h3", solution: ["g8f8", "e1e8", "f8e8"]),
            entry(fen: "8/4P3/7k/8/8/8/8/K7 w - - 0 1", setup: nil, solution: ["e7e8n"]),
        ]
        let result = PuzzleCollectionImporter.parse(PuzzleCollectionExporter.pgn(collection: "C", entries: entries))
        #expect(result.skipped.isEmpty)
        #expect(result.puzzles.map(\.fen) == entries.map(\.fen))
        #expect(result.puzzles.map(\.setupLAN) == entries.map(\.setupLAN))
        #expect(result.puzzles.map(\.solutionLANs) == entries.map(\.solutionLANs))
    }

    @Test func aPuzzleThatCannotBeReplayedIsLeftOut() {
        let pgn = PuzzleCollectionExporter.pgn(
            collection: "X", entries: [entry(solution: ["a1a8"]), entry(), entry(fen: "n'importe quoi")]
        )
        #expect(PuzzleCollectionImporter.parse(pgn).puzzles.count == 1)
    }

    @Test func anEmptyCollectionWritesNothing() {
        #expect(PuzzleCollectionExporter.pgn(collection: "Vide", entries: []).isEmpty)
    }

    @Test func theFileNameIsSafeForTheFileSystem() {
        #expect(PuzzleCollectionExporter.fileName(forCollection: "Fourchettes") == "Fourchettes.pgn")
        #expect(PuzzleCollectionExporter.fileName(forCollection: "a/b:c") == "a-b-c.pgn")
        #expect(PuzzleCollectionExporter.fileName(forCollection: "  ") == "ChessLab.pgn")
    }

    @Test func aFileWithoutTheHeaderStillReadsTheFirstMoveAsPreparation() {
        // Le fichier d'un autre site : la convention de Lichess s'applique toujours.
        let text = "[FEN \"r5k1/p4ppp/8/8/8/4R3/5PPP/4R1K1 b - - 0 22\"]\n\n22... a6 23. Re8+ Rxe8 24. Rxe8# *"
        let result = PuzzleCollectionImporter.parse(text)
        #expect(result.puzzles.first?.setupLAN == "a7a6")
        #expect(result.puzzles.first?.solutionLANs == ["e3e8", "a8e8", "e1e8"])
    }

    @Test func anExportWithOnlyThePreparationAndNoMovesIsRefused() {
        let text = "[FEN \"\(Self.corridorFEN)\"]\n[PuzzleSetup \"a7a6\"]\n\n*"
        #expect(PuzzleCollectionImporter.parse(text).skipped.map(\.reason) == [.noMoves])
    }
}
