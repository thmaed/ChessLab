import ChessKit

/// Couleur choisie par l'utilisateur avant une partie contre le moteur.
enum PlayerColorChoice: String, CaseIterable, Identifiable {
    case white
    case black
    case random

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white: "Blancs"
        case .black: "Noirs"
        case .random: "Aléatoire"
        }
    }

    var symbolName: String {
        switch self {
        case .white: "circle.fill"
        case .black: "circle"
        case .random: "shuffle"
        }
    }

    /// Résout le choix en une couleur effective (tire au sort si nécessaire).
    func resolved() -> Piece.Color {
        switch self {
        case .white: .white
        case .black: .black
        case .random: Bool.random() ? .white : .black
        }
    }
}
