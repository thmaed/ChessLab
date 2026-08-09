import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Résolution de conflits multi-appareils de la progression d'ouvertures (J3).
/// Scénario central du brief : révisions faites hors ligne sur deux appareils,
/// puis fusion. Le journal est la vérité, l'état FSRS est rejoué.
///
/// - important: container statique unique, suite `.serialized` — voir
///   ``PuzzleProgressSyncTests`` pour le piège des containers multiples.
@MainActor
@Suite(.serialized)
struct OpeningProgressSyncTests {

    private static let container: ModelContainer = {
        try! ModelContainer(
            for: OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: OpeningPositionProgress.self)
        try context.delete(model: OpeningReviewLog.self)
        try context.delete(model: RepertoireMembership.self)
        try context.save()
        return context
    }

    private let fen = OpeningFENKey.key(for: .standard)
    private let day: TimeInterval = 86_400
    private var base: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    @discardableResult
    private func insertLog(_ context: ModelContext, rating: FSRSRating, at date: Date) -> OpeningReviewLog {
        let log = OpeningReviewLog(
            fenKey: fen, rating: rating, reviewedAt: date,
            elapsedDays: 0, scheduledDays: 0, stabilityAfter: 0
        )
        context.insert(log)
        return log
    }

    private func insertProgress(_ context: ModelContext, reps: Int, lastReview: Date) -> OpeningPositionProgress {
        let p = OpeningPositionProgress(fenKey: fen)
        p.reps = reps
        p.lastReviewedAt = lastReview
        p.updatedAt = lastReview
        context.insert(p)
        return p
    }

    /// Deux appareils révisent la même position hors ligne ; après synchro le
    /// store contient DEUX enregistrements de progression et l'union des logs.
    /// La réconciliation doit fusionner en un seul, avec l'état rejoué de
    /// l'union chronologique — sans perdre aucune révision.
    @Test func mergesDuplicateRecordsByReplayingTheUnionOfLogs() throws {
        let context = try makeContext()

        // Appareil A : t0 (good), t2 (good). Appareil B : t1 (again).
        let t0 = base, t1 = base.addingTimeInterval(day), t2 = base.addingTimeInterval(2 * day)
        insertLog(context, rating: .good, at: t0)
        insertLog(context, rating: .again, at: t1)
        insertLog(context, rating: .good, at: t2)
        // Les deux enregistrements dupliqués laissés par CloudKit (pas d'unicité).
        insertProgress(context, reps: 2, lastReview: t2) // A
        insertProgress(context, reps: 1, lastReview: t1) // B
        try context.save()

        OpeningProgressSync.reconcile(in: context)

        // Un seul enregistrement, compteurs recalculés depuis l'union.
        let records = try context.fetch(FetchDescriptor<OpeningPositionProgress>())
        #expect(records.count == 1)
        let merged = try #require(records.first)
        #expect(merged.reps == 3)          // 3 révisions au total
        #expect(merged.lapses == 1)        // un seul « again »
        #expect(merged.lastReviewedAt == t2)

        // État identique au replay de l'union triée (déterminisme).
        let expected = OpeningProgressSync.replay([
            OpeningReviewLog(fenKey: fen, rating: .good, reviewedAt: t0, elapsedDays: 0, scheduledDays: 0, stabilityAfter: 0),
            OpeningReviewLog(fenKey: fen, rating: .again, reviewedAt: t1, elapsedDays: 0, scheduledDays: 0, stabilityAfter: 0),
            OpeningReviewLog(fenKey: fen, rating: .good, reviewedAt: t2, elapsedDays: 0, scheduledDays: 0, stabilityAfter: 0),
        ])
        #expect(abs(merged.stability - expected.stability) < 1e-9)

        // Aucun log perdu.
        #expect(try context.fetchCount(FetchDescriptor<OpeningReviewLog>()) == 3)
    }

    /// La réconciliation est idempotente : une 2ᵉ passe ne change rien.
    @Test func reconcileIsIdempotent() throws {
        let context = try makeContext()
        insertLog(context, rating: .good, at: base)
        insertLog(context, rating: .good, at: base.addingTimeInterval(day))
        insertProgress(context, reps: 1, lastReview: base) // volontairement en retard
        try context.save()

        OpeningProgressSync.reconcile(in: context)
        let afterFirst = try #require(try context.fetch(FetchDescriptor<OpeningPositionProgress>()).first)
        let repsAfterFirst = afterFirst.reps
        let updatedAfterFirst = afterFirst.updatedAt

        OpeningProgressSync.reconcile(in: context)
        let records = try context.fetch(FetchDescriptor<OpeningPositionProgress>())
        #expect(records.count == 1)
        #expect(records.first?.reps == repsAfterFirst)
        #expect(records.first?.updatedAt == updatedAfterFirst) // pas de re-écriture
    }

    /// FILET DE SÉCURITÉ : une course à la suppression a effacé TOUS les
    /// enregistrements de progression, mais le journal subsiste. La
    /// réconciliation recrée la progression par replay — rien n'est perdu.
    @Test func recreatesProgressFromLogsWhenAllRecordsWereDeleted() throws {
        let context = try makeContext()
        insertLog(context, rating: .good, at: base)
        insertLog(context, rating: .good, at: base.addingTimeInterval(day))
        insertLog(context, rating: .again, at: base.addingTimeInterval(2 * day))
        // Aucun OpeningPositionProgress.
        try context.save()

        OpeningProgressSync.reconcile(in: context)

        let records = try context.fetch(FetchDescriptor<OpeningPositionProgress>())
        #expect(records.count == 1)
        #expect(records.first?.reps == 3)
        #expect(records.first?.lapses == 1)
    }

    /// Le chemin incrémental (un seul appareil) reste cohérent : après des
    /// révisions via ``OpeningProgressStore``, la réconciliation est un no-op
    /// (aucun doublon, aucun re-calcul, pas de resynchro inutile).
    @Test func singleDeviceIncrementalPathIsAlreadyConsistent() throws {
        let context = try makeContext()
        OpeningProgressStore.recordReview(fenKey: fen, rating: .good, at: base, in: context)
        let second = OpeningProgressStore.recordReview(
            fenKey: fen, rating: .good, at: base.addingTimeInterval(day), in: context
        )
        let updatedBefore = second.updatedAt

        OpeningProgressSync.reconcile(in: context)

        let records = try context.fetch(FetchDescriptor<OpeningPositionProgress>())
        #expect(records.count == 1)
        #expect(records.first?.reps == 2)
        #expect(records.first?.updatedAt == updatedBefore) // inchangé
    }

    @Test func emptyStoreReconcilesWithoutCrash() throws {
        let context = try makeContext()
        OpeningProgressSync.reconcile(in: context)
        #expect(try context.fetchCount(FetchDescriptor<OpeningPositionProgress>()) == 0)
    }

    @Test func deduplicatesRepertoireMembershipsMergingFavorite() throws {
        let context = try makeContext()
        let a = RepertoireMembership(courseID: "scandi", sideRaw: OpeningSide.black.rawValue, isFavorite: false)
        a.updatedAt = base
        let b = RepertoireMembership(courseID: "scandi", sideRaw: OpeningSide.black.rawValue, isFavorite: true)
        b.updatedAt = base.addingTimeInterval(day)
        context.insert(a)
        context.insert(b)
        try context.save()

        OpeningProgressSync.reconcile(in: context)

        let records = try context.fetch(FetchDescriptor<RepertoireMembership>())
        #expect(records.count == 1)
        #expect(records.first?.isFavorite == true) // OU logique
    }
}
