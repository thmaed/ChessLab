import Foundation

/// Badge de niveau d'une ouverture — progression motivante : découverte →
/// travaillée → solide. Purement dérivé de la couverture.
/// Le calcul reste (il est dérivé, testé, et sert à savoir quoi travailler
/// ensuite) ; ses libellés et ses icônes sont partis le 29/08 : aucun écran
/// ne les affichait, et ils traînaient donc en français hors du catalogue de
/// traduction. À réécrire — traduits — le jour où un écran les montrera.
enum OpeningBadge: String, Hashable {
    case notStarted
    case discovery
    case worked
    case solid
}

/// Couverture d'une ouverture : combien de ses positions entraînables ont été
/// VUES et MAÎTRISÉES, et combien sont DUES. PUR (cours + instantané de
/// progression → bilan), testable sans SwiftData. Sert à toujours savoir quoi
/// travailler ensuite et à décerner un badge.
struct OpeningCoverage: Equatable {
    let total: Int      // positions entraînables (dédupliquées par FEN)
    let seen: Int       // au moins une révision
    let mastered: Int   // stabilité FSRS suffisante
    let due: Int        // vues et échéance passée

    /// Stabilité (jours) à partir de laquelle on considère une position
    /// « maîtrisée » — solide sans être définitif.
    static let masteryStabilityDays = 21.0

    var seenFraction: Double { total == 0 ? 0 : Double(seen) / Double(total) }
    var masteryFraction: Double { total == 0 ? 0 : Double(mastered) / Double(total) }
    /// Positions jamais vues (à apprendre).
    var unseen: Int { max(0, total - seen) }

    var badge: OpeningBadge {
        if seen == 0 { return .notStarted }
        if masteryFraction >= 0.8 { return .solid }
        if seenFraction >= 0.5 { return .worked }
        return .discovery
    }

    static func compute(
        course: OpeningCourse, progress: [String: OpeningProgressSnapshot], now: Date = Date()
    ) -> OpeningCoverage {
        let keys = Set(OpeningTrainingQueue.trainableCards(of: course).map(\.fenKey))
        var seen = 0, mastered = 0, due = 0
        for key in keys {
            guard let snap = progress[key], snap.reps > 0 else { continue }
            seen += 1
            if snap.stability >= masteryStabilityDays { mastered += 1 }
            if let date = snap.dueDate, date <= now { due += 1 }
        }
        return OpeningCoverage(total: keys.count, seen: seen, mastered: mastered, due: due)
    }
}
