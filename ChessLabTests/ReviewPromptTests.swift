import Foundation
import Testing
@testable import ChessLab

/// La règle de la demande d'avis : après une réussite, à quelqu'un qui revient,
/// une fois par version, et pas plus d'une fois tous les 120 jours.
struct ReviewPromptTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func ready(_ change: (inout ReviewPromptPolicy) -> Void = { _ in }) -> ReviewPromptPolicy {
        var policy = ReviewPromptPolicy(positiveMoments: 2, trainingDays: 3)
        change(&policy)
        return policy
    }

    @Test func asksOnceTheThresholdsAreReached() {
        #expect(ready().shouldAsk(version: "2.1", now: now))
    }

    @Test func waitsForEnoughSuccessesAndDays() {
        #expect(!ready { $0.positiveMoments = 1 }.shouldAsk(version: "2.1", now: now))
        #expect(!ready { $0.trainingDays = 2 }.shouldAsk(version: "2.1", now: now))
    }

    @Test func neverTwiceForTheSameVersion() {
        #expect(!ready { $0.lastAskedVersion = "2.1"; $0.lastAskedAt = now.addingTimeInterval(-400 * 86_400) }
            .shouldAsk(version: "2.1", now: now))
    }

    @Test func aNewVersionStillWaitsOneHundredTwentyDays() {
        let recently = ready { $0.lastAskedVersion = "2.0"; $0.lastAskedAt = now.addingTimeInterval(-30 * 86_400) }
        #expect(!recently.shouldAsk(version: "2.1", now: now))
        let longAgo = ready { $0.lastAskedVersion = "2.0"; $0.lastAskedAt = now.addingTimeInterval(-121 * 86_400) }
        #expect(longAgo.shouldAsk(version: "2.1", now: now))
    }

    @MainActor
    @Test func recordingCountsAndMarksTheAsk() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewPromptTests"))
        defaults.removePersistentDomain(forName: "ReviewPromptTests")
        defer { defaults.removePersistentDomain(forName: "ReviewPromptTests") }
        // Trois jours d'entraînement, comme `TrainingDays` les range.
        defaults.set(["2026-10-01", "2026-10-02", "2026-10-03"], forKey: "trainingDays.v1")

        #expect(!ReviewPrompt.recordPositiveMoment(defaults: defaults, now: now))   // 1re réussite
        #expect(ReviewPrompt.recordPositiveMoment(defaults: defaults, now: now))    // 2e : on demande
        #expect(!ReviewPrompt.recordPositiveMoment(defaults: defaults, now: now))   // déjà demandé
    }
}
