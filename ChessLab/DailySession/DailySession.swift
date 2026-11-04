import Foundation
import SwiftData

/// Une étape de la séance du jour (A5).
struct DailySessionStep: Identifiable, Equatable {
    enum Kind: String, Equatable {
        /// Les positions d'ouverture dues (répétition espacée FSRS).
        case openings
        /// Les puzzles ratés à la dernière tentative.
        case missedPuzzles
        /// Les puzzles tirés de vos parties, dus.
        case ownPuzzles
        /// Un cycle Woodpecker en cours : le programme à reprendre (suggestion d'Olivier, 2.1).
        case woodpecker
        /// Une finale, tournante.
        case endgame
    }

    let kind: Kind
    /// Ce qu'il reste à faire : positions, puzzles… 1 pour la finale tant
    /// qu'elle n'est pas ouverte.
    let remaining: Int
    /// Pour la finale : le cours choisi.
    var courseID: String?
    /// Pour Woodpecker : le programme à reprendre et le numéro de son cycle en cours.
    var programID: UUID?
    var cycleNumber: Int?

    var id: String { kind.rawValue }
    var isDone: Bool { remaining == 0 }
}

/// La séance du jour : un agrégateur, pas un nouveau contenu. Ouvertures dues
/// → puzzles ratés → puzzles de vos parties → une finale, avec la série de
/// jours. Pure : des comptes, un plan.
struct DailySessionPlan: Equatable {
    let steps: [DailySessionStep]
    let streak: Int
    let trainedToday: Bool

    var pending: [DailySessionStep] { steps.filter { !$0.isDone } }
    var isComplete: Bool { pending.isEmpty }
    var firstPending: DailySessionStep? { pending.first }
}

/// Un cycle Woodpecker en cours, tel que la séance le voit : le programme, son cycle,
/// ce qu'il reste dedans, et si l'on y a déjà travaillé aujourd'hui.
struct WoodpeckerSessionInfo: Equatable {
    let programID: UUID
    let cycle: Int
    let puzzlesLeft: Int
    let practicedToday: Bool
}

enum DailySessionBuilder {
    /// Une séance se veut courte : au plus 5 puzzles par étape, et un plafond
    /// RÉGLABLE de positions d'ouverture — 2, 5 ou 8, 5 par défaut (même
    /// plafond sur Android). Le reste attend demain.
    static let puzzlesCap = 5
    static let openingsCapKey = "dailySession.openingsCap"
    static let openingsCapChoices = [2, 5, 8]
    static let defaultOpeningsCap = 5

    static var openingsCap: Int {
        let stored = UserDefaults.standard.integer(forKey: openingsCapKey)
        return openingsCapChoices.contains(stored) ? stored : defaultOpeningsCap
    }

    static func plan(
        openingsDue: Int, missedPuzzles: Int, ownPuzzles: Int,
        endgameCourseID: String?, endgameOpenedToday: Bool,
        streak: Int, trainedToday: Bool,
        openingsCap: Int = DailySessionBuilder.openingsCap,
        openingsDoneToday: Int = 0,
        woodpecker: WoodpeckerSessionInfo? = nil
    ) -> DailySessionPlan {
        var steps = [
            DailySessionStep(kind: .openings, remaining: min(max(0, openingsCap - openingsDoneToday), max(0, openingsDue))),
            DailySessionStep(kind: .missedPuzzles, remaining: min(puzzlesCap, max(0, missedPuzzles))),
            DailySessionStep(kind: .ownPuzzles, remaining: min(puzzlesCap, max(0, ownPuzzles))),
        ]
        // Un cycle Woodpecker en cours : sa tâche reste faite pour la journée dès qu'on y a répondu à un puzzle,
        // sinon un cycle de mille puzzles empêcherait la séance de jamais se terminer.
        if let woodpecker, woodpecker.puzzlesLeft > 0 {
            steps.append(DailySessionStep(
                kind: .woodpecker, remaining: woodpecker.practicedToday ? 0 : woodpecker.puzzlesLeft,
                programID: woodpecker.programID, cycleNumber: woodpecker.cycle))
        }
        if let endgameCourseID {
            steps.append(DailySessionStep(
                kind: .endgame, remaining: endgameOpenedToday ? 0 : 1, courseID: endgameCourseID))
        }
        return DailySessionPlan(steps: steps, streak: streak, trainedToday: trainedToday)
    }

    /// La finale du jour : on tourne sur les finales du catalogue, une par
    /// jour, la même pour tout le monde ce jour-là (jours depuis l'epoch
    /// modulo le nombre de finales). Mêmes règles sur Android.
    static func endgameCourseID(ids: [String], now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard !ids.isEmpty else { return nil }
        let start = calendar.startOfDay(for: now)
        let days = Int(start.timeIntervalSince1970 / 86_400 + Double(calendar.timeZone.secondsFromGMT(for: start)) / 86_400)
        return ids[((days % ids.count) + ids.count) % ids.count]
    }

    /// Le cycle Woodpecker EN COURS, s'il y en a un : le programme le plus récemment travaillé parmi ceux
    /// qui n'ont pas été arrêtés, dont le cycle courant n'est pas bouclé.
    @MainActor
    static func woodpeckerInfo(in context: ModelContext, now: Date = Date()) -> WoodpeckerSessionInfo? {
        var descriptor = FetchDescriptor<WoodpeckerProgram>(
            predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 8
        for program in (try? context.fetch(descriptor)) ?? [] {
            guard let plan = program.plan else { continue }
            let cycle = plan.currentCycle
            guard !cycle.isComplete else { continue }
            return WoodpeckerSessionInfo(
                programID: program.id, cycle: cycle.number, puzzlesLeft: cycle.order.count - cycle.attempts.count,
                practicedToday: TrainingDays.woodpeckerPracticedToday(now: now))
        }
        return nil
    }

    /// Le plan d'aujourd'hui, lu dans les bases locales.
    @MainActor
    static func load(in context: ModelContext, now: Date = Date()) -> DailySessionPlan {
        let progress = (try? context.fetch(FetchDescriptor<OpeningPositionProgress>())) ?? []
        let due = progress.filter { ($0.dueDate ?? .distantFuture) <= now }.count
        let missed = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(source: nil, missedOnly: true), in: context)
        let own = PuzzleSessionDrawer.count(matching: PuzzleSessionFilter(source: .ownGames), in: context)
        let endgames = OpeningCatalog.all.filter { $0.kind == "endgame" }.map(\.id)
        return plan(
            openingsDue: due, missedPuzzles: missed, ownPuzzles: own,
            endgameCourseID: endgameCourseID(ids: endgames, now: now),
            endgameOpenedToday: TrainingDays.endgameOpenedToday(now: now),
            streak: TrainingDays.streak(now: now), trainedToday: TrainingDays.didTrainToday(now: now),
            openingsDoneToday: TrainingDays.openingsReviewedToday(now: now),
            woodpecker: woodpeckerInfo(in: context, now: now)
        )
    }
}
