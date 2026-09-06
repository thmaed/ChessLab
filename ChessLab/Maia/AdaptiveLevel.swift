import Foundation

/// « S'adapte à mes résultats » : entre deux parties, le niveau d'un
/// personnage suit ce que le joueur a fait contre lui. Un pas fixe et borné,
/// visible à l'écran — jamais une modulation en cours de partie, ni en
/// cachette (décision du 21/08/2026).
enum AdaptiveLevel {
    /// Pas d'une victoire ou d'une défaite ; une nulle ne bouge pas.
    static let step: Double = 25
    static let range: ClosedRange<Double> = 800...2500

    static func next(after result: ProgressionSummary.GameResult, level: Double) -> Double {
        let moved: Double = switch result {
        case .win: level + step
        case .loss: level - step
        case .draw: level
        }
        return (min(range.upperBound, max(range.lowerBound, moved)) / 25).rounded() * 25
    }
}
