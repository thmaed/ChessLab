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

    // MARK: Le plan tel qu'il est gardé (compressé, sous la limite d'iCloud)

    /// 1 000 puzzles réalistes (FEN de 40 caractères, solution de 1 à 5 coups), `cycles` cycles bouclés.
    private func bigPlan(cycles: Int) -> WoodpeckerPlan {
        var generator = SeededGenerator(state: 7)
        let big = (0..<1000).map { index in
            WoodpeckerPlan.Item(
                fen: "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)",
                solutionLANs: Array(["e3e8", "a8e8", "e1e8", "g8f7", "e8e7"].prefix(1 + 2 * (index % 3))),
                themeRaw: "checkmate", phaseRaw: "endgame", rating: 800 + index, setupLAN: "a7a6"
            )
        }
        var plan = WoodpeckerPlan.start(items: big, at: start, using: &generator)!
        for cycle in 0..<cycles {
            for step in 0..<1000 {
                plan.record(solved: step % 5 != 0, seconds: 3.7 + Double((step * 7919) % 5300) / 100, at: start)
            }
            if cycle < cycles - 1 { plan.startNextCycle(at: start, using: &generator) }
        }
        return plan
    }

    @Test func storedDataReadsBackTheSamePlan() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(5), at: start))
        plan.record(solved: true, seconds: 12.5, at: start)
        let data = try #require(plan.storedData)
        #expect(WoodpeckerPlan(storedData: data) == plan)
    }

    @Test func aPlanWrittenBeforeCompressionStillReads() throws {
        // Du JSON brut, comme avant : il commence par « { », jamais par l'octet nul du format compressé.
        let plan = try #require(WoodpeckerPlan.start(items: items(5), at: start))
        let legacy = try JSONEncoder().encode(plan)
        #expect(legacy.first == UInt8(ascii: "{"))
        #expect(WoodpeckerPlan(storedData: legacy) == plan)
    }

    @Test func garbageDoesNotReadAsAPlan() {
        #expect(WoodpeckerPlan(storedData: Data([0, 1, 2, 3])) == nil)
        #expect(WoodpeckerPlan(storedData: Data()) == nil)
    }

    /// Un petit plan reste du JSON BRUT : les versions 2.0 et 2.1 le relisent via iCloud (revue du 08/11/2026).
    @Test func aSmallPlanStaysPlainJSONForOlderVersions() throws {
        let plan = try #require(WoodpeckerPlan.start(items: items(20), at: start))
        let program = WoodpeckerProgram()
        program.plan = plan
        #expect(program.planData?.first == UInt8(ascii: "{"), "du JSON brut, lisible partout")
        #expect(program.plan == plan)
        // Ce que lit une ancienne version : le JSON, tel quel.
        let olderBuild = try JSONDecoder().decode(WoodpeckerPlan.self, from: try #require(program.planData))
        #expect(olderBuild == plan)
    }

    @Test func aHugePlanIsCompressedAndReadsBack() throws {
        let plan = bigPlan(cycles: 20)
        let program = WoodpeckerProgram()
        program.plan = plan
        #expect(program.planData?.first == 0, "au-delà du seuil : l'octet nul puis le JSON compressé")
        #expect(program.plan == plan)
    }

    @Test func aThousandPuzzlesStayWellUnderTheCloudKitLimit() throws {
        // Un enregistrement CloudKit pèse au plus 1 Mo : vingt cycles de 1 000 puzzles en font ~1 Mo en JSON brut (970 Ko ici, davantage avec des temps réels
        // à longues décimales) et ~130 Ko une fois compressés.
        let plan = bigPlan(cycles: 20)
        let raw = try JSONEncoder().encode(plan).count
        #expect(raw > 900_000)
        let stored = try #require(plan.storedData).count
        #expect(raw > WoodpeckerPlan.compressionThreshold)
        #expect(stored < 500_000)
        #expect(stored < raw / 3)
        #expect(WoodpeckerPlan(storedData: try #require(plan.storedData)) == plan)
    }

    @Test func formatsDurations() {
        #expect(WoodpeckerPlan.formatDuration(0) == "0:00")
        #expect(WoodpeckerPlan.formatDuration(425) == "7:05")
        #expect(WoodpeckerPlan.formatDuration(3723) == "1:02:03")
    }
}
