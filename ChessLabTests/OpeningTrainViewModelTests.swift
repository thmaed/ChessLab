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

    /// Cours à une seule carte : blancs au trait à la racine, coup attendu e4.
    private func singleCardCourse() -> OpeningCourse {
        let root = OpeningFENKey.key(for: .standard)
        var b = Board(position: .standard); _ = b.move(pieceAt: Square("e2"), to: Square("e4"))
        let k1 = OpeningFENKey.key(for: b.position)
        let e4 = MoveEdge(san: "e4", uci: "e2e4", toFEN: k1, role: .mainLine,
                          comment: .both("Contrôle le centre."), commentStatus: .validated)
        return OpeningCourse(id: "c", name: "C", side: .white, rootFEN: root,
                             positions: [root: PositionNode(fen: root, moves: [e4]), k1: PositionNode(fen: k1)])
    }

    private func vm(_ mode: OpeningTrainViewModel.Mode = .daily, _ context: ModelContext, course: OpeningCourse) -> OpeningTrainViewModel {
        OpeningTrainViewModel(mode: mode, context: context, courses: ["c": course])
    }

    @Test func dailyQueueCountsNewPositions() throws {
        let context = try makeContext()
        let course = OpeningGraphFixtures.linearCourse(id: "c", name: "Italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"], side: .white)
        let model = vm(.daily, context, course: course)
        #expect(model.total == 3)          // 3 positions blanches neuves
        #expect(model.phase == .awaiting)
    }

    @Test func correctMoveThenGoodRecordsAndAdvances() throws {
        let context = try makeContext()
        let course = singleCardCourse()
        let model = vm(.daily, context, course: course)
        let card = try #require(model.currentCard)

        model.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(model.phase == .correct)
        #expect(model.currentComment == "Contrôle le centre.")
        #expect(model.ratingOptions == [.hard, .good, .easy])

        model.grade(.good)
        #expect(model.reviewedCount == 1)
        #expect(model.phase == .complete)

        // Progression enregistrée ET journalisée (donc synchronisable).
        let progress = try #require(OpeningProgressStore.progress(forFEN: card.fenKey, in: context))
        #expect(progress.reps == 1)
        #expect(progress.dueDate != nil)
        #expect(try context.fetchCount(FetchDescriptor<OpeningReviewLog>()) == 1)
    }

    @Test func wrongMoveShowsCorrectionAndRecordsAgain() throws {
        let context = try makeContext()
        let course = singleCardCourse()
        let model = vm(.daily, context, course: course)
        let card = try #require(model.currentCard)

        model.attemptMove(from: Square("d2"), to: Square("d4"))   // mauvais coup
        #expect(model.phase == .wrong)
        #expect(model.ratingOptions == [.again])
        #expect(!model.hintMoves.isEmpty)                          // bon coup révélé

        model.grade(.again)
        let progress = try #require(OpeningProgressStore.progress(forFEN: card.fenKey, in: context))
        #expect(progress.reps == 1)
        #expect(progress.stateRaw == FSRSState.learning.rawValue)  // « again » sur une neuve → learning
    }

    @Test func usingHintCapsRatingAtHard() throws {
        let context = try makeContext()
        let model = vm(.daily, context, course: singleCardCourse())

        model.showHint()
        #expect(model.usedHint)
        model.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(model.phase == .correct)
        #expect(model.ratingOptions == [.hard])                    // Facile/Bien retirés
    }

    @Test func fullLineModeDisablesHints() throws {
        let context = try makeContext()
        let course = OpeningGraphFixtures.linearCourse(id: "c", name: "Italienne", sans: ["e4", "e5", "Nf3"], side: .white)
        let model = OpeningTrainViewModel(mode: .fullLine(courseID: "c"), context: context, courses: ["c": course])
        #expect(!model.allowsHints)
        model.showHint()
        #expect(!model.usedHint)   // sans filet : l'indice ne fait rien
    }

    @Test func emptyWhenNoTrainablePositions() throws {
        let context = try makeContext()
        // Cours côté noir mais racine blanche sans suite → aucune position noire entraînable.
        let root = OpeningFENKey.key(for: .standard)
        let course = OpeningCourse(id: "c", name: "C", side: .black, rootFEN: root,
                                   positions: [root: PositionNode(fen: root)])
        let model = OpeningTrainViewModel(mode: .daily, context: context, courses: ["c": course])
        #expect(model.total == 0)
        #expect(model.phase == .empty)
    }
}
