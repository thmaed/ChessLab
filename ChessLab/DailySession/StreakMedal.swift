import SwiftUI

/// Les médailles de la série de jours d'entraînement (C8) : un palier franchi
/// se voit, au lieu de rester un chiffre dans un coin. Les paliers sont fixes
/// et identiques sur Android (`StreakMedal.kt`).
enum StreakMedal: Int, CaseIterable, Equatable {
    case bronze = 3
    case silver = 7
    case gold = 30
    case platinum = 100
    case diamond = 365

    /// Nombre de jours de suite qui donne la médaille.
    var days: Int { rawValue }

    /// La plus haute médaille méritée par une série, `nil` sous trois jours.
    static func earned(forStreak days: Int) -> StreakMedal? {
        allCases.last { days >= $0.days }
    }

    /// La prochaine à gagner, `nil` une fois le diamant acquis.
    static func next(afterStreak days: Int) -> StreakMedal? {
        allCases.first { days < $0.days }
    }

    /// Vrai quand ce jour de série vient d'ATTEINDRE un palier.
    static func isMilestone(_ days: Int) -> Bool {
        allCases.contains { $0.days == days }
    }

    var name: String {
        switch self {
        case .bronze: LocalizationController.string("Médaille de bronze")
        case .silver: LocalizationController.string("Médaille d'argent")
        case .gold: LocalizationController.string("Médaille d'or")
        case .platinum: LocalizationController.string("Médaille de platine")
        case .diamond: LocalizationController.string("Médaille de diamant")
        }
    }

    var color: Color {
        switch self {
        case .bronze: Theme.gold
        case .silver: Color(red: 0.78, green: 0.82, blue: 0.88)
        case .gold: Theme.warning
        case .platinum: Theme.accentSecondary
        case .diamond: Theme.violet
        }
    }

    /// « Médaille d'argent · prochaine : or dans 23 jours ».
    static func caption(forStreak days: Int) -> String? {
        guard let medal = earned(forStreak: days) else {
            guard let first = next(afterStreak: days) else { return nil }
            return LocalizationController.string("Première médaille à %lld jours", first.days)
        }
        guard let next = next(afterStreak: days) else { return medal.name }
        return medal.name + " · " + LocalizationController.string("prochaine à %lld jours", next.days)
    }
}
