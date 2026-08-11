import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

@MainActor
@Suite(.serialized)
struct OpeningTrainViewModelTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: OpeningPositionProgress.self)
        try context.delete(model: OpeningReviewLog.self)
        try context.delete(model: RepertoireMembership.self)
        try context.save()
        return context
    }

    private var rootKey: String { OpeningFENKey.key(for: .standard) }

    /// Cours à un coup : blancs au trait à la racine, coup attendu e4, puis feuille.
    private func singleCardCourse() -> OpeningCourse {
        let root = OpeningFENKey.key(for: .standard)
        var b = Board(position: .standard); _ = b.move(pieceAt: Square("e2"), to: Square("e4"))
        let k1 = OpeningFENKey.key(for: b.position)
        let e4 = MoveEdge(san: "e4", uci: "e2e4", toFEN: k1, role: .mainLine,
                          comment: .both("Contrôle le centre."), commentStatus: .validated)
        return OpeningCourse(id: "c", name: "C", side: .white, rootFEN: root,
                             positions: [root: PositionNode(fen: root, moves: [e4]), k1: PositionNode(fen: k1)])
    }

    /// Racine avec DEUX coups : principale e4, variante d4.
    private func branchingCourse() -> OpeningCourse {
        let root = OpeningFENKey.key(for: .standard)
        var be = Board(position: .standard); _ = be.move(pieceAt: Square("e2"), to: Square("e4"))
        let kE = OpeningFENKey.key(for: be.position)
        var bd = Board(position: .standard); _ = bd.move(pieceAt: Square("d2"), to: Square("d4"))
        let kD = OpeningFENKey.key(for: bd.position)
        let e4 = MoveEdge(san: "e4", uci: "e2e4", toFEN: kE, role: .mainLine)
        let d4 = MoveEdge(san: "d4", uci: "d2d4", toFEN: kD, role: .sideline)
        return OpeningCourse(id: "c", name: "C", side: .white, rootFEN: root,
                             positions: [root: PositionNode(fen: root, moves: [e4, d4]),
                                         kE: PositionNode(fen: kE), kD: PositionNode(fen: kD)])
    }

    private func vm(_ mode: OpeningTrainViewModel.Mode = .daily, _ context: ModelContext, course: OpeningCourse) -> OpeningTrainViewModel {
        OpeningTrainViewModel(mode: mode, context: context, courses: ["c": course], synchronousOpponent: true)
    }

    private func lastLogRating(in context: ModelContext, fen: String) throws -> Int? {
        let logs = try context.fetch(FetchDescriptor<OpeningReviewLog>())
        return logs.first(where: { $0.fenKey == fen })?.ratingRaw
    }

    @Test func dailySessionStartsAwaitingOnACourse() throws {
        let context = try makeContext()
        let course = OpeningGraphFixtures.linearCourse(id: "c", name: "Italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"], side: .white)
        let model = vm(.daily, context, course: course)
        #expect(model.phase == .awaiting)          // trait aux blancs à la racine
        #expect(model.courseName == "Italienne")
    }

    @Test func correctMoveRecordsGoodAndFlows() throws {
        let context = try makeContext()
        let model = vm(.daily, context, course: singleCardCourse())

        model.attemptMove(from: Square("e2"), to: Square("e4"))
        // Un seul coup dans le cours → la ligne se termine tout de suite (auto-avance).
        #expect(model.phase == .complete)
        #expect(model.reviewedCount == 1)
        #expect(model.currentComment == "Contrôle le centre.")   // commentaire du coup joué
        #expect(model.playedSANs == ["e4"])

        let progress = try #require(OpeningProgressStore.progress(forFEN: rootKey, in: context))
        #expect(progress.reps == 1)
        #expect(progress.dueDate != nil)
        #expect(try lastLogRating(in: context, fen: rootKey) == FSRSRating.good.rawValue)
    }

    @Test func wrongMoveShowsCorrectionAndRecordsAgain() throws {
        let context = try makeContext()
        let model = vm(.daily, context, course: singleCardCourse())

        model.attemptMove(from: Square("d2"), to: Square("d4"))   // coup hors répertoire
        #expect(model.phase == .wrong)
        #expect(model.wrongCorrectSAN == "e4")                    // le bon coup est révélé
        #expect(!model.hintMoves.isEmpty)                          // flèche du bon coup
        #expect(try lastLogRating(in: context, fen: rootKey) == FSRSRating.again.rawValue)

        model.continueAfterWrong()                                // joue e4 et poursuit
        #expect(model.playedSANs == ["e4"])
        #expect(model.phase == .complete)

        let progress = try #require(OpeningProgressStore.progress(forFEN: rootKey, in: context))
        #expect(progress.reps == 1)
        #expect(progress.stateRaw == FSRSState.learning.rawValue)  // « again » sur une neuve → learning
    }

    @Test func usingHintCapsRatingAtHard() throws {
        let context = try makeContext()
        let model = vm(.daily, context, course: singleCardCourse())

        model.showHint()
        #expect(model.usedHint)
        #expect(!model.hintMoves.isEmpty)
        model.attemptMove(from: Square("e2"), to: Square("e4"))    // juste, MAIS indice utilisé
        #expect(model.phase == .complete)
        #expect(try lastLogRating(in: context, fen: rootKey) == FSRSRating.hard.rawValue)
    }

    @Test func variationPromptThenPlayVariation() throws {
        let context = try makeContext()
        let model = OpeningTrainViewModel(mode: .fullLine(courseID: "c"), context: context,
                                          courses: ["c": branchingCourse()], synchronousOpponent: true)
        model.attemptMove(from: Square("d2"), to: Square("d4"))    // variante
        #expect(model.phase == .variation)
        #expect(model.variationPlayedSAN == "d4")
        #expect(model.variationMainSAN == "e4")

        model.playVariation()
        #expect(model.playedSANs == ["d4"])                        // on a suivi la variante
        #expect(model.phase == .complete)
    }

    @Test func variationKeepMainLinePlaysMainAndNotes() throws {
        let context = try makeContext()
        let model = OpeningTrainViewModel(mode: .fullLine(courseID: "c"), context: context,
                                          courses: ["c": branchingCourse()], synchronousOpponent: true)
        model.attemptMove(from: Square("d2"), to: Square("d4"))    // variante
        #expect(model.phase == .variation)

        model.keepMainLine()
        #expect(model.playedSANs == ["e4"])                        // on a joué la principale
        #expect(model.currentComment?.contains("d4") == true)      // note « aussi jouable : d4 »
        #expect(model.phase == .complete)
    }

    @Test func opponentAutoPlaysBetweenUserMoves() throws {
        let context = try makeContext()
        let course = OpeningGraphFixtures.linearCourse(id: "c", name: "Ligne", sans: ["e4", "e5", "Nf3"], side: .white)
        let model = OpeningTrainViewModel(mode: .fullLine(courseID: "c"), context: context,
                                          courses: ["c": course], synchronousOpponent: true)

        model.attemptMove(from: Square("e2"), to: Square("e4"))    // notre coup
        // La riposte adverse (e5) est jouée automatiquement, puis c'est de nouveau à nous.
        #expect(model.playedSANs == ["e4", "e5"])
        #expect(model.phase == .awaiting)

        model.attemptMove(from: Square("g1"), to: Square("f3"))    // notre 2e coup → fin de ligne
        #expect(model.playedSANs == ["e4", "e5", "Nf3"])
        #expect(model.phase == .complete)
    }

    @Test func emptyWhenNoTrainablePositions() throws {
        let context = try makeContext()
        // Cours côté noir mais racine blanche sans suite → aucune position noire entraînable.
        let root = OpeningFENKey.key(for: .standard)
        let course = OpeningCourse(id: "c", name: "C", side: .black, rootFEN: root,
                                   positions: [root: PositionNode(fen: root)])
        let model = OpeningTrainViewModel(mode: .daily, context: context, courses: ["c": course])
        #expect(model.phase == .empty)
    }
}
