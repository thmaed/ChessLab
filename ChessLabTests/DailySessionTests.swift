import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// A5 — la séance du jour : la série de jours et le plan, deux fonctions pures.
@Suite
@MainActor
struct DailySessionTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func days(_ numbers: [Int]) -> Set<String> {
        Set(numbers.map { TrainingStreak.key(for: date($0), calendar: calendar) })
    }

    @Test("Jours consécutifs jusqu'à aujourd'hui")
    func streakEndingToday() {
        #expect(TrainingStreak.current(days: days([20, 21, 22, 23, 24]), now: date(24), calendar: calendar) == 5)
        #expect(TrainingStreak.current(days: days([22, 24]), now: date(24), calendar: calendar) == 1)
    }

    @Test("Une série vit jusqu'à la fin de la journée : aujourd'hui vide, elle compte jusqu'à hier")
    func streakSurvivesUntilTheDayEnds() {
        #expect(TrainingStreak.current(days: days([21, 22, 23]), now: date(24), calendar: calendar) == 3)
        // Un jour entier manqué : la série est rompue.
        #expect(TrainingStreak.current(days: days([21, 22, 23]), now: date(25), calendar: calendar) == 0)
        #expect(TrainingStreak.current(days: [], now: date(24), calendar: calendar) == 0)
    }

    @Test("La série traverse les fins de mois")
    func streakAcrossMonths() {
        let october31 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))!
        let november1 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        let set: Set<String> = [
            TrainingStreak.key(for: october31, calendar: calendar), TrainingStreak.key(for: november1, calendar: calendar)]
        #expect(TrainingStreak.current(days: set, now: november1, calendar: calendar) == 2)
    }

    @Test("Le plan ordonne les étapes et compte ce qui reste")
    func planOrdersTheSteps() {
        let plan = DailySessionBuilder.plan(
            openingsDue: 12, missedPuzzles: 0, ownPuzzles: 2, endgameCourseID: "eg-lucena",
            endgameOpenedToday: false, streak: 4, trainedToday: false, openingsCap: 10)
        #expect(plan.steps.map(\.kind) == [.openings, .missedPuzzles, .ownPuzzles, .endgame])
        #expect(plan.pending.map(\.kind) == [.openings, .ownPuzzles, .endgame])
        #expect(plan.firstPending?.remaining == 10)
        #expect(plan.steps.first { $0.kind == .endgame }?.courseID == "eg-lucena")
        #expect(!plan.isComplete)
        #expect(plan.streak == 4)
    }

    @Test("Une séance reste courte : le plafond d'ouvertures est réglable, 5 puzzles par étape")
    func stepsAreCapped() {
        func remaining(cap: Int) -> [Int] {
            DailySessionBuilder.plan(
                openingsDue: 80, missedPuzzles: 28, ownPuzzles: 7, endgameCourseID: nil,
                endgameOpenedToday: false, streak: 0, trainedToday: false, openingsCap: cap).steps.map(\.remaining)
        }
        #expect(remaining(cap: 5) == [5, 5, 5])
        #expect(remaining(cap: 3) == [3, 5, 5])
        #expect(remaining(cap: 10) == [10, 5, 5])
    }

    @Test("Le plafond réglé est relu, et une valeur inconnue retombe sur 5")
    func openingsCapSetting() {
        let key = DailySessionBuilder.openingsCapKey
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.set(3, forKey: key)
        #expect(DailySessionBuilder.openingsCap == 3)
        UserDefaults.standard.set(7, forKey: key)
        #expect(DailySessionBuilder.openingsCap == 5)
        UserDefaults.standard.removeObject(forKey: key)
        #expect(DailySessionBuilder.openingsCap == 5)
    }

    @Test("Le plafond atteint, l'étape des ouvertures est faite même s'il reste des positions dues")
    func openingsStepDoneOnceCapReached() {
        func remaining(done: Int, due: Int) -> Int {
            DailySessionBuilder.plan(
                openingsDue: due, missedPuzzles: 0, ownPuzzles: 0, endgameCourseID: nil,
                endgameOpenedToday: false, streak: 0, trainedToday: false,
                openingsCap: 5, openingsDoneToday: done).steps.first!.remaining
        }
        #expect(remaining(done: 0, due: 12) == 5)
        #expect(remaining(done: 3, due: 12) == 2)
        #expect(remaining(done: 5, due: 12) == 0)
        #expect(remaining(done: 2, due: 1) == 1)
    }

    @Test("Le compteur du jour repart de zéro le lendemain")
    func openingsCounterResetsEachDay() {
        let defaults = UserDefaults(suiteName: "DailySessionTests.\(UUID().uuidString)")!
        let monday = Date(timeIntervalSince1970: 1_790_000_000)
        TrainingDays.addOpeningsReviewed(3, now: monday, defaults: defaults)
        TrainingDays.addOpeningsReviewed(2, now: monday, defaults: defaults)
        #expect(TrainingDays.openingsReviewedToday(now: monday, defaults: defaults) == 5)
        #expect(TrainingDays.openingsReviewedToday(now: monday.addingTimeInterval(86_400 * 2), defaults: defaults) == 0)
    }

    @Test("Tout est fait quand il n'y a plus rien à revoir et que la finale est ouverte")
    func planIsCompleteWhenNothingRemains() {
        let plan = DailySessionBuilder.plan(
            openingsDue: 0, missedPuzzles: 0, ownPuzzles: 0, endgameCourseID: "eg-lucena",
            endgameOpenedToday: true, streak: 1, trainedToday: true)
        #expect(plan.isComplete)
        #expect(plan.firstPending == nil)
        // Sans finale au catalogue, l'étape n'existe pas.
        let none = DailySessionBuilder.plan(
            openingsDue: 0, missedPuzzles: 0, ownPuzzles: 0, endgameCourseID: nil,
            endgameOpenedToday: false, streak: 0, trainedToday: false)
        #expect(none.steps.map(\.kind) == [.openings, .missedPuzzles, .ownPuzzles])
        #expect(none.isComplete)
    }

    @Test("La finale du jour tourne : une par jour, et on revient au début")
    func endgameRotates() throws {
        let ids = ["a", "b", "c"]
        let first = try #require(DailySessionBuilder.endgameCourseID(ids: ids, now: date(24), calendar: calendar))
        let second = try #require(DailySessionBuilder.endgameCourseID(ids: ids, now: date(25), calendar: calendar))
        let third = try #require(DailySessionBuilder.endgameCourseID(ids: ids, now: date(26), calendar: calendar))
        let fourth = try #require(DailySessionBuilder.endgameCourseID(ids: ids, now: date(27), calendar: calendar))
        #expect(Set([first, second, third]) == Set(ids))
        #expect(fourth == first)
        // Le matin et le soir d'un même jour : la même finale.
        #expect(DailySessionBuilder.endgameCourseID(ids: ids, now: date(24, hour: 1), calendar: calendar)
            == DailySessionBuilder.endgameCourseID(ids: ids, now: date(24, hour: 23), calendar: calendar))
        #expect(DailySessionBuilder.endgameCourseID(ids: [], now: date(24), calendar: calendar) == nil)
    }

    @Test("Le journal des jours se lit et s'écrit")
    func daysStore() {
        let suite = UserDefaults(suiteName: "DailySessionTests-\(UUID().uuidString)")!
        #expect(!TrainingDays.didTrainToday(defaults: suite))
        TrainingDays.markToday(defaults: suite)
        TrainingDays.markToday(defaults: suite)   // idempotent
        #expect(TrainingDays.didTrainToday(defaults: suite))
        #expect(TrainingDays.all(defaults: suite).count == 1)
        #expect(TrainingDays.streak(defaults: suite) == 1)
        #expect(!TrainingDays.endgameOpenedToday(defaults: suite))
        TrainingDays.markEndgameOpened(defaults: suite)
        #expect(TrainingDays.endgameOpenedToday(defaults: suite))
    }

    @Test("Le plan lu dans les bases compte les positions dues, les puzzles ratés et ceux de vos parties")
    func loadReadsTheStores() throws {
        let container = try ModelContainer(
            for: Schema([OpeningPositionProgress.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let now = Date()

        let due = OpeningPositionProgress(fenKey: "a")
        due.dueDate = now.addingTimeInterval(-3600)
        let later = OpeningPositionProgress(fenKey: "b")
        later.dueDate = now.addingTimeInterval(86_400)
        context.insert(due)
        context.insert(later)

        // Un puzzle de vos parties, dû ; un puzzle de la bibliothèque, raté à la dernière tentative.
        let own = Puzzle()
        own.sourceRaw = PuzzleSource.ownGames.rawValue
        own.dueDate = now.addingTimeInterval(-60)
        own.successCount = 1
        own.repetitions = 1
        let missed = Puzzle()
        missed.sourceRaw = "lichess"
        missed.dueDate = now.addingTimeInterval(86_400)
        missed.failureCount = 2
        missed.repetitions = 0
        context.insert(own)
        context.insert(missed)
        try context.save()

        let plan = DailySessionBuilder.load(in: context, now: now)
        #expect(plan.steps.first { $0.kind == .openings }?.remaining == 1)
        #expect(plan.steps.first { $0.kind == .missedPuzzles }?.remaining == 1)
        #expect(plan.steps.first { $0.kind == .ownPuzzles }?.remaining == 1)
    }
}
