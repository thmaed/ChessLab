import Foundation
import Testing
@testable import ChessLab

/// Le bilan de la MÉMORISATION : ce qui est vu, acquis, à raffermir, dû.
///
/// Fonction pure — ni base ni horloge cachées —, donc vérifiable sur des
/// valeurs écrites à la main. C'est ce qu'on veut d'un chiffre qui sert à
/// décider quoi travailler.
@Suite("Bilan de mémorisation")
struct TrainingStatsTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(
        reps: Int, stability: Double, lapses: Int = 0,
        state: FSRSState = .review, due: TimeInterval? = nil
    ) -> OpeningPositionProgress {
        let entry = OpeningPositionProgress(fenKey: UUID().uuidString)
        entry.reps = reps
        entry.stability = stability
        entry.lapses = lapses
        entry.stateRaw = state.rawValue
        entry.dueDate = due.map { now.addingTimeInterval($0) }
        return entry
    }

    private func log(rating: FSRSRating, daysAgo: Double) -> OpeningReviewLog {
        OpeningReviewLog(
            fenKey: "k", rating: rating,
            reviewedAt: now.addingTimeInterval(-daysAgo * 86_400),
            elapsedDays: 0, scheduledDays: 0, stabilityAfter: 1
        )
    }

    @Test("Une position jamais révisée ne compte pas comme vue")
    func unseen() {
        let stats = TrainingStats.compute(
            progress: [record(reps: 0, stability: 0, state: .new)], logs: [], now: now
        )
        #expect(stats.studied == 0)
        #expect(stats.isEmpty)
    }

    @Test("Acquise au-delà d'une semaine de stabilité")
    func solid() {
        let stats = TrainingStats.compute(
            progress: [
                record(reps: 3, stability: 8),
                record(reps: 2, stability: 6),
            ],
            logs: [], now: now
        )
        #expect(stats.studied == 2)
        #expect(stats.solid == 1)
    }

    @Test("Difficile : déjà oubliée, ou encore en apprentissage")
    func hard() {
        let stats = TrainingStats.compute(
            progress: [
                record(reps: 4, stability: 20, lapses: 1),
                record(reps: 1, stability: 1, state: .learning),
                record(reps: 5, stability: 30),
            ],
            logs: [], now: now
        )
        #expect(stats.hard == 2)
    }

    @Test("Est due ce dont l'échéance est PASSÉE")
    func due() {
        let stats = TrainingStats.compute(
            progress: [
                record(reps: 2, stability: 3, due: -86_400),
                record(reps: 2, stability: 3, due: 86_400),
            ],
            logs: [], now: now
        )
        #expect(stats.due == 1)
    }

    @Test("La rétention ne regarde que les trente derniers jours")
    func retention() {
        let stats = TrainingStats.compute(
            progress: [],
            logs: [
                log(rating: .good, daysAgo: 1),
                log(rating: .again, daysAgo: 2),
                log(rating: .again, daysAgo: 60),   // hors fenêtre
            ],
            now: now
        )
        #expect(stats.retention == 0.5)
        #expect(stats.retentionLabel == "50 %")
    }

    @Test("Sans révision récente, pas de taux inventé")
    func noRetention() {
        let stats = TrainingStats.compute(progress: [], logs: [], now: now)
        #expect(stats.retention == nil)
        #expect(stats.retentionLabel == "—")
    }

    @Test("Les révisions de la semaine se comptent sur sept jours")
    func week() {
        let stats = TrainingStats.compute(
            progress: [],
            logs: [log(rating: .good, daysAgo: 2), log(rating: .good, daysAgo: 10)],
            now: now
        )
        #expect(stats.reviewsThisWeek == 1)
    }

    @Test("La prochaine échéance se tait quand quelque chose est déjà dû")
    func nextDueSilentWhenDue() {
        let stats = TrainingStats.compute(
            progress: [
                record(reps: 1, stability: 1, due: -3_600),
                record(reps: 1, stability: 1, due: 3 * 86_400),
            ],
            logs: [], now: now
        )
        #expect(stats.nextDueLabel(now: now) == nil)
    }

    @Test("Sinon elle annonce le délai")
    func nextDue() {
        let stats = TrainingStats.compute(
            progress: [record(reps: 1, stability: 1, due: 3 * 86_400)],
            logs: [], now: now
        )
        #expect(stats.nextDueLabel(now: now)?.contains("3") == true)
    }
}
