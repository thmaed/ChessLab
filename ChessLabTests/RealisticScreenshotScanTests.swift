import ChessKit
import CoreGraphics
import Testing
import UIKit
@testable import ChessLab

/// Le scanner face à une VRAIE capture de téléphone — le cas rapporté par
/// l'utilisateur (capture chess.com) où « le cadrage est inopérant » et « la
/// reconnaissance désastreuse ».
///
/// Ce qui distingue ce cas des fixtures carrées d'origine : image PORTRAIT,
/// plateau pleine largeur qui touche les deux bords, plateau réduit à une
/// bande de la hauteur, interface chargée (texte, avatars, mini-glyphes de
/// pièces capturées), coordonnées incrustées dans les cases du bord.
@MainActor
struct RealisticScreenshotScanTests {

    /// La position de la capture d'origine (finale tour + fou), pour coller au
    /// cas réel plutôt qu'à une position d'ouverture bien peuplée.
    private static let screenshotFEN = "5rk1/P7/2R5/5P1p/8/4b3/6K1/8 w - - 0 47"

    /// Le cadrage automatique doit trouver le plateau : pleine largeur
    /// (x ≈ 0, côté ≈ 1206) posé à y = 700.
    @Test func theBoardIsFoundInAPortraitPhoneScreenshot() throws {
        let uiImage = try #require(ScanTestImage.renderRealisticScreenshot(fen: Self.screenshotFEN))
        let cg = try #require(uiImage.cgImage)

        let result = try #require(CheckerboardDetector.detect(in: cg), "le plateau devrait être détecté")

        // La marge volontaire de 2 % élargit le cadre (~24 px), et le bord
        // gauche/droit est borné à l'image : on tolère marge + un demi-pour-cent.
        #expect(result.rect.minX < 12, "plateau collé au bord gauche")
        #expect(abs(result.rect.minY - 700) < 36, "plateau posé à y = 700")
        #expect(abs(result.rect.width - 1206) < 36, "côté ≈ pleine largeur")
        #expect(result.rect.maxY - 1906 < 36, "bas du plateau ≈ 1906")
        #expect(result.score > 0.55)
    }

    /// Le pipeline COMPLET de l'app (préparation, détection, redressement,
    /// recalage, classification) doit lire la position exacte — c'est la
    /// définition de « la reconnaissance fonctionne ».
    @Test func theWholePipelineReadsTheRealisticScreenshot() throws {
        let uiImage = try #require(ScanTestImage.renderRealisticScreenshot(fen: Self.screenshotFEN))
        let prepared = try #require(ScannerViewModel.prepare(uiImage))
        let detection = try #require(
            BoardDetector.detectBoard(in: prepared, source: .screenshot),
            "la détection auto doit réussir sur une capture de téléphone"
        )
        #expect(detection.isConfident, "le damier reconnu doit sauter le cadrage manuel")

        let squares = try #require(BoardRectifier.rectifyAndSlice(prepared, quad: detection.quad))
        let reading = BoardScanner.scan(
            squares: squares, source: .screenshot,
            classifier: TemplateSquareClassifier(source: .screenshot)
        )
        // Rotation `.none` (la lecture brute) : sur cette finale clairsemée,
        // l'orientation est objectivement ambiguë et `suggestedRotation` peut
        // préférer 180° — c'est le bouton « Pivoter » de la confirmation qui
        // tranche, pas une heuristique. Ce qu'on verrouille ici, c'est que
        // chaque pièce est lue SUR SA CASE.
        let fen = reading.fen(rotation: .none, sideToMove: .white)

        #expect(fen.split(separator: " ")[0] == Self.screenshotFEN.split(separator: " ")[0])
        // Les coordonnées incrustées ne doivent pas noyer la confirmation
        // sous les cases « incertaines » (15 cases du bord sont marquées).
        #expect(reading.lowConfidenceSquares(rotation: .none).count <= 6)
    }
}
