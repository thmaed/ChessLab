import ChessKit
import CoreGraphics
import Foundation

/// Ce qu'on a lu sur une case.
///
/// `kind` optionnel : c'est tout l'enjeu du plateau réel vu du dessus
/// (Lot 1.E), où l'on sait dire de façon fiable qu'une case est occupée et de
/// quelle couleur est la pièce, mais PAS son type (dame vs roi vus du sommet)
/// sans modèle entraîné. `nil` = « à préciser », complété par l'utilisateur.
enum SquareOccupancy: Equatable {
    case empty
    case piece(color: Piece.Color, kind: Piece.Kind?)

    var color: Piece.Color? {
        if case let .piece(color, _) = self { return color }
        return nil
    }

    var kind: Piece.Kind? {
        if case let .piece(_, kind) = self { return kind }
        return nil
    }

    var isEmpty: Bool { self == .empty }

    /// Vrai si la case est occupée par une pièce dont le type reste inconnu.
    var needsKind: Bool {
        if case let .piece(_, kind) = self { return kind == nil }
        return false
    }
}

/// Lecture d'une case, avec sa confiance.
struct SquareReading: Equatable {
    var occupancy: SquareOccupancy
    /// 0...1. Sert à surligner les cases douteuses à la confirmation plutôt
    /// qu'à les corriger en silence.
    var confidence: Double

    static let empty = SquareReading(occupancy: .empty, confidence: 1)

    /// Sous ce seuil, la case est signalée à l'utilisateur.
    static let confidenceThreshold = 0.55

    var isConfident: Bool { confidence >= Self.confidenceThreshold }
}

/// Un classifieur de case.
///
/// Le protocole est l'exigence « architecture prête pour CoreML » du prompt :
/// ``TemplateSquareClassifier`` couvre les sources numériques (Lot 1.C) et un
/// classifieur CoreML (Lot 1.F) peut se substituer sans que rien d'autre du
/// pipeline ne bouge.
protocol SquareClassifying {
    func classify(_ square: CGImage) -> SquareReading

    /// Lecture de la grille entière, `[ligne][colonne]`.
    ///
    /// Point d'entrée du pipeline, et non simple commodité : un classifieur de
    /// plateau réel a besoin du contexte GLOBAL (les deux couleurs du damier,
    /// la séparation des deux camps par regroupement des luminances), qu'une
    /// case seule ne peut pas donner. Les classifieurs qui n'en ont pas besoin
    /// héritent de l'implémentation par défaut, case par case.
    func classify(grid: [[CGImage]]) -> [[SquareReading]]
}

extension SquareClassifying {
    func classify(grid: [[CGImage]]) -> [[SquareReading]] {
        grid.map { row in row.map(classify) }
    }
}
