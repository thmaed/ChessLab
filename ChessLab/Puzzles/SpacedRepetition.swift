import Foundation

/// SM-2 simplifié (algorithme de répétition espacée popularisé par
/// Anki/SuperMemo) : au lieu d'une note qualité 0...5, on ne retient que
/// réussi/échoué (mappé respectivement à qualité 5 et 2) — suffisant
/// pour un puzzle "trouvé du premier coup" vs "raté", pas de note
/// intermédiaire à demander à l'utilisateur.
enum SpacedRepetition {
    struct Schedule: Equatable {
        var easinessFactor: Double
        var intervalDays: Int
        var repetitions: Int

        static let initial = Schedule(easinessFactor: 2.5, intervalDays: 0, repetitions: 0)
    }

    private static let minimumEasinessFactor = 1.3
    private static let successQuality = 5.0
    private static let failureQuality = 2.0

    /// Calcule le prochain intervalle après une tentative — un échec
    /// remet `repetitions` à zéro et impose une révision dès le
    /// lendemain, sans jamais faire chuter `easinessFactor` sous le
    /// plancher SM-2 standard (1.3).
    static func next(after schedule: Schedule, success: Bool) -> Schedule {
        let quality = success ? successQuality : failureQuality
        let delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
        let easinessFactor = max(minimumEasinessFactor, schedule.easinessFactor + delta)

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
