import ChessKit
import Foundation

/// Un puzzle que l'app PEUT créer depuis la partie analysée — rien n'est écrit tant que l'utilisateur
/// n'a pas accepté.
struct PuzzleCandidate: Identifiable, Equatable {
    let id = UUID()
    /// Position d'avant le coup joué : c'est au camp qui y a le trait de trouver la solution.
    let fen: String
    let playedSAN: String
    let solutionLANs: [String]
    let themeRaw: String
    /// Un mat forcé laissé filer (sinon : une erreur à retravailler).
    let isMate: Bool
    let moveNumber: Int
    let mover: Piece.Color
}

/// Le récapitulatif de fin d'analyse : les puzzles proposés pour la partie `key`.
struct PuzzleOffer: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let candidates: [PuzzleCandidate]

    var mates: [PuzzleCandidate] { candidates.filter(\.isMate) }
    var mistakes: [PuzzleCandidate] { candidates.filter { !$0.isMate } }
}
