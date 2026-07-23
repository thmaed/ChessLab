import ChessKit
import CoreGraphics
import Testing
import UIKit
@testable import ChessLab

/// Recalage de la grille sur les lignes du damier.
///
/// Ce que ces tests protègent : la découpe ne doit PAS croire au cadrage.
/// Vision rend un quadrilatère ~3 % trop grand même sur une capture parfaite,
/// et un cadrage manuel fait rarement mieux — sans recalage, chaque vignette
/// mord sur sa voisine et la reconnaissance s'effondre.
@MainActor
struct BoardGridFinderTests {

    private func board(fen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") throws -> CGImage {
        let position = try #require(Position(fen: fen))
        return try #require(BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800))
    }

    /// Un plateau cadré au pixel près : le recalage doit retrouver la grille
    /// uniforme, et surtout ne rien « corriger » qui n'est pas cassé.
    @Test func aPerfectlyCroppedBoardKeepsItsUniformGrid() throws {
        let grid = BoardGridFinder.grid(in: try board())

        for line in 0...8 {
            #expect(abs(grid.columns[line] - Double(line) * 100) < 4)
            #expect(abs(grid.rows[line] - Double(line) * 100) < 4)
        }
    }

    /// Le cas réel : le plateau occupe 800 px dans une image de 823, décalé de
    /// 14 px — exactement ce que produit la détection automatique de Vision.
    @Test func anOversizedCropIsRealignedOnTheBoardLines() throws {
        let inset = 14.0
        let canvas = 828.0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let padded = UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format).image { context in
            UIColor(white: 0.12, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
            UIImage(cgImage: try! board()).draw(in: CGRect(x: inset, y: inset, width: 800, height: 800))
        }.cgImage!

        let grid = BoardGridFinder.grid(in: padded)

        #expect(abs(grid.columns[0] - inset) < 5, "la première ligne doit tomber sur le bord du plateau, pas sur celui de l'image")
        #expect(abs(grid.columns[8] - (inset + 800)) < 5)
        #expect(abs((grid.columns[1] - grid.columns[0]) - 100) < 3, "le pas doit valoir une case du plateau")
    }

    /// Une image sans aucune structure de damier ne doit pas produire une
    /// grille fantaisiste : mieux vaut l'hypothèse uniforme qu'une pire.
    @Test func aFlatImageFallsBackOnTheUniformGrid() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let flat = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }.cgImage!

        let grid = BoardGridFinder.grid(in: flat)

        #expect(grid == BoardGridFinder.Grid.uniform(width: 400, height: 400))
    }

    /// Le test qui manquait, et le seul qui prouve le critère d'acceptation :
    /// l'image telle que l'app la reçoit traverse la détection ET le
    /// redressement RÉELS, pas une découpe idéale.
    ///
    /// Sans lui, tout le pipeline se validait sur des plateaux déjà
    /// parfaitement cadrés — et la vraie détection, elle, ne lisait que les
    /// 8 pions (les 24 autres pièces étaient perdues).
    @Test func theWholeAppPipelineReadsTheInjectedTestImage() throws {
        let uiImage = try #require(ScanTestImage.render(fen: ScanTestImage.syntheticFEN))
        let prepared = try #require(ScannerViewModel.prepare(uiImage))
        let quad = try #require(BoardDetector.detect(in: prepared, source: .screenshot), "la détection auto doit réussir sur une capture nette")
        let squares = try #require(BoardRectifier.rectifyAndSlice(prepared, quad: quad))

        let reading = BoardScanner.scan(
            squares: squares, source: .screenshot,
            classifier: TemplateSquareClassifier(source: .screenshot)
        )
        let fen = reading.fen(rotation: reading.suggestedRotation(), sideToMove: .white)

        #expect(fen.split(separator: " ")[0] == ScanTestImage.syntheticFEN.split(separator: " ")[0])
        // Quelques cases restent signalées, et c'est sain : redressement et
        // rééchantillonnage émoussent les glyphes, la confiance le dit. Ce
        // qu'on verrouille, c'est l'ORDRE DE GRANDEUR — à 33 cases douteuses
        // (l'état d'avant le recalage), le bandeau de confirmation ne
        // signalait plus rien d'utile.
        #expect(reading.lowConfidenceSquares(rotation: .none).count <= 6)
    }
}
