import ChessKit
import CoreGraphics
import Foundation
import UIKit
@testable import ChessLab

/// Fabriques d'images synthétiques pour les tests du scanner.
///
/// Pourquoi synthétique : on connaît la vérité au pixel près, sans dépendre
/// d'une photo réelle. Les fixtures réelles (Lot 1.C) répondent à une autre
/// question — « ça marche sur de vraies images ? » — et vivent à part.
enum SyntheticBoard {

    /// Plateau dont **chaque case a une couleur unique**, déduite de sa
    /// position. Sert à prouver que la découpe rend le bon quadrant : une
    /// inversion de lignes/colonnes ou un décalage d'un pixel se voit
    /// immédiatement, ce qu'un damier (2 couleurs seulement) masquerait.
    static func uniqueSquares(side: Int = 800) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)

        let image = renderer.image { context in
            let squareSide = Double(side) / 8
            for row in 0..<8 {
                for column in 0..<8 {
                    color(row: row, column: column).setFill()
                    context.fill(CGRect(
                        x: Double(column) * squareSide, y: Double(row) * squareSide,
                        width: squareSide, height: squareSide
                    ))
                }
            }
        }
        return image.cgImage!
    }

    /// Couleur attendue de la case (`row`, `column`), ligne 0 EN HAUT.
    /// Les canaux rouge et vert encodent directement la position ; le bleu
    /// reste constant et non nul pour éviter toute couleur dégénérée.
    static func color(row: Int, column: Int) -> UIColor {
        UIColor(
            red: CGFloat(row) / 8 + 1.0 / 16,
            green: CGFloat(column) / 8 + 1.0 / 16,
            blue: 0.5,
            alpha: 1
        )
    }

    /// Damier uni sur fond contrasté, avec marge : de quoi éprouver la
    /// DÉTECTION (Vision cherche un rectangle, il lui faut un bord net et
    /// une marge autour).
    static func boardOnBackground(
        boardSide: Double = 600, margin: Double = 100,
        light: UIColor = UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1),
        dark: UIColor = UIColor(red: 0.46, green: 0.59, blue: 0.34, alpha: 1)
    ) -> (image: CGImage, quad: BoardQuad) {
        let canvas = boardSide + margin * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format)

        let image = renderer.image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

            let squareSide = boardSide / 8
            for row in 0..<8 {
                for column in 0..<8 {
                    ((row + column) % 2 == 0 ? light : dark).setFill()
                    context.fill(CGRect(
                        x: margin + Double(column) * squareSide,
                        y: margin + Double(row) * squareSide,
                        width: squareSide, height: squareSide
                    ))
                }
            }
        }

        let quad = BoardQuad(
            topLeft: CGPoint(x: margin, y: margin),
            topRight: CGPoint(x: margin + boardSide, y: margin),
            bottomRight: CGPoint(x: margin + boardSide, y: margin + boardSide),
            bottomLeft: CGPoint(x: margin, y: margin + boardSide)
        )
        return (image.cgImage!, quad)
    }
}

/// Plateau **réel** synthétique, vu du dessus (Lot 1.E).
///

/// Lecture de pixels, pour affirmer ce que contient une vignette découpée.
enum PixelProbe {

    /// Couleur moyenne d'une image (plus stable qu'un pixel isolé, qui
    /// tomberait sur un bord anti-aliasé).
    static func averageColor(of image: CGImage) -> (red: Double, green: Double, blue: Double) {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0, 0) }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0, green = 0.0, blue = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            red += Double(pixels[index])
            green += Double(pixels[index + 1])
            blue += Double(pixels[index + 2])
        }
        let count = Double(width * height)
        return (red / count / 255, green / count / 255, blue / count / 255)
    }

    /// Couleur moyenne du **cœur** de l'image (60 % central) : ignore les
    /// bords, seuls concernés par l'interpolation du redressement.
    static func averageCenterColor(of image: CGImage) -> (red: Double, green: Double, blue: Double) {
        let inset = Double(min(image.width, image.height)) * 0.2
        let rect = CGRect(
            x: inset, y: inset,
            width: Double(image.width) - inset * 2, height: Double(image.height) - inset * 2
        ).integral

        guard let cropped = image.cropping(to: rect) else { return averageColor(of: image) }
        return averageColor(of: cropped)
    }
}
