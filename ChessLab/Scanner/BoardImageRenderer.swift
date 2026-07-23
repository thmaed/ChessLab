import ChessKit
import CoreGraphics
import SwiftUI
import UIKit

/// Rendu bitmap d'un plateau et de ses pièces.
///
/// Deux usages, volontairement servis par le MÊME code :
/// - les **gabarits** du template matching (Lot 1.C) : on reconnaît les
///   glyphes cburnett, il faut donc les rendre exactement comme l'app les
///   affiche ;
/// - les **images de test** injectées par `-scanTestImage` (voir
///   ``ScannerView``), qui traversent tout le pipeline comme une vraie
///   capture.
///
/// Le set cburnett est celui de Lichess par défaut : une capture Lichess
/// tombe donc sur les mêmes glyphes que ceux embarqués ici.
enum BoardImageRenderer {

    /// Glyphe d'une pièce, dessiné sur un fond uni, dans un carré.
    ///
    /// - parameter scale: taille du glyphe rapporté à la case (Lichess et
    ///   l'app laissent une petite marge autour de la pièce).
    static func renderSquare(
        piece: Piece?, background: Color, side: CGFloat, glyphScale: CGFloat = 1
    ) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(background).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))

            guard let piece, let glyph = UIImage(named: assetName(for: piece)) else { return }

            let glyphSide = side * glyphScale
            let inset = (side - glyphSide) / 2
            glyph.draw(in: CGRect(x: inset, y: inset, width: glyphSide, height: glyphSide))
        }
        return image.cgImage
    }

    /// Plateau complet rendu depuis une position — l'équivalent d'une
    /// capture d'écran d'échiquier.
    ///
    /// - parameter orientation: couleur affichée en bas.
    static func renderBoard(
        position: Position, theme: BoardTheme, side: CGFloat,
        orientation: Piece.Color = .white, glyphScale: CGFloat = 1
    ) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let squareSide = side / 8

        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            for row in 0..<8 {
                for column in 0..<8 {
                    let square = square(row: row, column: column, orientation: orientation)
                    let rect = CGRect(
                        x: CGFloat(column) * squareSide, y: CGFloat(row) * squareSide,
                        width: squareSide, height: squareSide
                    )

                    UIColor(square.color == .light ? theme.lightSquare : theme.darkSquare).setFill()
                    context.fill(rect)

                    if let piece = position.piece(at: square), let glyph = UIImage(named: assetName(for: piece)) {
                        let glyphSide = squareSide * glyphScale
                        let inset = (squareSide - glyphSide) / 2
                        glyph.draw(in: rect.insetBy(dx: inset, dy: inset))
                    }
                }
            }
        }
        return image.cgImage
    }

    /// Case affichée à (`row`, `column`), ligne 0 EN HAUT — même convention
    /// que ``BoardRectifier/slice(_:)``.
    static func square(row: Int, column: Int, orientation: Piece.Color) -> Square {
        let files = Square.File.allCases
        if orientation == .white {
            return PositionEditorViewModel.square(files[column], 8 - row)
        } else {
            return PositionEditorViewModel.square(files[7 - column], row + 1)
        }
    }

    static func assetName(for piece: Piece) -> String {
        let color = piece.color == .white ? "w" : "b"
        let kind: String
        switch piece.kind {
        case .king: kind = "K"
        case .queen: kind = "Q"
        case .rook: kind = "R"
        case .bishop: kind = "B"
        case .knight: kind = "N"
        case .pawn: kind = "P"
        }
        return "piece_\(color)\(kind)"
    }
}
