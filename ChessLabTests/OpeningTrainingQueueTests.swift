import ChessKit
import Foundation
import Testing
@testable import ChessLab

@MainActor
struct OpeningTrainingQueueTests {

    private func italian() -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(
            id: "ital", name: "Italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"], side: .white
        )
    }

    @Test func trainableCardsAreStudySideToMoveWithAMainLine() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        // Blancs au trait : avant e4, avant Nf3, avant Bc4 → 3 cartes.
        #expect(cards.count == 3)
        #expect(Set(cards.map(\.expectedSAN)) == ["e4", "Nf3", "Bc4"])
        #expect(cards.allSatisfy { OpeningFENKey.position(from: $0.fenKey)?.sideToMove == .white })
    }

    @Test func dailyQueuePutsDueFirstThenNewCappedExcludingNotDue() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var progress: [String: OpeningProgressSnapshot] = [:]
        // carte 0 : due (échéance passée) ; carte 1 : pas due (future) ; carte 2 : neuve.
        progress[cards[0].fenKey] = OpeningProgressSnapshot(dueDate: now.addingTimeInterval(-86_400), lapses: 0, stability: 5, reps: 1)
        progress[cards[1].fenKey] = OpeningProgressSnapshot(dueDate: now.addingTimeInterval(86_400), lapses: 0, stability: 5, reps: 1)

        let queue = OpeningTrainingQueue.dailyQueue(cards: cards, progress: progress, now: now, newLimit: 20)
        #expect(queue == [cards[0], cards[2]])   // due d'abord, puis la neuve ; la future exclue
    }

    @Test func dailyQueueCapsNewCards() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())   // 3 neuves
        let queue = OpeningTrainingQueue.dailyQueue(cards: cards, progress: [:], now: Date(), newLimit: 2)
        #expect(queue.count == 2)
    }

    @Test func dailyQueueDedupesByFEN() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        let doubled = cards + cards   // même position deux fois
        let queue = OpeningTrainingQueue.dailyQueue(cards: doubled, progress: [:], now: Date(), newLimit: 20)
        #expect(queue.count == cards.count)
    }

    @Test func hardestQueueKeepsOnlyFailedSortedByLapses() {
        let cards = OpeningTrainingQueue.trainableCards(of: italian())
        var progress: [String: OpeningProgressSnapshot] = [:]
        progress[cards[0].fenKey] = OpeningProgressSnapshot(dueDate: nil, lapses: 1, stability: 3, reps: 2)
        progress[cards[1].fenKey] = OpeningProgressSnapshot(dueDate: nil, lapses: 4, stability: 1, reps: 5)
        // carte 2 : jamais ratée → exclue.

        let queue = OpeningTrainingQueue.hardestQueue(cards: cards, progress: progress)
        #expect(queue == [cards[1], cards[0]])   // 4 échecs avant 1 échec
    }

    @Test func lineCardsFollowMainLineOrderForStudySide() {
        let cards = OpeningTrainingQueue.lineCards(of: italian())
        #expect(cards.map(\.expectedSAN) == ["e4", "Nf3", "Bc4"])   // dans l'ordre de la ligne
    }
}
