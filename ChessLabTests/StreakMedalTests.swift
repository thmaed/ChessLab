import Foundation
import Testing
@testable import ChessLab

struct StreakMedalTests {

    @Test func paliersEtMedaille() {
        #expect(StreakMedal.earned(forStreak: 2) == nil)
        #expect(StreakMedal.earned(forStreak: 3) == .bronze)
        #expect(StreakMedal.earned(forStreak: 29) == .silver)
        #expect(StreakMedal.earned(forStreak: 30) == .gold)
        #expect(StreakMedal.earned(forStreak: 400) == .diamond)
        #expect(StreakMedal.next(afterStreak: 7) == .gold)
        #expect(StreakMedal.next(afterStreak: 365) == nil)
        #expect(StreakMedal.isMilestone(100))
        #expect(!StreakMedal.isMilestone(8))
    }

    @Test func comparaisonDeCycles() {
        func cycle(solved: Int, seconds: Double) -> WoodpeckerPlan.Cycle {
            var c = WoodpeckerPlan.Cycle(number: 1, order: Array(0..<10), startedAt: Date())
            c.attempts = (0..<10).map { WoodpeckerPlan.Attempt(solved: $0 < solved, seconds: seconds / 10) }
            return c
        }
        let c = CycleComparison(previous: cycle(solved: 8, seconds: 200), current: cycle(solved: 9, seconds: 100))
        #expect(c.isProgress)
        #expect(c.previousTime == 1)
        #expect(abs(c.currentTime - 0.5) < 0.001)
        #expect(c.secondsSaved == 100)
        let worse = CycleComparison(previous: cycle(solved: 9, seconds: 100), current: cycle(solved: 7, seconds: 80))
        #expect(!worse.isProgress)
    }
}
