import Foundation

/// Palier de difficulté simplifié pour la bibliothèque de puzzles —
/// regroupe la plage de rating Lichess (600-2400, voir
/// ``LichessPuzzleLoader``) en 4 paliers lisibles plutôt que d'exposer
/// un nombre brut.
enum DifficultyTier: String, CaseIterable, Codable {
    case beginner
    case intermediate
    case advanced
    case expert

    var label: String {
        switch self {
        case .beginner: "Débutant"
        case .intermediate: "Intermédiaire"
        case .advanced: "Confirmé"
        case .expert: "Expert"
        }
    }

    /// Interne pour le tri `tier(forRating:)` ci-dessous, mais aussi
    /// utilisée par ``PuzzleQueueView`` pour pousser le filtre de
    /// difficulté dans un `#Predicate` SwiftData (bornes de rating)
    /// plutôt que de charger toute la bibliothèque en mémoire pour la
    /// filtrer coup par coup.
    var ratingRange: ClosedRange<Int> {
        switch self {
        case .beginner: 0...1199
        case .intermediate: 1200...1599
        case .advanced: 1600...1999
        case .expert: 2000...Int.max
        }
    }

    /// `nil` pour un puzzle sans note (issu de vos parties, voir
    /// ``Puzzle/rating``) — la difficulté n'y est pas mesurée.
    static func tier(forRating rating: Int?) -> DifficultyTier? {
        guard let rating else { return nil }
        return allCases.first { $0.ratingRange.contains(rating) }
    }
}
