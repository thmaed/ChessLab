import Foundation
import Testing
@testable import ChessLab

struct SpacedRepetitionTests {

    @Test func firstSuccessGivesOneDayInterval() {
        let result = SpacedRepetition.next(after: .initial, success: true)
        #expect(result.repetitions == 1)
        #expect(result.intervalDays == 1)
    }

    @Test func secondConsecutiveSuccessGivesSixDayInterval() {
        let first = SpacedRepetition.next(after: .initial, success: true)
        let second = SpacedRepetition.next(after: first, success: true)
        #expect(second.repetitions == 2)
        #expect(second.intervalDays == 6)
    }

    @Test func thirdConsecutiveSuccessGrowsIntervalPastSixDays() {
        let first = SpacedRepetition.next(after: .initial, success: true)
        let second = SpacedRepetition.next(after: first, success: true)
        let third = SpacedRepetition.next(after: second, success: true)
        #expect(third.repetitions == 3)
        // Au-delà de la 2e répétition, l'intervalle croît par
        // multiplication avec l'easinessFactor (mis à jour) plutôt que
        // par les paliers fixes 1/6 jours — doit dépasser le palier
        // précédent sans qu'on ait à reproduire la formule interne ici.
        #expect(third.intervalDays > second.intervalDays)
    }

    @Test func failureResetsRepetitionsAndForcesNextDayReview() {
        let first = SpacedRepetition.next(after: .initial, success: true)
        let second = SpacedRepetition.next(after: first, success: true)
        let afterFailure = SpacedRepetition.next(after: second, success: false)
        #expect(afterFailure.repetitions == 0)
        #expect(afterFailure.intervalDays == 1)
    }

    @Test func easinessFactorNeverDropsBelowFloor() {
        var schedule = SpacedRepetition.Schedule.initial
        for _ in 0..<20 {
            schedule = SpacedRepetition.next(after: schedule, success: false)
        }
        #expect(schedule.easinessFactor >= 1.3)
    }

    @Test func dueDateAddsIntervalDaysToReference() {
        let reference = Date(timeIntervalSince1970: 0)
        let schedule = SpacedRepetition.Schedule(easinessFactor: 2.5, intervalDays: 6, repetitions: 2)
        let due = SpacedRepetition.dueDate(for: schedule, from: reference)
        #expect(due.timeIntervalSince(reference) == 6 * 24 * 3600)
    }
}
