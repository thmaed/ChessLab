import ChessKit
import CoreGraphics
import Testing
import UIKit
@testable import ChessLab

/// Détection automatique du cadrage par le motif de damier.
@MainActor
struct CheckerboardDetectorTests {

    /// Une capture réaliste : plateau rendu, posé avec une marge sur un fond
    /// (comme une interface autour). La détection doit retrouver le plateau au
    /// pixel près, pas le fond.
    @Test func findsTheBoardInAScreenshotWithMargin() throws {
        let uiImage = try #require(ScanTestImage.render(fen: ScanTestImage.syntheticFEN))
        let cg = try #require(uiImage.cgImage)
        // L'image fait 1000×1000 : plateau de 800 centré (marge 100).
        let result = try #require(CheckerboardDetector.detect(in: cg), "un plateau devrait être trouvé")

        #expect(abs(result.rect.minX - 100) < 20, "bord gauche du plateau ≈ 100")
        #expect(abs(result.rect.minY - 100) < 20, "bord haut du plateau ≈ 100")
        #expect(abs(result.rect.width - 800) < 30, "côté du plateau ≈ 800")
        #expect(result.score > 0.55)
    }

    /// Une image sans damier ne doit rien renvoyer.
    @Test func returnsNilOnAFlatImage() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let flat = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { ctx in
            UIColor(white: 0.4, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }.cgImage!

        #expect(CheckerboardDetector.detect(in: flat) == nil)
    }
}
