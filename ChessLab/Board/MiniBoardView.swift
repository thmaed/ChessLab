import ChessKit
import SwiftUI

/// Une vignette de plateau : la position d'un cours d'un coup d'œil (C5).
/// Dessinée sur un `Canvas` — une liste de cinquante-huit cartes ne doit pas
/// porter 3 700 vues.
struct MiniBoardView: View {
    let fen: String
    var flipped = false

    private static let light = Color(red: 0.93, green: 0.90, blue: 0.82)
    private static let dark = Color(red: 0.46, green: 0.59, blue: 0.34)
    private static let glyphs: [Piece.Kind: String] = [
        .king: "♚", .queen: "♛", .rook: "♜", .bishop: "♝", .knight: "♞", .pawn: "♟\u{FE0E}",
    ]

    var body: some View {
        Canvas { context, size in
            let position = OpeningFENKey.position(from: fen)
            let cell = min(size.width, size.height) / 8
            for row in 0..<8 {
                for column in 0..<8 {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    let dark = (row + column) % 2 == 1
                    context.fill(Path(rect), with: .color(dark ? Self.dark : Self.light))
                    let file = flipped ? 7 - column : column
                    let rank = flipped ? row + 1 : 8 - row
                    guard let piece = position?.piece(at: Square("\(Array("abcdefgh")[file])\(rank)")),
                          let glyph = Self.glyphs[piece.kind]
                    else { continue }
                    let white = piece.color == .white
                    var text = Text(glyph).font(.system(size: cell * 1.3)).foregroundColor(white ? .white : .black)
                    if white { text = text.bold() }
                    let resolved = context.resolve(text)
                    // Léger contour pour que les blancs se lisent sur les cases claires.
                    if white {
                        for offset in [(-0.6, 0.0), (0.6, 0.0), (0.0, -0.6), (0.0, 0.6)] {
                            let shadow = context.resolve(Text(glyph).font(.system(size: cell * 1.3)).foregroundColor(.black.opacity(0.8)))
                            context.draw(shadow, at: CGPoint(x: rect.midX + offset.0, y: rect.midY + offset.1))
                        }
                    }
                    context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.stroke, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
