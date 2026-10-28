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

    // MARK: Partiel

    @Test func partialReturnsInTwoDaysAndKeepsRepetitions() {
        let acquired = SpacedRepetition.Schedule(easinessFactor: 2.5, intervalDays: 6, repetitions: 2)
        let result = SpacedRepetition.next(after: acquired, outcome: .partial)
        #expect(result.intervalDays == SpacedRepetition.partialIntervalDays)
        #expect(result.repetitions == 2)
    }

    @Test func partialLowersEasinessLessThanMissedAndMoreThanMastered() {
        let start = SpacedRepetition.Schedule.initial
        let mastered = SpacedRepetition.next(after: start, outcome: .mastered).easinessFactor
        let partial = SpacedRepetition.next(after: start, outcome: .partial).easinessFactor
        let missed = SpacedRepetition.next(after: start, outcome: .missed).easinessFactor
        #expect(mastered > partial)
        #expect(partial > missed)
    }

    @Test func booleanOverloadStillMapsToMasteredAndMissed() {
        let start = SpacedRepetition.Schedule.initial
        #expect(SpacedRepetition.next(after: start, success: true) == SpacedRepetition.next(after: start, outcome: .mastered))
        #expect(SpacedRepetition.next(after: start, success: false) == SpacedRepetition.next(after: start, outcome: .missed))
    }

    @Test func outcomeClassification() {
        #expect(PuzzleOutcome.classify(solved: true, hadWrongAttempt: false, playerMovesFound: 3) == .mastered)
        #expect(PuzzleOutcome.classify(solved: true, hadWrongAttempt: true, playerMovesFound: 3) == .partial)
        #expect(PuzzleOutcome.classify(solved: false, hadWrongAttempt: true, playerMovesFound: 1) == .partial)
        #expect(PuzzleOutcome.classify(solved: false, hadWrongAttempt: true, playerMovesFound: 0) == .missed)
    }
}
