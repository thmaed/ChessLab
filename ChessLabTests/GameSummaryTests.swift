import ChessKit
import Testing
@testable import ChessLab

/// Bilan de partie (agrégation par joueur) et critère « coup de théorie ».
struct GameSummaryTests {

    // MARK: GameSummary

    @Test func countsAreSplitByColor() {
        let summary = GameSummary.compute(
            qualities: [
                (color: .white, quality: .best),
                (color: .black, quality: .blunder),
                (color: .white, quality: .best),
                (color: .black, quality: .good),
                (color: .white, quality: .miss),
            ],
            totalMainLineMoves: 5,
            accuracyByColor: [.white: 91.5, .black: 60.2]
        )

        #expect(summary.white.count(of: .best) == 2)
        #expect(summary.white.count(of: .miss) == 1)
        #expect(summary.white.count(of: .blunder) == 0)
        #expect(summary.black.count(of: .blunder) == 1)
        #expect(summary.black.count(of: .good) == 1)
        #expect(summary.white.accuracy == 91.5)
        #expect(summary.black.accuracy == 60.2)
        #expect(summary.isComplete)
    }

    @Test func partialClassificationIsReportedAsIncomplete() {
        // 3 coups classifiés sur 10 : le bilan doit le dire, pas faire
        // passer un décompte partiel pour un décompte définitif.
        let summary = GameSummary.compute(
            qualities: [
                (color: .white, quality: .book),
                (color: .black, quality: .book),
                (color: .white, quality: .excellent),
            ],
            totalMainLineMoves: 10,
            accuracyByColor: [:]
        )

        #expect(!summary.isComplete)
        #expect(summary.white.classifiedCount == 2)
        #expect(summary.black.classifiedCount == 1)
        #expect(summary.white.accuracy == nil)
    }

    @Test func aGameWithoutMovesIsNeverComplete() {
        let summary = GameSummary.compute(qualities: [], totalMainLineMoves: 0, accuracyByColor: [:])
        #expect(!summary.isComplete)
    }

    // MARK: EcoOpeningLookup.isInBook

    private let database = [
        EcoOpening(eco: "C50", name: "Italienne", moves: ["e4", "e5", "Nf3", "Nc6", "Bc4"]),
        EcoOpening(eco: "B20", name: "Sicilienne", moves: ["e4", "c5"]),
    ]

    @Test func aPrefixOfTheoryIsInBook() {
        // La partie n'a pas encore quitté la ligne : chaque coup joué est
        // un coup de théorie, même si la base va plus loin.
        #expect(EcoOpeningLookup.isInBook(["e4"], in: database))
        #expect(EcoOpeningLookup.isInBook(["e4", "e5", "Nf3"], in: database))
        #expect(EcoOpeningLookup.isInBook(["e4", "e5", "Nf3", "Nc6", "Bc4"], in: database))
    }

    @Test func deviatingFromEveryLineLeavesTheBook() {
        #expect(!EcoOpeningLookup.isInBook(["e4", "e6"], in: database))
        #expect(!EcoOpeningLookup.isInBook(["d4"], in: database))
    }

    @Test func playingBeyondTheDeepestLineLeavesTheBook() {
        // Sens INVERSE de openingName : ici c'est la base qui doit
        // prolonger la partie. Un 6e coup après une ligne de 5 n'est plus
        // de la théorie, même si l'ouverture reste nommée.
        #expect(!EcoOpeningLookup.isInBook(["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"], in: database))
    }

    @Test func anEmptyPathIsNotABookMove() {
        #expect(!EcoOpeningLookup.isInBook([], in: database))
    }
}
