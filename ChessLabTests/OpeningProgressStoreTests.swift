import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Progression des ouvertures persistée (store synchronisable).
///
/// - important: UN SEUL `ModelContainer` en mémoire pour toute la suite,
///   `.serialized` — même précaution que ``PuzzleProgressSyncTests`` (plusieurs
///   containers dans le même process font trapper SwiftData). On purge le store
///   au début de chaque test.
@MainActor
@Suite(.serialized)
struct OpeningProgressStoreTests {

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

    @Test func recordReviewPersistsAndSchedules() throws {
        let context = try makeContext()
        let fen = OpeningFENKey.key(for: .standard)

        let progress = OpeningProgressStore.recordReview(fenKey: fen, rating: .good, in: context)

        #expect(progress.reps == 1)
        #expect(progress.stateRaw == FSRSState.review.rawValue)
        #expect(progress.dueDate != nil)
        #expect(progress.firstSeenAt != nil)

        let logs = try context.fetch(FetchDescriptor<OpeningReviewLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.fenKey == fen)
        #expect(logs.first?.ratingRaw == FSRSRating.good.rawValue)
    }

    /// LE test qui protège la règle d'indexation par FEN : on révise une
    /// position, on « régénère » l'arbre (nouveau cours, autre id, autre
    /// continuation) et la progression de la position partagée DOIT survivre —
    /// elle reste retrouvable par sa clé FEN, non détruite par la reconstruction.
    @Test func progressSurvivesTreeRegeneration() throws {
        let context = try makeContext()

        // Arbre V1 : 1.e4 d5 2.exd5 Qxd5 (Scandinave classique).
        let v1 = OpeningGraphFixtures.linearCourse(
            id: "scandi-v1", name: "Scandinave", sans: ["e4", "d5", "exd5", "Qxd5"], side: .black
        )
        // Position après 1.e4 d5 (partagée par toutes les Scandinaves).
        let sharedFEN = try #require(v1.chapters?.first?.positionFENs[2])
        #expect(v1.positions[sharedFEN] != nil)

        OpeningProgressStore.recordReview(fenKey: sharedFEN, rating: .good, in: context)
        #expect(OpeningProgressStore.progress(forFEN: sharedFEN, in: context)?.reps == 1)

        // Régénération : arbre V2 approfondi/différent (2...Nf6, portugaise),
        // AUTRE id et structure — mais qui contient la même position partagée.
        let v2 = OpeningGraphFixtures.linearCourse(
            id: "scandi-v2", name: "Scandinave (régénérée)", sans: ["e4", "d5", "exd5", "Nf6", "d4"], side: .black
        )
        #expect(v1.id != v2.id)
        #expect(v2.positions[sharedFEN] != nil) // la position existe toujours dans le nouvel arbre

        // La progression n'a pas bougé : indexée par FEN, pas par l'arbre.
        let survivor = try #require(OpeningProgressStore.progress(forFEN: sharedFEN, in: context))
        #expect(survivor.reps == 1)
        #expect(survivor.stateRaw == FSRSState.review.rawValue)

        // Et une seule entrée de progression pour cette position (pas de doublon).
        let all = try context.fetch(FetchDescriptor<OpeningPositionProgress>())
        #expect(all.filter { $0.fenKey == sharedFEN }.count == 1)
    }

    @Test func repeatedReviewsAdvanceScheduleAndLog() throws {
        let context = try makeContext()
        let fen = OpeningFENKey.key(for: .standard)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        OpeningProgressStore.recordReview(fenKey: fen, rating: .good, at: now, in: context)
        let second = OpeningProgressStore.recordReview(
            fenKey: fen, rating: .good, at: now.addingTimeInterval(5 * 86_400), in: context
        )

        #expect(second.reps == 2)
        #expect(try context.fetchCount(FetchDescriptor<OpeningReviewLog>()) == 2)
    }

    @Test func repertoireMembershipPersists() throws {
        let context = try makeContext()
        let membership = RepertoireMembership(courseID: "scandi-v1", sideRaw: OpeningSide.black.rawValue, isFavorite: true)
        context.insert(membership)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RepertoireMembership>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.courseID == "scandi-v1")
        #expect(fetched.first?.isFavorite == true)
    }
}
