import Foundation
import SwiftData
import Testing
@testable import ChessLab

struct OpeningCoverageTests {

    private func italian() -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(
            id: "ital", name: "Italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"], side: .white
        )
    }

    private func snap(_ stability: Double, reps: Int = 1, due: Date? = nil) -> OpeningProgressSnapshot {
        OpeningProgressSnapshot(dueDate: due, lapses: 0, stability: stability, reps: reps)
    }

    @Test func notStartedWhenNoProgress() {
        let cover = OpeningCoverage.compute(course: italian(), progress: [:])
        #expect(cover.total == 3)
        #expect(cover.seen == 0)
        #expect(cover.badge == .notStarted)
        #expect(cover.unseen == 3)
    }

    @Test func discoveryWhenFewSeen() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        let progress = [cards[0].fenKey: snap(3)]                 // 1/3 vues
        let cover = OpeningCoverage.compute(course: italian(), progress: progress)
        #expect(cover.seen == 1)
        #expect(cover.badge == .discovery)
    }

    @Test func workedWhenHalfSeenButNotMastered() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        let progress = [cards[0].fenKey: snap(3), cards[1].fenKey: snap(3)]  // 2/3 vues, 0 maîtrisées
        let cover = OpeningCoverage.compute(course: italian(), progress: progress)
        #expect(cover.seenFraction > 0.6)
        #expect(cover.mastered == 0)
        #expect(cover.badge == .worked)
    }

    @Test func solidWhenMostlyMastered() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        var progress: [String: OpeningProgressSnapshot] = [:]
        for card in cards { progress[card.fenKey] = snap(40) }    // stabilité ≥ 21 → maîtrisées
        let cover = OpeningCoverage.compute(course: italian(), progress: progress)
        #expect(cover.mastered == 3)
        #expect(cover.badge == .solid)
    }

    @Test func dueCountsSeenPositionsPastTheirDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        let progress = [
            cards[0].fenKey: snap(3, due: now.addingTimeInterval(-100)),  // due
            cards[1].fenKey: snap(3, due: now.addingTimeInterval(100)),   // pas due
        ]
        let cover = OpeningCoverage.compute(course: italian(), progress: progress, now: now)
        #expect(cover.due == 1)
    }
}

@MainActor
@Suite(.serialized)
struct RepertoireStoreTests {
    private static let container: ModelContainer = {
        try! ModelContainer(
            for: OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: RepertoireMembership.self)
        try context.save()
        return context
    }

    @Test func toggleAddsThenRemoves() throws {
        let context = try makeContext()
        #expect(!RepertoireStore.isMember("scandi", in: context))

        let added = RepertoireStore.toggle(courseID: "scandi", side: .black, in: context)
        #expect(added)
        #expect(RepertoireStore.isMember("scandi", in: context))
        #expect(RepertoireStore.memberIDs(in: context) == ["scandi"])

        let removed = RepertoireStore.toggle(courseID: "scandi", side: .black, in: context)
        #expect(!removed)
        #expect(!RepertoireStore.isMember("scandi", in: context))
        #expect(RepertoireStore.memberIDs(in: context).isEmpty)
    }
}
