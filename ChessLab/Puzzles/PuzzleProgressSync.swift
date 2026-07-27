import Foundation
import SwiftData

/// Pont entre la progression LOCALE (portée par ``Puzzle``, que la file
/// d'attente, la répétition espacée et les stats lisent SANS changement) et
/// sa copie SYNCHRONISÉE (``PuzzleProgress``, store « Games »).
///
/// - ``mirror(_:in:)`` : à chaque résolution, recopie la progression du
///   `Puzzle` vers son `PuzzleProgress` (clé `externalID`).
/// - ``reconcile(in:)`` : au lancement et à l'ouverture de la Progression,
///   fusionne la progression synchronisée (venue des autres appareils) dans
///   les `Puzzle` locaux — pour que file, SRS et stats en tiennent compte.
///
/// Le merge des COMPTEURS est un `max` (approximation assumée : deux appareils
/// qui résolvent le même puzzle hors ligne ne s'additionnent pas exactement —
/// mais pour des indicateurs de progression, c'est amplement suffisant).
/// L'état de répétition espacée (dueDate, répétitions…) adopte le plus AVANCÉ.
@MainActor
enum PuzzleProgressSync {

    /// Recopie la progression d'un puzzle (Lichess uniquement) vers son miroir
    /// synchronisé. No-op pour un puzzle issu de vos parties (pas d'`externalID`) :
    /// il est local par nature, la partie d'origine ne se synchronise pas non plus.
    static func mirror(_ puzzle: Puzzle, in context: ModelContext) {
        guard let key = puzzle.externalID, !key.isEmpty else { return }
        let record = fetchProgress(externalID: key, in: context) ?? {
            let new = PuzzleProgress(externalID: key)
            context.insert(new)
            return new
        }()
        record.successCount = puzzle.successCount ?? 0
        record.failureCount = puzzle.failureCount ?? 0
        record.easinessFactor = puzzle.easinessFactor ?? 2.5
        record.intervalDays = puzzle.intervalDays ?? 0
        record.repetitions = puzzle.repetitions ?? 0
        record.dueDate = puzzle.dueDate
        record.firstOpenedAt = puzzle.firstOpenedAt
        record.updatedAt = Date()
        try? context.save()
    }

    /// Fusionne la progression synchronisée dans les `Puzzle` locaux. Ne
    /// réécrit un `PuzzleProgress` que si le local était en avance (pour ne pas
    /// déclencher une resynchro iCloud inutile à chaque lancement).
    static func reconcile(in context: ModelContext) {
        let allProgress = (try? context.fetch(FetchDescriptor<PuzzleProgress>())) ?? []
        guard !allProgress.isEmpty else { return }

        for progress in allProgress {
            let key = progress.externalID
            // Requête PAR enregistrement, égalité simple : un `#Predicate`
            // `array.contains(...)` sur un tableau capturé n'est pas traduisible
            // par le store et CRASHE au fetch. Les entrées de progression sont
            // peu nombreuses (puzzles réellement tentés), N petites requêtes
            // indexées suffisent.
            guard !key.isEmpty, let puzzle = fetchPuzzle(externalID: key, in: context) else { continue }

            let mergedSuccess = max(puzzle.successCount ?? 0, progress.successCount)
            let mergedFailure = max(puzzle.failureCount ?? 0, progress.failureCount)

            puzzle.successCount = mergedSuccess
            puzzle.failureCount = mergedFailure
            // L'état SRS le plus AVANCÉ (plus de répétitions) fait foi.
            if progress.repetitions > (puzzle.repetitions ?? 0) {
                puzzle.easinessFactor = progress.easinessFactor
                puzzle.intervalDays = progress.intervalDays
                puzzle.repetitions = progress.repetitions
                puzzle.dueDate = progress.dueDate
            }
            // Première ouverture : la plus ancienne des deux dates.
            if let synced = progress.firstOpenedAt,
               puzzle.firstOpenedAt == nil || synced < (puzzle.firstOpenedAt ?? .distantFuture) {
                puzzle.firstOpenedAt = synced
            }

            // Le local était en avance : on remonte le miroir pour que les
            // autres appareils convergent aussi vers le max.
            if progress.successCount != mergedSuccess || progress.failureCount != mergedFailure {
                progress.successCount = mergedSuccess
                progress.failureCount = mergedFailure
                progress.updatedAt = Date()
            }
        }
        try? context.save()
    }

    // MARK: Fetch

    private static func fetchProgress(externalID: String, in context: ModelContext) -> PuzzleProgress? {
        var descriptor = FetchDescriptor<PuzzleProgress>(
            predicate: #Predicate { $0.externalID == externalID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchPuzzle(externalID: String, in context: ModelContext) -> Puzzle? {
        // `Puzzle.externalID` est optionnel : on compare optionnel à optionnel,
        // sinon SwiftData trappe (SIGTRAP) sur le mismatch String? vs String.
        let target: String? = externalID
        var descriptor = FetchDescriptor<Puzzle>(
            predicate: #Predicate { $0.externalID == target }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
