import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import ChessLab

/// Tests du redressement et de la découpe (étape 7 / Lot 1.B).
///
/// Le critère du lot : « chaque case contient le bon quadrant, au pixel
/// près ». D'où le plateau à couleurs uniques — sur un simple damier, une
/// inversion lignes/colonnes passerait inaperçue une fois sur deux.
struct BoardRectifierTests {

    private func expectColor(
        _ actual: (red: Double, green: Double, blue: Double),
        row: Int, column: Int,
        tolerance: Double = 0.02,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var expectedRed: CGFloat = 0, expectedGreen: CGFloat = 0, expectedBlue: CGFloat = 0, alpha: CGFloat = 0
        SyntheticBoard.color(row: row, column: column)
            .getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &alpha)

        #expect(abs(actual.red - Double(expectedRed)) < tolerance,
                "rouge de la case (\(row), \(column)) : \(actual.red) ≠ \(expectedRed)", sourceLocation: sourceLocation)
        #expect(abs(actual.green - Double(expectedGreen)) < tolerance,
                "vert de la case (\(row), \(column)) : \(actual.green) ≠ \(expectedGreen)", sourceLocation: sourceLocation)
    }

    // MARK: Découpe

    @Test func slicingProducesSixtyFourSquares() throws {
        let rows = try #require(BoardRectifier.slice(SyntheticBoard.uniqueSquares()))

        #expect(rows.count == 8)
        #expect(rows.allSatisfy { $0.count == 8 })
        #expect(rows.flatMap { $0 }.count == 64)
    }

    /// Le test central du lot : chaque vignette contient bien SA case.
    @Test func everySlicedSquareHoldsItsOwnQuadrant() throws {
        let rows = try #require(BoardRectifier.slice(SyntheticBoard.uniqueSquares()))

        for row in 0..<8 {
            for column in 0..<8 {
                expectColor(PixelProbe.averageCenterColor(of: rows[row][column]), row: row, column: column)
            }
        }
    }

    /// Les vignettes sont carrées, et un cheveu plus petites qu'une case : le
    /// rognage volontaire de ``BoardRectifier/edgeInset`` évite qu'une vignette
    /// emporte un liseré de sa voisine — un liseré suffit à faire passer une
    /// case vide pour contrastée.
    @Test func slicedSquaresAreSquareAndTrimmedOfTheirNeighbours() throws {
        let rows = try #require(BoardRectifier.slice(SyntheticBoard.uniqueSquares(side: 800)))
        let expected = Int(100 * (1 - 2 * BoardRectifier.edgeInset))

        #expect(rows[0][0].width == expected)
        #expect(rows[0][0].height == expected)
        #expect(rows[0][0].width == rows[7][7].width, "toutes les vignettes ont la même taille")
    }

    // MARK: Redressement

    @Test func rectifyingAnUndistortedBoardIsIdentityOnItsSquares() throws {
        let image = SyntheticBoard.uniqueSquares(side: 800)
        let quad = BoardQuad.covering(width: 800, height: 800)

        let rows = try #require(BoardRectifier.rectifyAndSlice(image, quad: quad))

        for row in 0..<8 {
            for column in 0..<8 {
                expectColor(PixelProbe.averageCenterColor(of: rows[row][column]), row: row, column: column)
            }
        }
    }

    @Test func rectifyingNormalizesToASquareOfTheRequestedSide() throws {
        let (image, quad) = SyntheticBoard.boardOnBackground()
        let rectified = try #require(BoardRectifier.rectify(image, quad: quad, side: 400))

        #expect(rectified.width == 400)
        #expect(rectified.height == 400)
    }

    /// Le vrai service rendu : une image PRISE DE BIAIS, redressée, redonne
    /// les cases dans le bon ordre. On part des couleurs uniques, on les
    /// déforme selon un quadrilatère connu, et on doit tout retrouver.
    @Test func rectifyingUndoesAKnownPerspectiveDistortion() throws {
        let source = SyntheticBoard.uniqueSquares(side: 800)
        let distortedQuad = BoardQuad(
            topLeft: CGPoint(x: 180, y: 60),
            topRight: CGPoint(x: 760, y: 140),
            bottomRight: CGPoint(x: 700, y: 900),
            bottomLeft: CGPoint(x: 60, y: 780)
        )
        let distorted = try #require(warp(source, into: distortedQuad, canvas: 1000))

        let rows = try #require(BoardRectifier.rectifyAndSlice(distorted, quad: distortedQuad))

        // Tolérance plus large qu'en découpe pure : deux rééchantillonnages
        // (déformation puis redressement) lissent un peu les couleurs.
        for row in 0..<8 {
            for column in 0..<8 {
                expectColor(
                    PixelProbe.averageCenterColor(of: rows[row][column]),
                    row: row, column: column, tolerance: 0.05
                )
            }
        }
    }

    /// Déforme une image carrée pour qu'elle occupe `quad` dans un canevas.
    /// Inverse exact de `BoardRectifier.rectify` : c'est ce qui rend le test
    /// ci-dessus significatif.
    private func warp(_ image: CGImage, into quad: BoardQuad, canvas: Int) -> CGImage? {
        let height = Double(canvas)
        func flipped(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x, y: CGFloat(height - Double(point.y)))
        }

        guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return nil }
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter.setValue(flipped(quad.topLeft), forKey: "inputTopLeft")
        filter.setValue(flipped(quad.topRight), forKey: "inputTopRight")
        filter.setValue(flipped(quad.bottomRight), forKey: "inputBottomRight")
        filter.setValue(flipped(quad.bottomLeft), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        return context.createCGImage(output, from: CGRect(x: 0, y: 0, width: canvas, height: canvas))
    }

    // MARK: Détection

    /// Vision doit retrouver seule un plateau franc sur fond contrasté. Ce
    /// n'est PAS un contrat fort (la détection échouera sur de vraies
    /// photos, d'où l'ajustement manuel) : ce test vérifie seulement que le
    /// câblage Vision et la conversion de coordonnées sont bons — origine en
    /// bas à gauche chez Vision, en haut à gauche chez nous.
    @Test func detectionFindsAPlainBoardAndReturnsTopLeftOriginCorners() throws {
        let (image, expected) = SyntheticBoard.boardOnBackground(boardSide: 600, margin: 100)

        let detected = try #require(
            BoardDetector.detect(in: image, source: .screenshot),
            "Vision devrait détecter un damier franc sur fond sombre"
        )

        // ±12 px : Vision cale ses coins sur les bords détectés, pas au
        // pixel théorique.
        for (found, want) in zip(detected.corners, expected.corners) {
            #expect(abs(Double(found.x) - Double(want.x)) < 12, "x: \(found.x) ≠ \(want.x)")
            #expect(abs(Double(found.y) - Double(want.y)) < 12, "y: \(found.y) ≠ \(want.y)")
        }
    }

    @Test func detectionReturnsNilOnAnImageWithoutAnyRectangle() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let noise = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { context in
            for x in stride(from: 0, to: 400, by: 4) {
                for y in stride(from: 0, to: 400, by: 4) {
                    UIColor(hue: .random(in: 0...1), saturation: 1, brightness: .random(in: 0...1), alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }

        #expect(BoardDetector.detect(in: noise.cgImage!, source: .screenshot) == nil)
    }
}
