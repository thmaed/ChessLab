import ChessKit
import SwiftUI

/// Récapitulatif du matériel capturé dans une partie : les pièces prises
/// par chaque camp et le différentiel de matériel. Pur et testable.
struct CapturedMaterial: Equatable {
    /// Pièces NOIRES capturées par les Blancs (triées par valeur décroissante).
    var byWhite: [Piece.Kind] = []
    /// Pièces BLANCHES capturées par les Noirs.
    var byBlack: [Piece.Kind] = []
    /// Différentiel de matériel : > 0 = avantage aux Blancs. Calculé sur la
    /// position réelle (et non sur les prises) pour rester exact après une
    /// promotion.
    var diff: Int = 0

    /// Prises d'un camp (les pièces adverses qu'il a gagnées).
    func captures(by color: Piece.Color) -> [Piece.Kind] {
        color == .white ? byWhite : byBlack
    }

    /// Différentiel du point de vue d'un camp (> 0 = ce camp mène).
    func advantage(for color: Piece.Color) -> Int {
        color == .white ? diff : -diff
    }

    static func from(moveLog: [Move], board: Board) -> CapturedMaterial {
        var material = CapturedMaterial()

        for move in moveLog {
            if case let .capture(piece) = move.result {
                if piece.color == .black {
                    material.byWhite.append(piece.kind)
                } else {
                    material.byBlack.append(piece.kind)
                }
            }
        }
        let byValueDesc: (Piece.Kind, Piece.Kind) -> Bool = { pieceValue($0) > pieceValue($1) }
        material.byWhite.sort(by: byValueDesc)
        material.byBlack.sort(by: byValueDesc)

        var whiteValue = 0
        var blackValue = 0
        for piece in board.position.pieces {
            if piece.color == .white {
                whiteValue += pieceValue(piece.kind)
            } else {
                blackValue += pieceValue(piece.kind)
            }
        }
        material.diff = whiteValue - blackValue
        return material
    }
}

/// Bandeau compact des pièces capturées d'un camp, à afficher à côté de son
/// nom. Pièces de même type groupées et légèrement chevauchées ; badge
/// « +N » de différentiel si ce camp mène au matériel. Hauteur fixe (même
/// vide) pour ne jamais décaler la mise en page.
struct CapturedTrayView: View {
    /// Pièces capturées, triées par valeur décroissante.
    let kinds: [Piece.Kind]
    /// Couleur des glyphes affichés (= couleur des pièces capturées).
    let glyphColor: Piece.Color
    /// Différentiel de matériel de ce camp ; affiché « +N » si > 0.
    var advantage: Int = 0

    private let glyph: CGFloat = 15
    private let overlap: CGFloat = 9

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                ZStack(alignment: .leading) {
                    ForEach(0..<group.count, id: \.self) { i in
                        // Contour clair pour les pièces noires (sinon
                        // invisibles sur le fond sombre du bandeau).
                        PieceGlyphView(
                            piece: Piece(group.kind, color: glyphColor, square: .a1),
                            outline: glyphColor == .black ? Color.white.opacity(0.85) : nil
                        )
                        .frame(width: glyph, height: glyph)
                        .offset(x: CGFloat(i) * overlap)
                    }
                }
                .frame(width: glyph + CGFloat(max(0, group.count - 1)) * overlap, height: glyph, alignment: .leading)
            }
            if advantage > 0 {
                Text("+\(advantage)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 2)
            }
        }
        .frame(height: 20)
        .accessibilityHidden(true)
    }

    private var groups: [(kind: Piece.Kind, count: Int)] {
        var result: [(kind: Piece.Kind, count: Int)] = []
        for kind in kinds {
            if let last = result.last, last.kind == kind {
                result[result.count - 1].count += 1
            } else {
                result.append((kind, 1))
            }
        }
        return result
    }
}
