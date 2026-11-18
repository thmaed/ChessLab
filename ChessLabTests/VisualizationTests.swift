import Foundation
import Testing
@testable import ChessLab

/// Le module Visualisation (18/11/2026) : la règle, sans écran. Pendant Android : `VisualizationTest`.
struct VisualizationTests {
    /// Un hasard réglé : les tests rejouent toujours la même suite.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func sq(_ n: String) -> VisualizationSquare { VisualizationSquare(n)! }

    @Test func squareColours() {
        #expect(!sq("a1").isLight)
        #expect(sq("h1").isLight)
        #expect(!sq("h8").isLight)
        #expect(sq("e4").isLight)
        #expect(!sq("d4").isLight)
        #expect(VisualizationGenerator.squareColor(sq("e5")).answer == .dark)
    }

    @Test func notationRoundTrips() {
        for s in VisualizationSquare.all { #expect(VisualizationSquare(s.notation) == s) }
        #expect(VisualizationSquare("i1") == nil)
        #expect(VisualizationSquare("a9") == nil)
    }

    @Test func knightDistances() {
        #expect(KnightDistance.between(sq("g1"), sq("f3")) == 1)
        #expect(KnightDistance.between(sq("g1"), sq("e5")) == 2)
        #expect(KnightDistance.between(sq("b1"), sq("f5")) % 2 == 0, "même couleur : un nombre pair de coups")
        #expect(KnightDistance.between(sq("a1"), sq("b2")) == 4)
        #expect(KnightDistance.between(sq("a1"), sq("h8")) == 6)
        let longest = VisualizationSquare.all.flatMap { a in VisualizationSquare.all.map { KnightDistance.between(a, $0) } }.max()
        #expect(longest == 6, "les réponses 1 à 6 couvrent tous les trajets")
    }

    @Test func diagonals() {
        #expect(VisualizationDiagonal.named("a1–h8")?.squares.count == 8)
        #expect(VisualizationDiagonal.named("h1–a8")?.squares.count == 8)
        #expect(VisualizationDiagonal.named("f1–a6")?.squares.count == 6)
        #expect(VisualizationDiagonal.all.allSatisfy { $0.squares.count >= 3 })
        #expect(VisualizationDiagonal.all.count == 22, "11 dans chaque sens, d'au moins trois cases")
        #expect(sq("c1").sharesDiagonal(with: sq("h6")))
        #expect(!sq("c1").sharesDiagonal(with: sq("h5")))
    }

    @Test func eachGeneratedQuestionIsRightAndOffersItsAnswer() {
        var rng = Seeded(state: 42)
        for kind in VisualizationKind.allCases {
            for _ in 0..<200 {
                let q = VisualizationGenerator.question(kind, using: &rng)
                #expect(q.kind == kind)
                if kind != .findSquare {
                    #expect(q.choices.contains(q.answer), "\(kind) : la réponse est proposée")
                    #expect(Set(q.choices).count == q.choices.count, "\(kind) : pas de choix en double")
                }
                switch kind {
                case .squareColor: #expect(q.answer == (q.squares[0].isLight ? .light : .dark))
                case .sameDiagonal: #expect(q.answer == (q.squares[0].sharesDiagonal(with: q.squares[1]) ? .yes : .no))
                case .lineIntersection:
                    let s = q.squares[0]
                    #expect(q.line!.contains(s) && q.diagonal!.squares.contains(s))
                    #expect(q.choices.count == 4)
                case .knightDistance:
                    #expect(q.squares[0] != q.squares[1])
                    #expect(q.answer == .number(KnightDistance.between(q.squares[0], q.squares[1])))
                case .nameSquare: #expect(q.choices.count == 4)
                case .findSquare: #expect(q.answer == .square(q.squares[0]))
                case .pathCheck:
                    #expect(q.moves.count == 4)
                    #expect(q.answer == (VisualizationGenerator.isLegalPath(q.moves[0].kind, q.moves.map(\.square)) ? .yes : .no))
                case .attackAfter:
                    #expect(q.moves.count == 3)
                    #expect(VisualizationGenerator.isLegalPath(q.moves[0].kind, q.moves.map(\.square)), "le trajet est jouable")
                    let hit = VisualizationAttacks.from(q.moves[0].kind, at: q.moves.last!.square).contains(q.squares[0])
                    #expect(q.answer == (hit ? .yes : .no))
                case .twoPieces:
                    #expect(q.pieces.count == 2 && q.moves.count == 3)
                    #expect(q.pieces[0].kind != q.pieces[1].kind)
                case .isCheck, .squareAttacked:
                    #expect(q.pieces.filter { $0.kind == .king }.count == 2)
                    #expect(Set(q.pieces.map(\.square)).count == q.pieces.count, "une pièce par case")
                    #expect(q.pieces.filter { $0.kind == .pawn }.allSatisfy { (1...6).contains($0.square.rank) })
                case .hangingPiece:
                    let hung = VisualizationGenerator.hanging(in: q.pieces)
                    #expect(hung.count <= 1, "une réponse, pas deux")
                    #expect(q.answer == (hung.first.map { .square($0.square) } ?? .option("none")))
                }
            }
        }
    }

    @Test func sameDiagonalIsBalancedAndNeverTrivial() {
        var rng = Seeded(state: 7)
        var yes = 0
        for _ in 0..<400 {
            let q = VisualizationGenerator.question(.sameDiagonal, using: &rng)
            if q.answer == .yes {
                yes += 1
                #expect(abs(q.squares[0].file - q.squares[1].file) >= 2, "deux voisines, ce serait trop facile")
            }
        }
        #expect((140...260).contains(yes), "à peu près autant de oui que de non : \(yes)")
    }

    @Test func aMissedQuestionCanBeAskedAgainExactly() {
        var rng = Seeded(state: 3)
        for kind in VisualizationKind.allCases {
            let q = VisualizationGenerator.question(kind, using: &rng)
            let again = VisualizationGenerator.question(reviewKey: q.reviewKey, using: &rng)
            #expect(again?.reviewKey == q.reviewKey)
            #expect(again?.answer == q.answer)
        }
        #expect(VisualizationGenerator.question(reviewKey: "n'importe quoi", using: &rng) == nil)
    }

    @Test func aMissIsReviewedUntilTwoSuccesses() {
        var stats = VisualizationStats()
        let q = VisualizationGenerator.squareColor(sq("c6"))
        stats.record(q, correct: false)
        #expect(stats.reviewKeys(for: [.squareColor]) == [q.reviewKey])
        #expect(stats.reviewKeys(for: [.knightDistance]).isEmpty, "seulement parmi les exercices choisis")
        stats.record(q, correct: true)
        #expect(!stats.reviewKeys(for: [.squareColor]).isEmpty)
        stats.record(q, correct: true)
        #expect(stats.reviewKeys(for: [.squareColor]).isEmpty)
        #expect(stats.attempts(for: .squares) == 3)
        #expect(stats.accuracy(for: .squares) == 67)
        #expect(stats.accuracy(for: .lines) == nil)
    }

    @Test func theDrawerServesMissesAndNeverRepeatsBackToBack() {
        var rng = Seeded(state: 11)
        var stats = VisualizationStats()
        let missed = VisualizationGenerator.squareColor(sq("b7"))
        stats.record(missed, correct: false)
        var served = 0
        var previous: VisualizationQuestion?
        for _ in 0..<300 {
            let q = VisualizationDrawer.next(kinds: [.squareColor, .knightDistance], stats: stats, previous: previous, using: &rng)
            #expect(q.reviewKey != previous?.reviewKey)
            #expect([.squareColor, .knightDistance].contains(q.kind))
            if q.reviewKey == missed.reviewKey { served += 1 }
            previous = q
        }
        #expect(served > 30, "la question ratée revient souvent : \(served) fois sur 300")
    }

    @Test func settingsSurviveAndAnOldOrEmptySaveFallsBack() throws {
        var settings = VisualizationSettings()
        settings.steps = [.squares, .lines]
        settings.length = .oneMinute
        settings.fromBlack = true
        settings.secondsPerQuestion = 5
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(VisualizationSettings.self, from: data) == settings)
        let empty = try JSONDecoder().decode(VisualizationSettings.self, from: Data(#"{"steps":[]}"#.utf8))
        #expect(empty.steps == [.squares], "jamais aucune marche")
        #expect(VisualizationSettings().kinds == [.squareColor, .findSquare, .nameSquare])
    }

    // MARK: Lot 2

    @Test func attacksStopOnTheFirstOccupiedSquare() {
        let rook = VisualizationAttacks.from(.rook, at: sq("a1"), occupied: [sq("a4")])
        #expect(rook.contains(sq("a4")) && !rook.contains(sq("a5")))
        #expect(rook.contains(sq("h1")))
        #expect(VisualizationAttacks.from(.pawn, white: true, at: sq("e4")) == [sq("d5"), sq("f5")])
        #expect(VisualizationAttacks.from(.pawn, white: false, at: sq("e5")) == [sq("d4"), sq("f4")])
        #expect(VisualizationAttacks.from(.knight, at: sq("a1")) == [sq("b3"), sq("c2")])
    }

    @Test func twoPiecesSeeEachOtherAsObstacles() {
        // ♖ a1, ♗ c3 ; la tour monte en a4 ; le fou va en a5 — il masque la tour au-delà.
        let starts = [VisualizationPiece(.rook, sq("a1")), VisualizationPiece(.bishop, sq("c3"))]
        let moves = [VisualizationPiece(.rook, sq("a4")), VisualizationPiece(.bishop, sq("a5")), VisualizationPiece(.rook, sq("a3"))]
        #expect(VisualizationGenerator.twoPieces(starts, moves, target: sq("a6")).answer == .option("none"))
        #expect(VisualizationGenerator.twoPieces(starts, moves, target: sq("a4")).answer == .option("first"))
        #expect(VisualizationGenerator.twoPieces(starts, moves, target: sq("b6")).answer == .option("second"))
        #expect(VisualizationGenerator.twoPieces(starts, moves, target: sq("c3")).answer == .option("both"))
    }

    @Test func lot2AnswersAreBalanced() {
        var rng = Seeded(state: 21)
        var counts: [VisualizationKind: [VisualizationAnswer: Int]] = [:]
        for kind in [VisualizationKind.pathCheck, .attackAfter, .twoPieces, .isCheck, .squareAttacked] {
            for _ in 0..<120 { counts[kind, default: [:]][VisualizationGenerator.question(kind, using: &rng).answer, default: 0] += 1 }
        }
        for kind in [VisualizationKind.pathCheck, .attackAfter, .isCheck, .squareAttacked] {
            #expect((30...90).contains(counts[kind]?[.yes] ?? 0), "\(kind) : \(counts[kind] ?? [:])")
        }
        #expect(counts[.twoPieces]?.count == 4, "les quatre réponses sortent : \(counts[.twoPieces] ?? [:])")
    }

    @Test func aPositionReadsTheSameFromItsKey() {
        let position = VisualizationPiece.parse("Kg1,Qd1,Rf1,kg8,rd8,bc5")!
        #expect(VisualizationGenerator.isCheck(position).answer == .no)
        #expect(VisualizationPiece.parse("Kg1,Qh7,kg8")!.count == 3)
        #expect(VisualizationGenerator.isCheck(VisualizationPiece.parse("Kg1,Qh7,kg8")!).answer == .yes)
        #expect(VisualizationPiece.parse("Kg1,Xz9") == nil)
        #expect(VisualizationPiece(.knight, sq("g1")).figurine.unicodeScalars.first == "♘")
    }

    /// Le chrono grandit avec la marche : 5 s pour une case, 20 s pour une position.
    @Test func theTimerGrowsWithTheStep() {
        #expect(VisualizationKind.squareColor.seconds(base: 5) == 5)
        #expect(VisualizationKind.knightDistance.seconds(base: 5) == 10)
        #expect(VisualizationKind.twoPieces.seconds(base: 5) == 15)
        #expect(VisualizationKind.hangingPiece.seconds(base: 5) == 20)
        #expect(VisualizationKind.isCheck.seconds(base: 10) == 40)
    }
}
