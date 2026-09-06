import Foundation

/// Le niveau ESTIMÉ du joueur, sur l'échelle humaine de Maia : ce que Maia
/// reçoit comme « Elo de l'adversaire », pour jouer contre vous comme un
/// humain joue contre quelqu'un de votre force.
///
/// Une mise à jour Elo classique après chaque partie contre un personnage
/// (facteur K = 32, résultat attendu par la formule logistique), amorcée au
/// premier niveau choisi. Interne : rien n'est affiché — l'estimation par la
/// précision des coups a été mesurée impossible en août, celle-ci ne
/// prétend pas plus qu'un compteur de résultats.
enum PlayerLevel {
    static let key = "playerLevel.v1"
    static let kFactor: Double = 32
    static let range: ClosedRange<Double> = 600...2800

    /// Résultat attendu du joueur (0…1) contre un adversaire de `opponent`.
    static func expectedScore(player: Double, opponent: Double) -> Double {
        1 / (1 + pow(10, (opponent - player) / 400))
    }

    static func updated(_ player: Double, against opponent: Double, result: ProgressionSummary.GameResult) -> Double {
        let score: Double = switch result {
        case .win: 1
        case .draw: 0.5
        case .loss: 0
        }
        let next = player + kFactor * (score - expectedScore(player: player, opponent: opponent))
        return min(range.upperBound, max(range.lowerBound, next.rounded()))
    }

    /// Le niveau connu, ou `seed` (le niveau choisi pour la partie) faute
    /// d'historique.
    static func current(seed: Double, defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.double(forKey: key)
        return stored > 0 ? stored : seed
    }

    static func record(result: ProgressionSummary.GameResult, against opponent: Double, seed: Double, defaults: UserDefaults = .standard) -> Double {
        let next = updated(current(seed: seed, defaults: defaults), against: opponent, result: result)
        defaults.set(next, forKey: key)
        return next
    }
}
