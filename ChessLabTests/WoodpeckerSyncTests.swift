import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Woodpecker et iCloud (17/11/2026) : une réponse = un petit enregistrement ; le plan entier ne s'écrit plus
/// qu'à la création et aux débuts de cycle. Avant, il repartait vers iCloud après CHAQUE puzzle (20 Ko pour 50
/// puzzles, 200 Ko pour une collection de 500).
struct WoodpeckerSyncTests {

    private func items(_ count: Int) -> [WoodpeckerPlan.Item] {
        (0..<count).map { WoodpeckerPlan.Item(fen: "fen\($0)", solutionLANs: ["e2e4"]) }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let program = UUID()

    private func logged(_ cycle: Int, _ step: Int, solved: Bool = true, at offset: Double = 0) -> WoodpeckerPlan.LoggedAttempt {
        WoodpeckerPlan.LoggedAttempt(cycle: cycle, step: step, attempt: .init(solved: solved, seconds: 10),
                                     at: start.addingTimeInterval(offset + Double(step)))
    }

    // MARK: La graine

    @Test func theSeededOrderIsTheSameOnEveryDevice_andVisitsEachPuzzleOnce() {
        let a = WoodpeckerPlan.seededOrder(count: 50, programID: program, cycle: 2)
        let b = WoodpeckerPlan.seededOrder(count: 50, programID: program, cycle: 2)
        #expect(a == b, "deux appareils, même programme, même cycle : même ordre")
        #expect(Set(a) == Set(0..<50))
        #expect(a != WoodpeckerPlan.seededOrder(count: 50, programID: program, cycle: 3), "un autre cycle, un autre ordre")
        #expect(a != WoodpeckerPlan.seededOrder(count: 50, programID: UUID(), cycle: 2), "un autre programme, un autre ordre")
    }

    // MARK: La fusion des réponses

    @Test func loggedAnswersFillTheCycle_inOrder_withoutGaps() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(5), at: start))
        // Places 0, 1, 3 : la 3 attend la 2 (pas de trou).
        plan.merge([logged(1, 0), logged(1, 1, solved: false), logged(1, 3)], programID: program)
        #expect(plan.currentCycle.attempts.map(\.solved) == [true, false])
        #expect(plan.currentItemIndex == plan.currentCycle.order[2])
    }

    @Test func twoDevicesAnsweringTheSameStep_countOnce_theEarliestWins() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(3), at: start))
        plan.merge([logged(1, 0, solved: false, at: 50), logged(1, 0, solved: true, at: 0)], programID: program)
        #expect(plan.currentCycle.attempts.map(\.solved) == [true])
    }

    @Test func aFinishedCycleGetsItsEndDate_andTheNextCycleOpensFromItsAnswers() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(3), at: start))
        // Cycle 1 bouclé, et deux réponses du cycle 2 — commencé sur l'autre appareil, plan pas encore reçu.
        plan.merge([logged(1, 0), logged(1, 1), logged(1, 2), logged(2, 0, at: 100), logged(2, 1, at: 100)],
                   programID: program)
        #expect(plan.cycles.count == 2)
        #expect(plan.cycles[0].finishedAt == start.addingTimeInterval(2))
        #expect(plan.currentCycle.number == 2)
        #expect(plan.currentCycle.order == WoodpeckerPlan.seededOrder(count: 3, programID: program, cycle: 2))
        #expect(plan.currentCycle.attempts.count == 2)
    }

    @Test func answersAlreadyWrittenInThePlanAreNotCountedTwice() throws {
        var plan = try #require(WoodpeckerPlan.start(items: items(4), at: start))
        plan.record(solved: true, seconds: 5)          // écrit dans le plan (version précédente, par exemple)
        plan.merge([logged(1, 0, solved: false), logged(1, 1)], programID: program)
        #expect(plan.currentCycle.attempts.map(\.solved) == [true, true], "la place 0 est déjà prise : seule la 1 s'ajoute")
    }

    // MARK: Le programme en base

    @MainActor
    @Test func answeringLeavesThePlanUntouched_onlySmallRecordsAreAdded() throws {
        let container = try ModelContainer(for: WoodpeckerProgram.self, WoodpeckerAttemptRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let program = WoodpeckerProgram()
        program.plan = try #require(WoodpeckerPlan.start(items: items(50), at: start))
        context.insert(program)
        try context.save()
        let writtenPlan = program.planData
        let writtenAt = program.updatedAt

        for step in 0..<10 {
            program.logAttempt(cycle: 1, step: step, solved: step % 3 != 0, seconds: 8)
        }
        try context.save()

        #expect(program.planData == writtenPlan, "le plan ne doit pas être réécrit à chaque puzzle")
        #expect(program.updatedAt == writtenAt, "ni la date du programme (elle renverrait tout l'enregistrement)")
        #expect(try context.fetchCount(FetchDescriptor<WoodpeckerAttemptRecord>()) == 10)
        let plan = try #require(program.plan)
        #expect(plan.currentCycle.attempts.count == 10)
        #expect(plan.currentCycle.solvedCount == 6)
        // Ce qui part par réponse : une poignée de champs, contre le plan entier avant.
        #expect((writtenPlan?.count ?? 0) > 2_000)
    }

    @MainActor
    @Test func aNewCycleRewritesThePlanOnce_withTheAnswersFoldedIn() throws {
        let container = try ModelContainer(for: WoodpeckerProgram.self, WoodpeckerAttemptRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let program = WoodpeckerProgram()
        program.plan = try #require(WoodpeckerPlan.start(items: items(3), at: start))
        context.insert(program)
        for step in 0..<3 { program.logAttempt(cycle: 1, step: step, solved: true, seconds: 4) }
        try context.save()

        var plan = try #require(program.plan)
        #expect(plan.currentCycle.isComplete)
        plan.startNextCycle(programID: program.id)
        program.plan = plan
        try context.save()

        let written = try #require(program.planData.flatMap(WoodpeckerPlan.init(storedData:)))
        #expect(written.cycles.count == 2)
        #expect(written.cycles[0].attempts.count == 3, "les réponses du cycle bouclé sont versées dans le plan")
        #expect(written.cycles[1].order == WoodpeckerPlan.seededOrder(count: 3, programID: program.id, cycle: 2))
    }

    @MainActor
    @Test func answersFromAnotherDevice_addUp_insteadOfOverwriting() throws {
        let container = try ModelContainer(for: WoodpeckerProgram.self, WoodpeckerAttemptRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let program = WoodpeckerProgram()
        program.plan = try #require(WoodpeckerPlan.start(items: items(6), at: start))
        context.insert(program)
        program.logAttempt(cycle: 1, step: 0, solved: true, seconds: 3, at: start)
        // L'autre appareil a répondu aux places 1 et 2 : ses enregistrements arrivent par iCloud.
        for step in 1...2 {
            let remote = WoodpeckerAttemptRecord()
            remote.programID = program.id
            remote.cycleNumber = 1
            remote.step = step
            remote.solved = false
            remote.seconds = 9
            remote.answeredAt = start.addingTimeInterval(Double(step))
            context.insert(remote)
        }
        try context.save()
        let plan = try #require(program.plan)
        #expect(plan.currentCycle.attempts.map(\.solved) == [true, false, false])
    }
}
