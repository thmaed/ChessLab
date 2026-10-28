import Foundation

/// SM-2 simplifié (algorithme de répétition espacée popularisé par
/// Anki/SuperMemo) : au lieu d'une note qualité 0...5 à demander à
/// l'utilisateur, la qualité se déduit de l'issue (``PuzzleOutcome``) :
/// maîtrisé = 5, partiel = 3, raté = 2. Le partiel revient vite (deux jours)
/// sans effacer la série de réussites d'un puzzle déjà acquis.
enum SpacedRepetition {
    struct Schedule: Equatable {
        var easinessFactor: Double
        var intervalDays: Int
        var repetitions: Int

        static let initial = Schedule(easinessFactor: 2.5, intervalDays: 0, repetitions: 0)
    }

    private static let minimumEasinessFactor = 1.3
    private static let successQuality = 5.0
    private static let partialQuality = 3.0
    private static let failureQuality = 2.0
    /// Délai de retour d'un puzzle partiel : entre le lendemain d'un échec et
    /// les six jours de la deuxième réussite.
    static let partialIntervalDays = 2

    /// Calcule le prochain intervalle après une tentative — un échec
    /// remet `repetitions` à zéro et impose une révision dès le
    /// lendemain, sans jamais faire chuter `easinessFactor` sous le
    /// plancher SM-2 standard (1.3).
    static func next(after schedule: Schedule, success: Bool) -> Schedule {
        next(after: schedule, outcome: success ? .mastered : .missed)
    }

    /// Même calcul, avec l'issue à trois états. Un partiel garde `repetitions`
    /// tel quel (ni remis à zéro, ni incrémenté) et revient dans
    /// ``partialIntervalDays`` jours.
    static func next(after schedule: Schedule, outcome: PuzzleOutcome) -> Schedule {
        let success = outcome == .mastered
        let quality: Double
        switch outcome {
        case .mastered: quality = successQuality
        case .partial: quality = partialQuality
        case .missed: quality = failureQuality
        }
        let delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
        let easinessFactor = max(minimumEasinessFactor, schedule.easinessFactor + delta)

        if outcome == .partial {
            return Schedule(
                easinessFactor: easinessFactor, intervalDays: partialIntervalDays, repetitions: schedule.repetitions
            )
        }
        guard success else {
            return Schedule(easinessFactor: easinessFactor, intervalDays: 1, repetitions: 0)
        }

        let repetitions = schedule.repetitions + 1
        let intervalDays: Int
        switch repetitions {
        case 1: intervalDays = 1
        case 2: intervalDays = 6
        default: intervalDays = Int((Double(schedule.intervalDays) * easinessFactor).rounded())
        }

        return Schedule(easinessFactor: easinessFactor, intervalDays: max(1, intervalDays), repetitions: repetitions)
    }

    static func dueDate(for schedule: Schedule, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: schedule.intervalDays, to: reference) ?? reference
    }
}
