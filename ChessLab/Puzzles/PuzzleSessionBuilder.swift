import Foundation

/// Compose une séance de puzzles depuis un ensemble de candidats "dus" —
/// pur, testable sans SwiftData.
enum PuzzleSessionBuilder {
    /// Puzzles jamais ouverts d'abord (mélangés entre eux), puzzles déjà
    /// ouverts ensuite (mélangés entre eux) : ne recommence à répéter un
    /// puzzle déjà vu qu'une fois tous les inédits épuisés pour les
    /// filtres actifs — évite de retomber sur les mêmes puzzles à
    /// chaque ouverture de l'écran tant que la bibliothèque (des
    /// dizaines de milliers d'entrées, presque toutes "dues" dès le
    /// préchargement) n'a pas été explorée une première fois.
    static func buildSession(from candidates: [Puzzle], cap: Int) -> [Puzzle] {
        let neverOpened = candidates.filter { $0.firstOpenedAt == nil }.shuffled()
        let alreadyOpened = candidates.filter { $0.firstOpenedAt != nil }.shuffled()
        return Array((neverOpened + alreadyOpened).prefix(cap))
    }
}
