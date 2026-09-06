import ChessKit
import Foundation

/// Encodeur d'entrée de Maia-3 : transforme les dernières positions d'une
/// partie en tenseur `64 × 97` (une ligne par case).
///
/// Réplique exacte de `tokenize_board()` et `get_historical_tokens()` du dépôt
/// `CSSLab/maia3`, prouvée bit à bit par `MaiaFixtureTests` :
///
///  - **Une position = 12 plans par case** : pion, cavalier, fou, tour, dame,
///    roi du camp AU TRAIT (plans 0-5), puis les mêmes pour l'adversaire
///    (plans 6-11). Pas de droits de roque, pas d'en passant : le modèle les
///    infère de l'historique.
///  - **Le plateau est retourné quand les Noirs jouent** (rangée 9 − r,
///    couleurs échangées), position par position : dans l'historique, les
///    orientations alternent donc d'un demi-coup à l'autre. C'est ce que fait
///    le code de référence, pas une simplification.
///  - **Historique de 8 positions**, de la plus ancienne (colonnes 0-11) à la
///    courante (colonnes 84-95) ; s'il en manque, la plus ancienne connue est
///    répétée en tête. La 97e colonne (temps de réflexion) reste à zéro à
///    l'inférence.
enum MaiaEncoder {
    static let historyLength = 8
    static let planesPerPosition = 12
    static let featuresPerSquare = historyLength * planesPerPosition + 1  // 97
    static let squareCount = 64

    /// Numéro de plan d'une pièce, dans le repère du camp au trait.
    static func plane(of piece: Piece, sideToMove: Piece.Color) -> Int {
        let kindOffset: Int = switch piece.kind {
        case .pawn: 0
        case .knight: 1
        case .bishop: 2
        case .rook: 3
        case .queen: 4
        case .king: 5
        }
        return kindOffset + (piece.color == sideToMove ? 0 : 6)
    }

    /// Les 64 × 12 bits d'UNE position, case par case (a1 → h8 après
    /// renversement éventuel), sous forme d'un masque de 12 bits par case.
    static func planes(of position: Position) -> [UInt16] {
        var squares = [UInt16](repeating: 0, count: squareCount)
        let mirror = position.sideToMove == .black
        for piece in position.pieces {
            let square = mirror ? MaiaMoveTable.mirrored(piece.square) : piece.square
            squares[MaiaMoveTable.squareIndex(square)] |= UInt16(1) << UInt16(plane(of: piece, sideToMove: position.sideToMove))
        }
        return squares
    }

    /// Tenseur d'entrée `64 × 97`, ligne par ligne, prêt pour Core ML.
    ///
    /// - parameter history: les positions de la partie, de la plus ancienne à
    ///   la COURANTE (dernier élément = position à jouer). Seules les huit
    ///   dernières comptent ; une liste vide rend un tenseur nul.
    static func tokens(history: [Position]) -> [Float] {
        var tensor = [Float](repeating: 0, count: squareCount * featuresPerSquare)
        guard !history.isEmpty else { return tensor }
        let recent = Array(history.suffix(historyLength))
        let padding = historyLength - recent.count
        let planesByPosition = recent.map(planes(of:))

        for slot in 0..<historyLength {
            // Les fentes manquantes en tête répètent la plus ancienne connue.
            let source = slot < padding ? planesByPosition[0] : planesByPosition[slot - padding]
            let columnBase = slot * planesPerPosition
            for square in 0..<squareCount {
                let mask = source[square]
                guard mask != 0 else { continue }
                let rowBase = square * featuresPerSquare + columnBase
                for plane in 0..<planesPerPosition where mask & (UInt16(1) << UInt16(plane)) != 0 {
                    tensor[rowBase + plane] = 1
                }
            }
        }
        return tensor
    }

    /// Les 96 bits d'historique d'une case, en hexadécimal (24 caractères,
    /// colonne 0 en poids fort) — le format des fixtures de référence.
    static func hexRow(_ tensor: [Float], square: Int) -> String {
        var hex = ""
        let base = square * featuresPerSquare
        for nibble in 0..<24 {
            var value = 0
            for bit in 0..<4 {
                value = value << 1 | (tensor[base + nibble * 4 + bit] > 0.5 ? 1 : 0)
            }
            hex += String(value, radix: 16)
        }
        return hex
    }
}
