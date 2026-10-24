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
        /// Une finale, tournante.
        case endgame
    }

    let kind: Kind
    /// Ce qu'il reste à faire : positions, puzzles… 1 pour la finale tant
    /// qu'elle n'est pas ouverte.
    let remaining: Int
    /// Pour la finale : le cours choisi.
    var courseID: String?

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

enum DailySessionBuilder {

    static func plan(
        openingsDue: Int, missedPuzzles: Int, ownPuzzles: Int,
        endgameCourseID: String?, endgameOpenedToday: Bool,
        streak: Int, trainedToday: Bool
    ) -> DailySessionPlan {
        var steps = [
            DailySessionStep(kind: .openings, remaining: max(0, openingsDue)),
            DailySessionStep(kind: .missedPuzzles, remaining: max(0, missedPuzzles)),
            DailySessionStep(kind: .ownPuzzles, remaining: max(0, ownPuzzles)),
        ]
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
            streak: TrainingDays.streak(now: now), trainedToday: TrainingDays.didTrainToday(now: now)
        )
    }
}
