import ChessKit
import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import ChessLab

/// Positions couvrant les cas qui comptent : départ (toutes les pièces),
/// milieu de partie (cases vides éparses), finale (peu de pièces), et une
/// position sans dames.
///
/// Hors de la suite : `@Test(arguments:)` évalue ses arguments EN DEHORS de
/// l'acteur, une propriété statique isolée au `MainActor` y serait inutilisable.
let scannerTestPositions: [(name: String, fen: String)] = [
    ("position initiale", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"),
    ("sicilienne", "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"),
    ("milieu de partie", "r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P1B2/2PBPN2/PP1N1PPP/R2Q1RK1 w - - 0 9"),
    ("finale de tours", "8/5pk1/6p1/8/8/1R6/5PPP/6K1 w - - 0 40"),
    ("cavaliers et fous", "5bk1/5ppp/8/8/8/2N5/5PPP/4B1K1 w - - 0 30")
]

/// Tests de la lecture d'un diagramme numérique (étape 7 / Lot 1.C).
///
/// Critère du lot : plateau synthétique rendu depuis un FEN → pipeline
/// complet → **FEN reconstruit identique au FEN source**, sur plusieurs
/// positions et plusieurs thèmes (attendu 64/64).
///
/// ⚠️ **Limite assumée de ces tests** : gabarits et plateaux de test sortent
/// du MÊME moteur de rendu. Ils prouvent donc la cohérence du pipeline
/// (découpe, rotation, seuils, génération du FEN), pas qu'une VRAIE capture
/// Lichess est lisible — seules les fixtures réelles répondent à ça
/// (`ScannerFixtureTests`). D'où les tests « conditions dégradées » plus bas,
/// qui s'en approchent : couleurs de plateau hors thèmes, bruit, flou.
@MainActor
struct BoardScannerTests {

    /// Rend un plateau, le passe par la découpe et le classifieur, et rend le
    /// FEN lu.
    private func readBack(
        fen: String, theme: BoardTheme = .classic, source: ScanSource = .screenshot,
        orientation: Piece.Color = .white, glyphScale: CGFloat = 1
    ) throws -> (fen: String, reading: BoardScanReading) {
        let position = try #require(Position(fen: fen))
        let board = try #require(BoardImageRenderer.renderBoard(
            position: position, theme: theme, side: 800,
            orientation: orientation, glyphScale: glyphScale
        ))
        let squares = try #require(BoardRectifier.slice(board))

        let classifier = TemplateSquareClassifier(source: source)
        let reading = BoardScanner.scan(squares: squares, source: source, classifier: classifier)
        let rotation = reading.suggestedRotation()

        return (reading.fen(rotation: rotation, sideToMove: .white), reading)
    }

    /// Compare les seuls champs qu'une image peut porter : le placement.
    private func placement(_ fen: String) -> String {
        String(fen.split(separator: " ")[0])
    }

    // MARK: Le critère du lot

    @Test(arguments: scannerTestPositions)
    func aRenderedBoardIsReadBackExactly(position: (name: String, fen: String)) throws {
        let result = try readBack(fen: position.fen)

        #expect(
            placement(result.fen) == placement(position.fen),
            "\(position.name) : lu \(placement(result.fen))"
        )
    }

    @Test(arguments: BoardTheme.all)
    func everyBoardThemeIsReadBackExactly(theme: BoardTheme) throws {
        let source = scannerTestPositions[2]
        let result = try readBack(fen: source.fen, theme: theme)

        #expect(
            placement(result.fen) == placement(source.fen),
            "thème \(theme.label) : lu \(placement(result.fen))"
        )
    }

    /// La marge autour du glyphe varie d'un site à l'autre : les gabarits
    /// sont rendus à plusieurs échelles pour cette raison précise.
    @Test(arguments: [0.8, 0.92, 1.0] as [CGFloat])
    func aBoardIsReadBackWhateverTheGlyphMargin(glyphScale: CGFloat) throws {
        let source = scannerTestPositions[1]
        let result = try readBack(fen: source.fen, glyphScale: glyphScale)

        #expect(placement(result.fen) == placement(source.fen))
    }

    @Test func everySquareOfARenderedBoardIsReadConfidently() throws {
        let result = try readBack(fen: scannerTestPositions[2].fen)

        #expect(result.reading.lowConfidenceSquares(rotation: .none).isEmpty)
    }

    // MARK: Orientation

    /// Le prompt exige de pouvoir inverser la lecture. Un plateau rendu du
    /// côté des Noirs doit être reconnu tel quel : la position lue est la
    /// même, seule la rotation proposée change.
    @Test func aBoardSeenFromBlackSideIsSuggestedFlipped() throws {
        let source = scannerTestPositions[2]
        let position = try #require(Position(fen: source.fen))
        let board = try #require(BoardImageRenderer.renderBoard(
            position: position, theme: .classic, side: 800, orientation: .black
        ))
        let squares = try #require(BoardRectifier.slice(board))

        let reading = BoardScanner.scan(
            squares: squares, source: .screenshot,
            classifier: TemplateSquareClassifier(source: .screenshot)
        )

        #expect(reading.suggestedRotation() == .half)
        #expect(placement(reading.fen(rotation: .half, sideToMove: .white)) == placement(source.fen))
    }

    @Test func digitalSourcesOnlyConsiderTwoOrientations() {
        #expect(BoardReadingRotation.candidates(for: .screenshot) == [.none, .half])
        #expect(BoardReadingRotation.candidates(for: .screenPhoto) == [.none, .half])
    }

    @Test func rotatingAGridFourTimesReturnsIt() {
        let grid = (0..<8).map { row in (0..<8).map { column in row * 8 + column } }

        #expect(BoardScanReading.rotate(grid, quarterTurns: 4) == grid)
        #expect(BoardScanReading.rotate(grid, quarterTurns: 0) == grid)
    }

    @Test func aQuarterTurnMovesTheTopLeftCornerToTheTopRight() {
        let grid = (0..<8).map { row in (0..<8).map { column in row * 8 + column } }
        let rotated = BoardScanReading.rotate(grid, quarterTurns: 1)

        // Sens horaire : le coin haut gauche part en haut à droite.
        #expect(rotated[0][7] == grid[0][0])
        #expect(rotated[7][7] == grid[0][7])
    }

    // MARK: Roques et trait

    /// Une image ne dit pas si le roi a déjà bougé : les roques sont déduits
    /// de la position, jamais inventés.
    @Test func castlingRightsAreInferredFromThePositionOnly() throws {
        let result = try readBack(fen: scannerTestPositions[0].fen)
        #expect(result.fen.split(separator: " ")[2] == "KQkq")

        let endgame = try readBack(fen: scannerTestPositions[3].fen)
        #expect(endgame.fen.split(separator: " ")[2] == "-")
    }

    /// Le trait n'est JAMAIS déductible d'une image : il est passé en
    /// paramètre et confirmé par l'utilisateur.
    @Test func theSideToMoveComesFromTheCallerNotTheImage() throws {
        let position = try #require(Position(fen: scannerTestPositions[2].fen))
        let board = try #require(BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800))
        let squares = try #require(BoardRectifier.slice(board))
        let reading = BoardScanner.scan(
            squares: squares, source: .screenshot,
            classifier: TemplateSquareClassifier(source: .screenshot)
        )

        #expect(reading.fen(rotation: .none, sideToMove: .white).split(separator: " ")[1] == "w")
        #expect(reading.fen(rotation: .none, sideToMove: .black).split(separator: " ")[1] == "b")
    }

    // MARK: Cases vides

    @Test func anEmptyBoardIsReadAsEmpty() throws {
        let position = try #require(Position(fen: "8/8/8/8/8/8/8/8 w - - 0 1"))
        let board = try #require(BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800))
        let squares = try #require(BoardRectifier.slice(board))

        let reading = BoardScanner.scan(
            squares: squares, source: .screenshot,
            classifier: TemplateSquareClassifier(source: .screenshot)
        )

        #expect(reading.pieceCount == 0)
        #expect(reading.fen(rotation: .none, sideToMove: .white) == "8/8/8/8/8/8/8/8 w - - 0 1")
    }

    // MARK: Conditions dégradées (au plus près d'une vraie image)

    /// **Le test qui compte vraiment.** Les couleurs de Lichess
    /// (`#f0d9b5` / `#b58863`) ne sont AUCUN des thèmes de l'app : les
    /// gabarits sont donc rendus sur des fonds différents de l'image lue.
    /// Si ça passe, c'est que la reconnaissance tient à la forme du glyphe et
    /// non à la couleur du plateau — la propriété qui rend le critère
    /// d'acceptation (« capture Lichess reconnue ») atteignable.
    @Test func aBoardWithColorsFromNoThemeIsStillReadExactly() throws {
        let lichess = BoardTheme(
            id: "lichess", label: "Lichess",
            lightSquare: Color(red: 0.941, green: 0.851, blue: 0.710),
            darkSquare: Color(red: 0.710, green: 0.533, blue: 0.388),
            lastMoveLight: .yellow, lastMoveDark: .yellow, checkColor: .red,
            selectedColor: .blue, legalDotColor: .black, coordinateColor: .black
        )

        let source = scannerTestPositions[2]
        let result = try readBack(fen: source.fen, theme: lichess)

        #expect(placement(result.fen) == placement(source.fen), "lu \(placement(result.fen))")
    }

    /// Photo d'un écran : bruit, flou et exposition inégale. On n'exige pas
    /// la perfection — le critère du prompt est **≥ 60/64 cases correctes**,
    /// le reste marqué incertain et corrigeable.
    @Test func aNoisyBlurredScreenPhotoReadsAtLeastSixtySquares() throws {
        let source = scannerTestPositions[2]
        let position = try #require(Position(fen: source.fen))
        let clean = try #require(BoardImageRenderer.renderBoard(position: position, theme: .classic, side: 800))
        let degraded = try #require(degrade(clean))

        let squares = try #require(BoardRectifier.slice(degraded))
        let reading = BoardScanner.scan(
            squares: squares, source: .screenPhoto,
            classifier: TemplateSquareClassifier(source: .screenPhoto)
        )

        let expected = try #require(Position(fen: source.fen))
        let read = reading.squares(rotation: .none)
        var correct = 0

        for square in Square.allCases {
            let truth = expected.piece(at: square)
            let got = read[square]?.occupancy
            switch (truth, got) {
            case (nil, .empty), (nil, nil):
                correct += 1
            case let (piece?, .piece(color, kind)) where piece.color == color && piece.kind == kind:
                correct += 1
            default:
                break
            }
        }

        #expect(correct >= 60, "seulement \(correct)/64 cases correctes sur une photo d'écran dégradée")
    }

    /// Assombrit, ajoute du bruit et un léger flou — de quoi imiter une photo
    /// d'écran prise à main levée.
    private func degrade(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        guard let exposure = CIFilter(name: "CIExposureAdjust") else { return nil }
        exposure.setValue(ciImage, forKey: kCIInputImageKey)
        exposure.setValue(-0.8, forKey: kCIInputEVKey)

        guard let blurred = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurred.setValue(exposure.outputImage, forKey: kCIInputImageKey)
        blurred.setValue(1.2, forKey: kCIInputRadiusKey)

        guard let output = blurred.outputImage else { return nil }
        let context = CIContext()
        guard let base = context.createCGImage(output, from: CIImage(cgImage: image).extent) else { return nil }

        // Bruit poivre-et-sel léger, par-dessus le flou.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let noisy = UIGraphicsImageRenderer(size: CGSize(width: image.width, height: image.height), format: format).image { context in
            UIImage(cgImage: base).draw(at: .zero)
            for _ in 0..<6000 {
                let gray = CGFloat.random(in: 0...1)
                UIColor(white: gray, alpha: 0.5).setFill()
                context.fill(CGRect(
                    x: CGFloat.random(in: 0..<CGFloat(image.width)),
                    y: CGFloat.random(in: 0..<CGFloat(image.height)),
                    width: 2, height: 2
                ))
            }
        }
        return noisy.cgImage
    }

    // MARK: Corrélation (calcul pur)

    @Test func correlationOfAPatchWithItselfIsOne() throws {
        let values = (0..<64).map { _ in Double.random(in: 0...1) }
        let normalized = try #require(ImagePatch.normalize(values))

        #expect(abs(ImagePatch.dot(normalized, normalized) - 1) < 1e-9)
    }

    /// La propriété qui fait tout marcher : ZNCC est invariante au contraste
    /// et à la luminosité. C'est ce qui permet de lire les mêmes glyphes sur
    /// un thème inconnu ou une photo sous-exposée.
    @Test func correlationIsInvariantToBrightnessAndContrast() throws {
        let values = (0..<64).map { _ in Double.random(in: 0.2...0.8) }
        let darkened = values.map { $0 * 0.4 + 0.05 }

        let a = try #require(ImagePatch.normalize(values))
        let b = try #require(ImagePatch.normalize(darkened))

        #expect(abs(ImagePatch.dot(a, b) - 1) < 1e-9)
    }

    @Test func correlationOfOppositePatternsIsMinusOne() throws {
        let values = (0..<64).map { _ in Double.random(in: 0...1) }
        let inverted = values.map { 1 - $0 }

        let a = try #require(ImagePatch.normalize(values))
        let b = try #require(ImagePatch.normalize(inverted))

        #expect(abs(ImagePatch.dot(a, b) + 1) < 1e-9)
    }

    @Test func aFlatPatchHasNoNormalization() {
        #expect(ImagePatch.normalize([Double](repeating: 0.5, count: 64)) == nil)
    }
}
