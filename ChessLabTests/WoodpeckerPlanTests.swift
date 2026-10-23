import Foundation
import Testing
@testable import ChessLab

/// Le plan d'un programme Woodpecker — valeur pure, sans base ni horloge.
struct WoodpeckerPlanTests {

    /// Générateur déterministe : l'ordre mélangé se vérifie sans hasard.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private func items(_ count: Int) -> [WoodpeckerPlan.Item] {
        (0..<count).map { WoodpeckerPlan.Item(fen: "fen\($0)", solutionLANs: ["e2e4"]) }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func aNewProgramVisitsEveryPuzzleOnceInTheFirstCycle() throws {
        var generator = SeededGenerator(state: 42)
        let plan = try #require(WoodpeckerPlan.start(items: items(50), at: start, using: &generator))
        #expect(plan.cycles.count == 1)
        #expect(plan.currentCycle.number == 1)
        #expect(Set(plan.currentCycle.order) == Set(0..<50))
        #expect(plan.currentCycle.order.count == 50)
        #expect(plan.currentItemIndex == plan.currentCycle.order[0])
    }

    @Test func noProgramWithoutPuzzles() {
        #expect(WoodpeckerPlan.start(items: []) == nil)
    }

    @Test func answersAdvanceThroughTheCycleAndCloseIt() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(3), at: start))
        let order = plan.currentCycle.order
        plan.record(solved: true, seconds: 10, at: start)
        #expect(plan.currentItemIndex == order[1])
        plan.record(solved: false, seconds: 20, at: start)
        plan.record(solved: true, seconds: 30, at: start.addingTimeInterval(60))

        #expect(plan.currentItemIndex == nil)
        #expect(plan.currentCycle.isComplete)
        #expect(plan.currentCycle.solvedCount == 2)
        #expect(plan.currentCycle.activeSeconds == 60)
        #expect(plan.currentCycle.finishedAt == start.addingTimeInterval(60))

        // Cycle bouclé : une réponse de plus ne compte pas.
        plan.record(solved: true, seconds: 99)
        #expect(plan.currentCycle.attempts.count == 3)
    }

    @Test func theNextCycleReplaysTheSameSetInANewOrder() throws {
        var generator = SeededGenerator(state: 7)
        var plan = try #require(WoodpeckerPlan.start(items: items(25), at: start, using: &generator))
        // Pas de nouveau cycle tant que le premier n'est pas fini.
        plan.startNextCycle(at: start, using: &generator)
        #expect(plan.cycles.count == 1)

        for _ in 0..<25 { plan.record(solved: true, seconds: 4) }
        let firstOrder = plan.currentCycle.order
        plan.startNextCycle(at: start, using: &generator)

        #expect(plan.cycles.count == 2)
        #expect(plan.currentCycle.number == 2)
        #expect(Set(plan.currentCycle.order) == Set(0..<25))
        #expect(plan.currentCycle.order != firstOrder, "mélangé à chaque cycle (décision du 23/10)")
        #expect(plan.previousCycle?.number == 1)
        #expect(plan.items.count == 25, "le lot reste le même")
    }

    @Test func theTargetIsHalfTheLastFinishedCycle() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(2), at: start))
        #expect(plan.nextCycleTargetSeconds == nil)
        plan.record(solved: true, seconds: 100)
        plan.record(solved: true, seconds: 140)
        #expect(plan.nextCycleTargetSeconds == 120)
    }

    @Test func negativeTimesAreIgnored() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(1), at: start))
        plan.record(solved: true, seconds: -5)
        #expect(plan.currentCycle.activeSeconds == 0)
    }

    @Test func survivesAJSONRoundTrip() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(4), at: start))
        plan.record(solved: true, seconds: 12.5, at: start)
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(WoodpeckerPlan.self, from: data) == plan)
    }

    @Test func formatsDurations() {
        #expect(WoodpeckerPlan.formatDuration(0) == "0:00")
        #expect(WoodpeckerPlan.formatDuration(425) == "7:05")
        #expect(WoodpeckerPlan.formatDuration(3723) == "1:02:03")
    }
}
